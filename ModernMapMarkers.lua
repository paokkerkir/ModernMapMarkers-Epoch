-- ModernMapMarkers.lua (WotLK 3.3.5a)
-- Core logic: point index, marker pool, rendering, event handling.
-- UI (dropdowns, labels) is in ModernMapMarkers_UI.lua.
-- Marker data is defined in MarkerData.lua as MMM_MarkerData / MMM_MarkerData_WDM.

-- ============================================================
-- Constants
-- ============================================================

local HOVER_SIZE_MULTIPLIER   = 1.15
local HOVER_ALPHA             = 0.5
local FIND_SIZE_MULTIPLIER    = 1.4
local FIND_HIGHLIGHT_ALPHA    = 0.9
local FIND_HIGHLIGHT_DURATION = 3.5
local SOUND_CLICK             = "Sound\\Interface\\uCharacterSheetOpen.wav"
local MARKER_SIZE_LARGE       = 32
local MARKER_SIZE_SMALL       = 24
local UPDATE_THROTTLE         = 0.1
local MAX_POOL_SIZE           = 50
local CONTINENT_MULTIPLIER    = 100
local INVALID_ZONE            = 0

local TEXTURES = {
    dungeon   = "Interface\\Addons\\ModernMapMarkers\\Textures\\dungeon.tga",
    raid      = "Interface\\Addons\\ModernMapMarkers\\Textures\\raid.tga",
    worldboss = "Interface\\Addons\\ModernMapMarkers\\Textures\\worldboss.tga",
    zepp      = "Interface\\Addons\\ModernMapMarkers\\Textures\\zepp.tga",
    boat      = "Interface\\Addons\\ModernMapMarkers\\Textures\\boat.tga",
    tram      = "Interface\\Addons\\ModernMapMarkers\\Textures\\tram.tga",
    portal    = "Interface\\Addons\\ModernMapMarkers\\Textures\\portal.tga",
}

local WORLD_BOSS_MAP = {
    ["Doom Lord Kazzak"] = "WorldBossesBC",
    ["Doomwalker"]       = "WorldBossesBC",
}

local ATLAS_OUTDOOR_INDEX = {
    ["Azuregos"]                            = 1,
    ["Doom Lord Kazzak"]                    = 2,
    ["Doomwalker"]                          = 3,
    ["Emerald Dragon - Spawn Point 1 of 4"] = 4,
    ["Emerald Dragon - Spawn Point 2 of 4"] = 4,
    ["Emerald Dragon - Spawn Point 3 of 4"] = 4,
    ["Emerald Dragon - Spawn Point 4 of 4"] = 4,
}

-- [1]=atlasID, [2]=displayName
local NIGHTMARE_DRAGONS = {
    {"DLethon",  "Lethon"},
    {"DEmeriss", "Emeriss"},
    {"DTaerar",  "Taerar"},
    {"DYsondre", "Ysondre"},
}

-- Maps WotLK continent index -> Atlas type index
-- 1=Kalimdor->2, 2=EK->1, 3=Outland->3, 4=Northrend->4
local ATLAS_CONTINENT_MAP = {2, 1, 3, 4}

-- Shared between default and WDM datasets for Outland/Northrend.
local WDM_SHARED_TYPES      = {dungeon=true, raid=true, worldboss=true}
local WDM_SHARED_CONTINENTS = {3, 4}

-- ============================================================
-- Cached globals
-- ============================================================

local pairs       = pairs
local tinsert     = table.insert
local tconcat     = table.concat
local GetTime     = GetTime
local math_random = math.random
local math_sin    = math.sin
local strfind     = string.find
local strsub      = string.sub
local pcall       = pcall

-- ============================================================
-- State
-- ============================================================

local pointsByMap        = {}
local markerPool         = {}
local markerPoolCount    = 0
local activeMarkers      = {}
local activeMarkersCount = 0
local initialized        = false
local lastContinent      = 0
local lastZone           = 0
local lastUpdateTime     = 0
local frame              = CreateFrame("Frame")
local updateEnabled      = false
local flatDataCache
local pendingOriginC
local pendingOriginZ
local usingWDM           = false

-- ============================================================
-- Global namespace  (shared with ModernMapMarkers_UI.lua)
-- ============================================================

MMM = MMM or {}

function MMM.ForceRedraw()
    lastContinent = 0
    lastZone      = 0
end

-- Called by the destination popup in ModernMapMarkers_UI.lua.
function MMM.NavigateToTransportDest(destContinent, destZone, originC, originZ)
    pendingOriginC = originC
    pendingOriginZ = originZ
    PlaySoundFile("Sound\\Interface\\MapPing.wav")
    SetMapZoom(destContinent, destZone)
    MMM.ForceRedraw()
end

function MMM.SetUpdateEnabled(state)
    if state and not updateEnabled then
        frame:RegisterEvent("WORLD_MAP_UPDATE")
        updateEnabled = true
    elseif not state and updateEnabled then
        frame:UnregisterEvent("WORLD_MAP_UPDATE")
        updateEnabled = false
    end
end

-- ============================================================
-- Point index
-- ============================================================

local function BuildPointIndex()
    -- Data format (per continent bucket): { zoneID, x, y, name, type, info, atlasID [, dest] }
    local pointsToUse = MMM_DefaultPoints
    if IsAddOnLoaded("WDM") then
        pointsToUse = MMM_WdmPoints
        usingWDM    = true
    end

    for continent, entries in pairs(pointsToUse) do
        for i = 1, #entries do
            local p   = entries[i]
            local key = continent * CONTINENT_MULTIPLIER + p[1]
            local bucket = pointsByMap[key]
            if not bucket then
                bucket = {}
                pointsByMap[key] = bucket
            end
            -- dest is embedded as p[8] for transport types; nil otherwise.
            tinsert(bucket, {continent, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]})
        end
    end

    -- When WDM is active, supplement continents 3 and 4 with dungeon/raid/worldboss
    -- entries from MMM_DefaultPoints (which WDM_WdmPoints no longer carries).
    if usingWDM then
        for _, continent in ipairs(WDM_SHARED_CONTINENTS) do
            local defaultEntries = MMM_DefaultPoints[continent]
            if defaultEntries then
                for i = 1, #defaultEntries do
                    local p = defaultEntries[i]
                    if WDM_SHARED_TYPES[p[5]] then
                        local key = continent * CONTINENT_MULTIPLIER + p[1]
                        local bucket = pointsByMap[key]
                        if not bucket then
                            bucket = {}
                            pointsByMap[key] = bucket
                        end
                        tinsert(bucket, {continent, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]})
                    end
                end
            end
        end
    end
end

-- Returns a flat list of { continent, zone, name, type, description, atlasID }
-- for the Find Marker dropdown. Transport and portal types are excluded.
-- Built once on first call and cached for the session.
function MMM.GetFlatData()
    if flatDataCache then return flatDataCache end
    local result = {}
    local skip = {boat=true, zepp=true, tram=true, portal=true}
    -- Use WDM points when WDM is active so that SetMapZoom gets the correct
    -- zone IDs. Using DefaultPoints with WDM active would navigate to the
    -- wrong zone because the zone IDs differ between the two datasets.
    -- Exception: continents 3 and 4 dungeon/raid/worldboss entries are shared
    -- between datasets, so always read those from MMM_DefaultPoints.
    local pointsToUse = usingWDM and MMM_WdmPoints or MMM_DefaultPoints
    for continent, entries in pairs(pointsToUse) do
        for i = 1, #entries do
            local p = entries[i]
            if not skip[p[5]] and p[8] ~= "nolist" then
                tinsert(result, {
                    continent   = continent,
                    zone        = p[1],
                    name        = p[4],
                    type        = p[5],
                    description = p[6],
                    atlasID     = p[7],
                })
            end
        end
    end
    -- Supplement with default dungeon/raid/worldboss entries for Outland and
    -- Northrend when WDM is active (WDM omits these to avoid duplication).
    if usingWDM then
        for _, continent in ipairs(WDM_SHARED_CONTINENTS) do
            local defaultEntries = MMM_DefaultPoints[continent]
            if defaultEntries then
                for i = 1, #defaultEntries do
                    local p = defaultEntries[i]
                    if WDM_SHARED_TYPES[p[5]] and p[8] ~= "nolist" then
                        tinsert(result, {
                            continent   = continent,
                            zone        = p[1],
                            name        = p[4],
                            type        = p[5],
                            description = p[6],
                            atlasID     = p[7],
                        })
                    end
                end
            end
        end
    end
    flatDataCache = result
    return result
end

-- ============================================================
-- Marker pool
-- ============================================================

local function GetMarkerFromPool()
    if markerPoolCount > 0 then
        local marker = markerPool[markerPoolCount]
        markerPool[markerPoolCount] = nil
        markerPoolCount = markerPoolCount - 1
        return marker
    end
    local marker = CreateFrame("Button", nil, WorldMapDetailFrame)
    marker.texture   = marker:CreateTexture(nil, "OVERLAY")
    marker.highlight = marker:CreateTexture(nil, "HIGHLIGHT")
    marker.highlight:SetBlendMode("ADD")
    return marker
end

local function ReturnMarkerToPool(marker)
    marker:Hide()
    marker:ClearAllPoints()
    marker:SetScript("OnEnter", nil)
    marker:SetScript("OnLeave", nil)
    marker:SetScript("OnClick", nil)
    marker:SetScript("OnUpdate", nil)
    marker.findTimer       = nil
    marker.markerName      = nil
    marker.markerDisplay   = nil
    marker.markerInfo      = nil
    marker.markerHint      = nil
    marker.markerKind      = nil
    marker.atlasID         = nil
    marker.transportDest   = nil
    marker.isDualDest      = nil
    marker.isMultiDest     = nil
    marker.isEmeraldDragon = nil
    marker.originalSize    = nil
    if markerPoolCount < MAX_POOL_SIZE then
        markerPoolCount = markerPoolCount + 1
        markerPool[markerPoolCount] = marker
    else
        marker:SetParent(nil)
    end
end

-- ============================================================
-- Click handlers
-- WotLK 3.3.5a: SetScript callbacks receive no parameters.
-- The frame is 'this', the button is 'arg1', elapsed time is 'arg1'.
-- ============================================================

local function GetRandomNightmareDragon()
    local d = NIGHTMARE_DRAGONS[math_random(1, 4)]
    return d[1], d[2]
end

local function IsWorldMapFullscreen()
    if BlackoutWorld and BlackoutWorld:IsVisible() then return true end
    local mapWidth  = WorldMapFrame:GetWidth()
    local mapHeight = WorldMapFrame:GetHeight()
    return (mapWidth / GetScreenWidth() > 0.9 and mapHeight / GetScreenHeight() > 0.9)
end

local function OnWorldBossClick()
    if not AtlasLoot_ShowBossLoot or not AtlasFrame or not Atlas_Refresh then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000AtlasLoot not loaded.|r")
        return
    end
    local bossName    = this.markerName
    local dataID      = WORLD_BOSS_MAP[bossName]
    local atlasIndex  = ATLAS_OUTDOOR_INDEX[bossName]
    local displayName = bossName

    if this.isEmeraldDragon then
        dataID, displayName = GetRandomNightmareDragon()
        atlasIndex = 4
    end

    if dataID and atlasIndex then
        PlaySoundFile(SOUND_CLICK)
        if WorldMapFrame:IsVisible() and IsWorldMapFullscreen() then
            HideUIPanel(WorldMapFrame)
        end
        if AtlasFrame and AtlasOptions then
            AtlasOptions.AtlasType = 7   -- Outdoor Encounters
            AtlasOptions.AtlasZone = atlasIndex
            local savedAutoSelect = AtlasOptions.AtlasAutoSelect
            AtlasOptions.AtlasAutoSelect = false
            Atlas_Refresh()
            AtlasFrame:SetFrameStrata("FULLSCREEN")
            AtlasFrame:Show()
            AtlasOptions.AtlasAutoSelect = savedAutoSelect
        end
        -- Capture into locals so the closure doesn't capture 'this'.
        local boss_dataID      = dataID
        local boss_displayName = displayName
        local delayFrame       = CreateFrame("Frame")
        delayFrame.timer       = 0
        delayFrame:SetScript("OnUpdate", function()
            this.timer = this.timer + arg1
            if this.timer >= 0.1 then
                this:SetScript("OnUpdate", nil)
                local ok = pcall(AtlasLoot_ShowBossLoot, boss_dataID, boss_displayName, AtlasFrame)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Error loading AtlasLoot data.|r")
                end
            end
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000No Atlas data found for \"" .. bossName .. "\".|r")
    end
end

local function OnAtlasClick()
    if this.atlasID and AtlasFrame and AtlasOptions then
        PlaySoundFile(SOUND_CLICK)
        if WorldMapFrame:IsVisible() and IsWorldMapFullscreen() then
            HideUIPanel(WorldMapFrame)
        end
        local continent = GetCurrentMapContinent()
        AtlasOptions.AtlasType = ATLAS_CONTINENT_MAP[continent] or 1
        AtlasOptions.AtlasZone = this.atlasID
        Atlas_Refresh()
        AtlasFrame:SetFrameStrata("FULLSCREEN")
        local savedAutoSelect = AtlasOptions.AtlasAutoSelect
        AtlasOptions.AtlasAutoSelect = false
        AtlasFrame:Show()
        AtlasOptions.AtlasAutoSelect = savedAutoSelect
        if AtlasQuestFrame then AtlasQuestFrame:Show() end
    end
end

local function StartPinHighlight(pin)
    pin.highlight:SetAlpha(0)
    pin.findTimer = 0
    pin:SetScript("OnUpdate", function()
        this.findTimer = this.findTimer + arg1
        local progress = this.findTimer / FIND_HIGHLIGHT_DURATION
        if progress >= 1 then
            this:SetWidth(this.originalSize)
            this:SetHeight(this.originalSize)
            this.highlight:SetAlpha(0)
            this.findTimer = nil
            this:SetScript("OnUpdate", nil)
        else
            local envelope = 1 - progress
            local pulse    = (math_sin(progress * 3.14159 * 8) + 1) * 0.5
            local sz       = this.originalSize
                           + (this.originalSize * (FIND_SIZE_MULTIPLIER - 1)) * pulse * envelope
            this:SetWidth(sz)
            this:SetHeight(sz)
            this.highlight:SetAlpha(FIND_HIGHLIGHT_ALPHA * pulse * envelope)
        end
    end)
end

local function OnTransportClick()
    local dest = this.transportDest
    if not dest then return end

    -- Three or more destinations: delegate to the popup menu.
    if this.isMultiDest then
        PlaySound("UChatScrollButton")
        MMM.ShowDestMenu(this)
        return
    end

    local chosen
    if this.isDualDest then
        -- arg1 is the mouse button name in an OnClick handler
        chosen = (arg1 == "RightButton") and dest[2] or dest[1]
    else
        chosen = dest
    end

    local cc = GetCurrentMapContinent()
    local cz = GetCurrentMapZone()
    PlaySoundFile("Sound\\Interface\\MapPing.wav")

    -- Same-zone transport: highlight the other pin without navigating.
    if chosen[1] == cc and chosen[2] == cz then
        local clicked = this
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin ~= clicked and pin.transportDest then
                local d = pin.transportDest
                local match
                if pin.isMultiDest then
                    for i = 1, #d do
                        if d[i][1] == cc and d[i][2] == cz then
                            match = true
                            break
                        end
                    end
                elseif pin.isDualDest then
                    match = (d[1][1] == cc and d[1][2] == cz)
                         or (d[2][1] == cc and d[2][2] == cz)
                else
                    match = (d[1] == cc and d[2] == cz)
                end
                if match then
                    StartPinHighlight(pin)
                    break
                end
            end
        end
        return
    end

    -- Different-zone: navigate to destination and highlight the return marker.
    -- If the dest carries "nopulse" the return highlight is intentionally skipped.
    local nopulse = chosen[3] == "nopulse"
    if not nopulse then
        pendingOriginC = cc
        pendingOriginZ = cz
    end
    SetMapZoom(chosen[1], chosen[2])
    MMM.ForceRedraw()
end

-- ============================================================
-- Pin creation
-- ============================================================

local function CreateMapPin(x, y, size, texture, tooltipText, tooltipInfo, atlasID, kind, dest)
    -- "dropdown" sentinel: comment shown only in Find Marker, not on the map.
    local displayName = nil
    if dest == "dropdown" then
        local nl = strfind(tooltipText, "\n")
        if nl then displayName = strsub(tooltipText, 1, nl - 1) end
        dest = nil
    end
    local pin = GetMarkerFromPool()
    pin:SetWidth(size)
    pin:SetHeight(size)
    pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", x, -y)
    pin.texture:SetAllPoints()
    pin.texture:SetTexture(texture)
    pin:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 3)
    pin.highlight:SetAllPoints()
    pin.highlight:SetTexture(texture)
    pin.highlight:SetAlpha(0)
    pin.originalSize    = size
    pin.markerName      = tooltipText
    pin.markerDisplay   = displayName
    pin.markerInfo      = tooltipInfo
    pin.markerKind      = kind
    pin.atlasID         = atlasID
    pin.transportDest   = dest
    pin.isDualDest      = dest and type(dest[1]) == "table" and #dest == 2 or false
    pin.isMultiDest     = dest and type(dest[1]) == "table" and #dest >= 3 or false
    pin.isEmeraldDragon = (kind == "worldboss" and tooltipInfo == "60"
                           and not WORLD_BOSS_MAP[tooltipText]) or nil

    if pin.isMultiDest then
        -- Hint line lists all destinations; the popup handles actual navigation.
        local parts = {}
        for i = 1, #dest do
            tinsert(parts, dest[i][3] or ("Destination " .. i))
        end
        pin.markerHint = "|cFFFFD700Click for destinations:|r " .. tconcat(parts, ", ")
    elseif pin.isDualDest then
        pin.markerHint = "|cFFFFD700Left-click:|r " .. (dest[1][3] or "Destination 1")
                      .. "   |cFFFFD700Right-click:|r " .. (dest[2][3] or "Destination 2")
    end

    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    pin:SetScript("OnEnter", function()
        local hint = ModernMapMarkersDB.showTransportHints and this.markerHint or nil
        MMM.ShowMarkerInfo(this.markerDisplay or this.markerName, this.markerInfo, hint)
        local newSize = this.originalSize * HOVER_SIZE_MULTIPLIER
        this:SetWidth(newSize)
        this:SetHeight(newSize)
        this.highlight:SetAlpha(HOVER_ALPHA)
    end)
    pin:SetScript("OnLeave", function()
        MMM.HideMarkerInfo()
        this:SetWidth(this.originalSize)
        this:SetHeight(this.originalSize)
        this.highlight:SetAlpha(0)
    end)
    pin:SetScript("OnClick", function()
        if this.markerKind == "worldboss" then
            OnWorldBossClick()
        elseif this.markerKind == "boat" or this.markerKind == "zepp"
            or this.markerKind == "tram" or this.markerKind == "portal" then
            OnTransportClick()
        elseif this.atlasID then
            OnAtlasClick()
        end
    end)
    pin:Show()
    return pin
end

-- ============================================================
-- Marker display
-- ============================================================

local function ClearMarkers()
    for i = 1, activeMarkersCount do
        ReturnMarkerToPool(activeMarkers[i])
        activeMarkers[i] = nil
    end
    activeMarkersCount = 0
    MMM.HideMarkerInfo()
    if MMM.HideDestMenu then MMM.HideDestMenu() end
end

function MMM.ClearMarkers()
    ClearMarkers()
end

local function UpdateMarkers()
    if not initialized then return end
    if not ModernMapMarkersDB.showMarkers or not WorldMapFrame:IsVisible() then return end

    local currentContinent = GetCurrentMapContinent()
    local currentZone      = GetCurrentMapZone()
    local currentLevel     = GetCurrentMapDungeonLevel()

    -- Only show markers on the top dungeon level.
    if currentLevel and currentLevel > 1 then
        if activeMarkersCount > 0 then ClearMarkers() end
        lastContinent = INVALID_ZONE
        lastZone      = INVALID_ZONE
        return
    end

    -- Clear when inside an instance or on an invalid map.
    if currentContinent == INVALID_ZONE or currentZone == INVALID_ZONE then
        if activeMarkersCount > 0 then
            ClearMarkers()
            lastContinent = INVALID_ZONE
            lastZone      = INVALID_ZONE
        end
        return
    end

    if currentContinent == lastContinent and currentZone == lastZone then return end

    local now = GetTime()
    if now - lastUpdateTime < UPDATE_THROTTLE then return end
    lastUpdateTime = now

    lastContinent = currentContinent
    lastZone      = currentZone

    ClearMarkers()

    local mapWidth  = WorldMapDetailFrame:GetWidth()
    local mapHeight = WorldMapDetailFrame:GetHeight()
    if mapWidth == 0 or mapHeight == 0 then return end

    local key = currentContinent * CONTINENT_MULTIPLIER + currentZone
    local relevantPoints = pointsByMap[key]
    if not relevantPoints then return end

    local db               = ModernMapMarkersDB
    local showDungeons     = db.showDungeons
    local showRaids        = db.showRaids
    local showWorldBosses  = db.showWorldBosses
    local showBoats        = db.showBoats
    local showZeppelins    = db.showZeppelins
    local showTrams        = db.showTrams
    local showPortals      = db.showPortals
    local transportFaction = db.transportFaction
    local portalFaction    = db.portalFaction

    local texDungeon   = TEXTURES.dungeon
    local texRaid      = TEXTURES.raid
    local texWorldBoss = TEXTURES.worldboss
    local texZepp      = TEXTURES.zepp
    local texBoat      = TEXTURES.boat
    local texTram      = TEXTURES.tram
    local texPortal    = TEXTURES.portal

    local pointCount = #relevantPoints
    for i = 1, pointCount do
        local data    = relevantPoints[i]
        local kind    = data[6]
        local info    = data[7]
        local shouldDisplay = false
        local texture

        if kind == "dungeon" then
            shouldDisplay = showDungeons
            texture = texDungeon
        elseif kind == "raid" then
            shouldDisplay = showRaids
            texture = texRaid
        elseif kind == "worldboss" then
            shouldDisplay = showWorldBosses
            texture = texWorldBoss
        elseif kind == "boat" then
            shouldDisplay = showBoats
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texBoat
        elseif kind == "zepp" then
            shouldDisplay = showZeppelins
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texZepp
        elseif kind == "tram" then
            shouldDisplay = showTrams
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texTram
        elseif kind == "portal" then
            shouldDisplay = showPortals
            if shouldDisplay and portalFaction ~= "all" then
                shouldDisplay = (info == portalFaction) or (info == "Neutral")
            end
            texture = texPortal
        end

        if shouldDisplay then
            local size = (kind == "boat" or kind == "zepp" or kind == "tram" or kind == "portal")
                and MARKER_SIZE_SMALL or MARKER_SIZE_LARGE
            local pin = CreateMapPin(
                data[3] * mapWidth, data[4] * mapHeight,
                size, texture,
                data[5], info, data[8], kind, data[9])
            activeMarkersCount = activeMarkersCount + 1
            activeMarkers[activeMarkersCount] = pin
        end
    end

    -- Trigger a Find Marker highlight if one is pending.
    if MMM.pendingHighlight then
        local target = MMM.pendingHighlight
        MMM.pendingHighlight = nil
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin.markerName == target then
                StartPinHighlight(pin)
                break
            end
        end
    end

    -- Highlight the return transport after a transport click.
    if pendingOriginC then
        local oc = pendingOriginC
        local oz = pendingOriginZ
        pendingOriginC = nil
        pendingOriginZ = nil
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin.transportDest then
                local d = pin.transportDest
                local match
                if pin.isMultiDest then
                    for i = 1, #d do
                        if d[i][1] == oc and d[i][2] == oz then
                            match = true
                            break
                        end
                    end
                elseif pin.isDualDest then
                    match = (d[1][1] == oc and d[1][2] == oz)
                         or (d[2][1] == oc and d[2][2] == oz)
                else
                    match = (d[1] == oc and d[2] == oz)
                end
                if match then
                    StartPinHighlight(pin)
                    break
                end
            end
        end
    end
end

function MMM.UpdateMarkers()
    UpdateMarkers()
end

function MMM.RefreshVisibleTooltip()
    for i = 1, activeMarkersCount do
        local pin = activeMarkers[i]
        if pin and pin:IsVisible() then
            local mx, my = GetCursorPosition()
            local scale  = pin:GetEffectiveScale()
            local left   = pin:GetLeft()   and pin:GetLeft()   * scale or 0
            local right  = pin:GetRight()  and pin:GetRight()  * scale or 0
            local bottom = pin:GetBottom() and pin:GetBottom() * scale or 0
            local top    = pin:GetTop()    and pin:GetTop()    * scale or 0
            if mx >= left and mx <= right and my >= bottom and my <= top then
                local hint = ModernMapMarkersDB.showTransportHints and pin.markerHint or nil
                MMM.ShowMarkerInfo(pin.markerDisplay or pin.markerName, pin.markerInfo, hint)
                return
            end
        end
    end
end

-- ============================================================
-- Saved variables
-- ============================================================

local DEFAULTS = {
    showMarkers        = true,
    showDungeons       = true,
    showRaids          = true,
    showWorldBosses    = true,
    showBoats          = true,
    showZeppelins      = true,
    showTrams          = true,
    showPortals        = false,
    transportFaction   = "all",
    portalFaction      = "all",
    showTransportHints = true,
}

local function InitializeSavedVariables()
    if not ModernMapMarkersDB then ModernMapMarkersDB = {} end
    local db = ModernMapMarkersDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
end

-- ============================================================
-- Silent Atlas priming
-- ============================================================

-- Silently runs Atlas_Refresh() with Naxxramas selected, then restores the
-- previous AtlasOptions state. No frame is ever shown; this exists solely to
-- force Atlas to complete any deferred internal initialization that it skips
-- until the first real Refresh call. Called once on PLAYER_ENTERING_WORLD via
-- a short OnUpdate delay to guarantee Atlas has finished loading first.
local function PrimeAtlasSilently()
    if not Atlas_Refresh or not AtlasOptions then return end
    local savedType = AtlasOptions.AtlasType
    local savedZone = AtlasOptions.AtlasZone
    AtlasOptions.AtlasType = 4   -- Northrend
    AtlasOptions.AtlasZone = 15  -- Naxxramas
    Atlas_Refresh()
    AtlasOptions.AtlasType = savedType
    AtlasOptions.AtlasZone = savedZone
end

local primerFrame = CreateFrame("Frame")

local function ScheduleAtlasPriming()
    primerFrame.timer = 0
    primerFrame:SetScript("OnUpdate", function()
        this.timer = this.timer + arg1
        if this.timer >= 0.5 then
            this:SetScript("OnUpdate", nil)
            PrimeAtlasSilently()
        end
    end)
end

-- ============================================================
-- Event handling
-- WotLK 3.3.5a uses implicit globals: 'this', 'event', 'arg1'.
-- ============================================================

frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "ModernMapMarkers" then
        BuildPointIndex()
        this:UnregisterEvent("ADDON_LOADED")

    elseif event == "VARIABLES_LOADED" then
        if not initialized then
            InitializeSavedVariables()
            initialized = true
            if ModernMapMarkersDB.showMarkers then
                frame:RegisterEvent("WORLD_MAP_UPDATE")
                updateEnabled = true
            end
        end
        this:UnregisterEvent("VARIABLES_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not initialized then
            InitializeSavedVariables()
            BuildPointIndex()
            initialized = true
            if ModernMapMarkersDB.showMarkers then
                frame:RegisterEvent("WORLD_MAP_UPDATE")
                updateEnabled = true
            end
        end
        lastContinent = 0
        lastZone      = 0
        ScheduleAtlasPriming()

    elseif event == "WORLD_MAP_UPDATE" then
        if initialized then
            UpdateMarkers()
        end
    end
end)
