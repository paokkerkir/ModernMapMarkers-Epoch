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
local INVALID_ZONE            = 0

local TEXTURES = {
    dungeon   = "Interface\\Addons\\ModernMapMarkers\\Textures\\dungeon.tga",
    raid      = "Interface\\Addons\\ModernMapMarkers\\Textures\\raid.tga",
    worldboss = "Interface\\Addons\\ModernMapMarkers\\Textures\\worldboss.tga",
    zepp      = "Interface\\Addons\\ModernMapMarkers\\Textures\\zepp.tga",
    boat      = "Interface\\Addons\\ModernMapMarkers\\Textures\\boat.tga",
    tram      = "Interface\\Addons\\ModernMapMarkers\\Textures\\tram.tga",
    portal    = "Interface\\Addons\\ModernMapMarkers\\Textures\\portal.tga",
    pvp       = "Interface\\Addons\\ModernMapMarkers\\Textures\\pvp.tga",
    flightpath = "Interface\\TaxiFrame\\UI-Taxi-Icon-Highlight",
}

local WORLD_BOSS_MAP = {
	["Azuregos"]            = "Azuregos",
   	["Corrupted Ancient"]   = "Corruptedancient",
    	["Gonzor"]              = "Gonzor",
    	["King Gnok"]           = "Kinggnok",
    	["King Mosh"]           = "KingMosh",
    	["Silithid Lurker"]     = "Silithidlurker",
    	["Volchan"]             = "Volchan",
    	["Lord Kazzak"]         = "LordKazzak",
    	["Winterspring Boss"]   = "WinterspringBoss",}

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

-- Internal zone name -> continent index. Used by the Find Marker panel
-- to filter by continent, and to sanity-check zone-name references.
-- Names are PE's internal names (from WorldMapArea.dbc), which preserve
-- PE's typos ("Aszhara", "Darnassis", "Ogrimmar", "Hilsbrad").
local ZONE_TO_CONTINENT = {
    -- Kalimdor
    Ashenvale           = 1, Aszhara        = 1, Barrens       = 1,
    Darkshore           = 1, Darnassis      = 1, Desolace      = 1,
    Durotar             = 1, Dustwallow     = 1, Felwood       = 1,
    Feralas             = 1, Moonglade      = 1, Mulgore       = 1,
    Ogrimmar            = 1, Silithus       = 1, StonetalonMountains = 1,
    Tanaris             = 1, Teldrassil     = 1, ThousandNeedles = 1,
    ThunderBluff        = 1, UngoroCrater   = 1, Winterspring  = 1,
    -- Eastern Kingdoms
    Alterac             = 2, Arathi         = 2, Badlands      = 2,
    BlastedLands        = 2, BurningSteppes = 2, DeadwindPass  = 2,
    DunMorogh           = 2, Duskwood       = 2, EasternPlaguelands = 2,
    Elwynn              = 2, Hilsbrad       = 2, Hinterlands   = 2,
    Ironforge           = 2, LochModan      = 2, Redridge      = 2,
    SearingGorge        = 2, Silverpine     = 2, Stormwind     = 2,
    Stranglethorn       = 2, SwampOfSorrows = 2, Tirisfal      = 2,
    Undercity           = 2, WesternPlaguelands = 2, Westfall   = 2,
    Wetlands            = 2,
    -- Project Epoch custom zones
    -- TODO: replace "TolBarad" with the exact string returned by GetMapInfo()
    -- while standing in Tol Barad. Run: /script print(GetMapInfo())
    TolBarad            = 2,
}

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

local pointsByMap        = {}        -- internalZoneName -> { entry, entry, ... }
local zoneNameToMap      = {}        -- internalZoneName -> {continent, zoneIdx}
local markerPool         = {}
local markerPoolCount    = 0
local activeMarkers      = {}
local activeMarkersCount = 0
local initialized        = false
local zoneNavBuilt       = false
local buildingZoneNav    = false
local lastZoneName       = nil
local lastUpdateTime     = 0
local frame              = CreateFrame("Frame")
local updateEnabled      = false
local flatDataCache
local pendingOriginName

-- ============================================================
-- Global namespace  (shared with ModernMapMarkers_UI.lua)
-- ============================================================

MMM = MMM or {}

function MMM.ForceRedraw()
    lastZoneName = nil
end

-- Build the internal-name -> (continent, zoneIdx) map by iterating every
-- zone on continents 1 and 2 via SetMapZoom + GetMapInfo. Must be called
-- once; guarded by zoneNavBuilt. Sets buildingZoneNav so UpdateMarkers
-- suppresses redraws triggered by the SetMapZoom side-effects.
-- Zones not discoverable via GetMapZones (Project Epoch custom content
-- that has no vanilla continent/zone index). Add entries here as PE
-- expands. Each entry maps an internal zone name to {continent, zoneIdx}.
--
-- TODO: replace the placeholder indices {2, 999} with real values from:
--   /script print(GetCurrentMapContinent(), GetCurrentMapZone())
--   (run while standing in Tol Barad with the world map open on that zone)
local ZONE_NAV_OVERRIDES = {
    TolBarad = {2, 22},  -- TODO: fill in real continent+zone index
}

local function BuildZoneNav()
    if zoneNavBuilt then return end
    buildingZoneNav = true

    local savedC = GetCurrentMapContinent()
    local savedZ = GetCurrentMapZone()

    for c = 1, 2 do
        local zones = { GetMapZones(c) }
        for z = 1, #zones do
            SetMapZoom(c, z)
            local internal = GetMapInfo()
            if internal then
                zoneNameToMap[internal] = {c, z}
            end
        end
    end

    -- Restore prior map view (best-effort).
    if savedC and savedC > 0 then
        if savedZ and savedZ > 0 then
            SetMapZoom(savedC, savedZ)
        else
            SetMapZoom(savedC)
        end
    end

    -- Merge PE custom zones that GetMapZones won't discover.
    for name, coords in pairs(ZONE_NAV_OVERRIDES) do
        if not zoneNameToMap[name] then
            zoneNameToMap[name] = coords
        end
    end

    zoneNavBuilt    = true
    buildingZoneNav = false
    MMM.ForceRedraw()
end

MMM.BuildZoneNav = BuildZoneNav

-- Low-level zone-name navigation. Returns true on success, false if the
-- zone is unknown. Does not play sounds, set pendingOriginName, or force
-- a redraw — callers decide those.
local function NavigateByName(zoneName)
    if not zoneNavBuilt then BuildZoneNav() end
    local m = zoneNameToMap[zoneName]
    if not m then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFF0000MMM: unknown destination zone \""
            .. tostring(zoneName) .. "\".|r")
        return false
    end
    SetMapZoom(m[1], m[2])
    return true
end

MMM.NavigateByName = NavigateByName

-- Called by the destination popup in ModernMapMarkers_UI.lua.
-- destName and originName are internal zone-name strings.
function MMM.NavigateToTransportDest(destName, originName)
    PlaySoundFile("Sound\\Interface\\MapPing.wav")
    if NavigateByName(destName) then
        pendingOriginName = originName
        MMM.ForceRedraw()
    end
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
    -- Entry format (flat list): { zoneName, x, y, name, type, info, atlasID [, slot8] }
    -- pointsByMap[zoneName] = { entry, entry, ... }  (entries stored verbatim)
    for i = 1, #MMM_DefaultPoints do
        local p    = MMM_DefaultPoints[i]
        local zone = p[1]
        local bucket = pointsByMap[zone]
        if not bucket then
            bucket = {}
            pointsByMap[zone] = bucket
        end
        tinsert(bucket, p)
    end
end

-- Returns a flat list of { continent, zoneName, name, type, description, atlasID }
-- for the Find Marker dropdown. Transport and portal types are excluded.
-- Built once on first call and cached for the session.
function MMM.GetFlatData()
    if flatDataCache then return flatDataCache end
    local result = {}
    local skip = {boat=true, zepp=true, tram=true, portal=true, pvp=true, flightpath=true}
    for i = 1, #MMM_DefaultPoints do
        local p    = MMM_DefaultPoints[i]
        local kind = p[5]
        local slot8 = p[8]
        if not skip[kind] and slot8 ~= "nolist" then
            tinsert(result, {
                continent   = ZONE_TO_CONTINENT[p[1]],
                zoneName    = p[1],
                name        = p[4],
                type        = kind,
                description = p[6],
                atlasID     = p[7],
            })
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
-- Atlas sort-mode compatibility
-- ============================================================

local mmmZoneID    = nil
local mmmAtlasType = nil
local mmmAtlasZone = nil

-- Scan ATLAS_DROPDOWNS for zoneID and park AtlasType/AtlasZone on its
-- position under the current sort layout.  Returns true if found.
local function ParkAtlasOnZone(zoneID)
    if not zoneID then return false end
    for t, zones in pairs(ATLAS_DROPDOWNS) do
        for z, id in pairs(zones) do
            if id == zoneID then
                AtlasOptions.AtlasType = t
                AtlasOptions.AtlasZone = z
                return true
            end
        end
    end
    return false
end

local function WithContinentSort(callback)
    if not AtlasOptions then
        callback()
        return
    end

    local savedSortBy = AtlasOptions.AtlasSortBy
    local needsSwitch = savedSortBy and savedSortBy ~= 1

    if needsSwitch then
        local savedType = AtlasOptions.AtlasType
        local savedZone = AtlasOptions.AtlasZone

        AtlasOptions.AtlasSortBy = 1
        Atlas_PopulateDropdowns()

        callback()

        local openedZoneID = ATLAS_DROPDOWNS[AtlasOptions.AtlasType]
                         and ATLAS_DROPDOWNS[AtlasOptions.AtlasType][AtlasOptions.AtlasZone]

        AtlasOptions.AtlasSortBy = savedSortBy
        Atlas_PopulateDropdowns()

        if not ParkAtlasOnZone(openedZoneID) then
            AtlasOptions.AtlasType = savedType
            AtlasOptions.AtlasZone = savedZone
        end
    else
        callback()
    end
end

local atlasToggleHooked = false
local function HookAtlasToggle()
    if atlasToggleHooked then return end
    if not Atlas_Toggle then return end
    atlasToggleHooked = true

    local original_Atlas_Toggle = Atlas_Toggle
    Atlas_Toggle = function()
        local willShow = not AtlasFrame:IsVisible()
        if willShow
            and mmmAtlasType
            and AtlasOptions
            and AtlasOptions.AtlasSortBy ~= 1
        then
            local savedType = mmmAtlasType
            local savedZone = mmmAtlasZone
            WithContinentSort(function()
                AtlasOptions.AtlasType = savedType
                AtlasOptions.AtlasZone = savedZone
                original_Atlas_Toggle()
            end)
        else
            original_Atlas_Toggle()
        end
    end

    local original_Type_OnClick = AtlasFrameDropDownType_OnClick
    AtlasFrameDropDownType_OnClick = function()
        mmmZoneID    = nil
        mmmAtlasType = nil
        mmmAtlasZone = nil
        original_Type_OnClick()
    end

    local original_Zone_OnClick = AtlasFrameDropDown_OnClick
    AtlasFrameDropDown_OnClick = function()
        mmmZoneID    = nil
        mmmAtlasType = nil
        mmmAtlasZone = nil
        original_Zone_OnClick()
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
    -- 1. Force load the WorldEvents module (where Volchan, etc. live)
    if not IsAddOnLoaded("AtlasLoot_WorldEvents") then
        LoadAddOn("AtlasLoot_WorldEvents")
    end

    -- 2. API Check: We only need the show function
    if not AtlasLoot_ShowBossLoot then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000MMM Error:|r AtlasLoot_ShowBossLoot function not found.")
        return
    end

    local bossName = this.markerName
    -- Use the atlasID from MarkerData.lua (e.g., "Volchan")
    local atlasID  = this.atlasID or (WORLD_BOSS_MAP and WORLD_BOSS_MAP[bossName])

    if not atlasID then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000MMM:|r No AtlasID mapping found for " .. tostring(bossName))
        return
    end

    -- 3. Close World Map so we can see the loot window
    if WorldMapFrame:IsVisible() and IsWorldMapFullscreen() then
        HideUIPanel(WorldMapFrame)
    end

    -- 4. Set the Anchor Frame
    -- Since AtlasFrame is missing, we use AtlasLootDefaultFrame (the Standalone window)
    local pFrame = AtlasLootDefaultFrame or UIParent

    -- 5. Show the Loot
    local ok, err = pcall(AtlasLoot_ShowBossLoot, atlasID, bossName, pFrame)
    
    if ok then
        PlaySoundFile(SOUND_CLICK)
        -- If it's the standalone browser, ensure it's actually visible
        if AtlasLootDefaultFrame then 
            AtlasLootDefaultFrame:Show() 
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000MMM Hook Error:|r " .. tostring(err))
    end
end

-- Resolve an atlasID to (type, zone) indices inside the currently populated
-- ATLAS_DROPDOWNS. Accepts either a string map key (e.g. "BlackrockDepths")
-- or, for backwards compatibility, a legacy numeric index under the
-- continent sort layout. Returns nil, nil if unresolvable.
local function ResolveAtlasID(atlasID, continent)
    if type(atlasID) == "string" then
        -- Search every dropdown list (continents + plugin categories)
        -- for an entry whose value equals atlasID. This is sort-mode
        -- independent and survives PE's extra/removed maps and any
        -- plugin reordering.
        for t, zones in pairs(ATLAS_DROPDOWNS) do
            for z, id in pairs(zones) do
                if id == atlasID then
                    return t, z
                end
            end
        end
        return nil, nil
    end
    -- Legacy numeric fallback. The old data format assumed SortBy=1
    -- (continent), with EK at type 1 and Kalimdor at type 2. This is
    -- fragile under PE because the map list differs from stock, so new
    -- data should use string keys instead.
    if type(atlasID) == "number" then
        local t = ATLAS_CONTINENT_MAP[continent] or 1
        if ATLAS_DROPDOWNS[t] and ATLAS_DROPDOWNS[t][atlasID] then
            return t, atlasID
        end
    end
    return nil, nil
end

local function OnAtlasClick()
    if not (this.atlasID and AtlasFrame and AtlasOptions) then return end
    PlaySoundFile(SOUND_CLICK)
    local atlasID = this.atlasID
    local continent = GetCurrentMapContinent()
    if WorldMapFrame:IsVisible() and IsWorldMapFullscreen() then
        HideUIPanel(WorldMapFrame)
    end
    WithContinentSort(function()
        -- Resolve inside the closure: WithContinentSort repopulates
        -- ATLAS_DROPDOWNS before calling us, so the search hits the
        -- SortBy=1 layout regardless of the user's saved sort mode.
        local atlasType, atlasZone = ResolveAtlasID(atlasID, continent)
        if not atlasType then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cFFFF0000MMM: Atlas map \""
                .. tostring(atlasID)
                .. "\" not available in this Atlas build.|r")
            return
        end
        AtlasOptions.AtlasType = atlasType
        AtlasOptions.AtlasZone = atlasZone
        Atlas_Refresh()
        AtlasFrame:SetFrameStrata("FULLSCREEN")
        local savedAutoSelect = AtlasOptions.AtlasAutoSelect
        AtlasOptions.AtlasAutoSelect = false
        AtlasFrame:Show()
        AtlasOptions.AtlasAutoSelect = savedAutoSelect
        -- Remember this page for HookAtlasToggle (manual re-opens).
        mmmAtlasType = atlasType
        mmmAtlasZone = atlasZone
        mmmZoneID = ATLAS_DROPDOWNS[atlasType] and ATLAS_DROPDOWNS[atlasType][atlasZone]
    end)
    if AtlasQuestFrame then AtlasQuestFrame:Show() end
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

-- Returns true if any destination of `pin` points at zone `zoneName`.
-- Shared by OnTransportClick (same-zone highlight) and UpdateMarkers
-- (return-transport pulse after a SetMapZoom).
local function PinMatchesZone(pin, zoneName)
    local d = pin.transportDest
    if not d then return false end
    if pin.isMultiDest then
        for i = 1, #d do
            if d[i][1] == zoneName then return true end
        end
        return false
    elseif pin.isDualDest then
        local a = type(d[1]) == "table" and d[1][1] or d[1]
        local b = type(d[2]) == "table" and d[2][1] or d[2]
        return a == zoneName or b == zoneName
    else  -- single
        if type(d) == "string" then return d == zoneName end
        return d[1] == zoneName
    end
end

-- Resolve a dest "choice" (either a string or a {"Name","nopulse"} table)
-- to its zone name and the nopulse flag.
local function ResolveChoice(choice)
    if type(choice) == "string" then return choice, false end
    return choice[1], choice[2] == "nopulse"
end

local function OnTransportClick()
    local dest = this.transportDest
    if not dest then return end

    -- Three or more destinations (any multi-form): delegate to popup menu.
    if this.isMultiDest then
        PlaySound("UChatScrollButton")
        MMM.ShowDestMenu(this)
        return
    end

    local destName, nopulse
    if this.isDualDest then
        -- arg1 is the mouse button name in an OnClick handler.
        local choice = (arg1 == "RightButton") and dest[2] or dest[1]
        destName, nopulse = ResolveChoice(choice)
    else
        -- Single dest: dest is either a bare zone-name string or a
        -- {"Name","nopulse"} table.
        destName, nopulse = ResolveChoice(dest)
    end

    if not zoneNavBuilt then BuildZoneNav() end

    local currentName = GetMapInfo()
    PlaySoundFile("Sound\\Interface\\MapPing.wav")

    -- Same-zone transport: highlight the return pin without navigating.
    if destName == currentName then
        local clicked = this
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin ~= clicked and pin.transportDest
               and PinMatchesZone(pin, currentName) then
                StartPinHighlight(pin)
                break
            end
        end
        return
    end

    -- Different zone: navigate via zoneNameToMap.
    local m = zoneNameToMap[destName]
    if not m then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFF0000MMM: unknown destination zone \""
            .. tostring(destName) .. "\".|r")
        return
    end
    if not nopulse then
        pendingOriginName = currentName
    end
    SetMapZoom(m[1], m[2])
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
    elseif dest == "nolist" then
        -- "nolist" only suppresses Find-panel inclusion; the pin itself
        -- has no navigable destination.
        dest = nil
    end

    -- Classify dest. Zone-name format (post-PE refactor):
    --   nil                         -> no nav
    --   "ZoneName"                  -> single
    --   {"ZoneName","nopulse"}      -> single, no return-pulse
    --   {"Zone1","Zone2"}           -> dual (left-click / right-click)
    --     each element can also be {"Zone","nopulse"}
    --   {{"Zone","Label"}, ...}     -> multi (popup)
    local isSingle, isDual, isMulti = false, false, false
    if type(dest) == "string" then
        isSingle = true
    elseif type(dest) == "table" then
        if type(dest[1]) == "table" then
            isMulti = true
        elseif type(dest[1]) == "string" then
            if dest[2] == "nopulse" then
                isSingle = true
            else
                isDual = true
            end
        end
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
    pin.isDualDest      = isDual
    pin.isMultiDest     = isMulti
    pin.isEmeraldDragon = (kind == "worldboss" and tooltipInfo == "60"
                           and not WORLD_BOSS_MAP[tooltipText]) or nil

    if isMulti then
        -- Hint lists labels; the popup handles navigation.
        local parts = {}
        for i = 1, #dest do
            tinsert(parts, dest[i][2] or dest[i][1] or ("Destination " .. i))
        end
        pin.markerHint = "|cFFFFD700Click for destinations:|r " .. tconcat(parts, ", ")
    elseif isDual then
        local a = type(dest[1]) == "table" and dest[1][1] or dest[1]
        local b = type(dest[2]) == "table" and dest[2][1] or dest[2]
        pin.markerHint = "|cFFFFD700Left-click:|r " .. a
                      .. "   |cFFFFD700Right-click:|r " .. b
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
            or this.markerKind == "tram" or this.markerKind == "portal"
            or this.markerKind == "pvp" or this.markerKind == "flightpath" then
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
    if buildingZoneNav then return end
    if not ModernMapMarkersDB.showMarkers or not WorldMapFrame:IsVisible() then return end

    -- Resolve the current zone by internal name. GetMapInfo() is authoritative
    -- (DBC-backed) and matches the keys in pointsByMap. We fall back to
    -- WorldMapFrameAreaLabel's text only when GetMapInfo returns nothing
    -- (e.g. an unusual PE map state); that fallback is localized display
    -- text and will not key into pointsByMap — which is fine, markers just
    -- won't render on that unknown map.
    local currentContinent = GetCurrentMapContinent()
    local currentZone      = GetCurrentMapZone()
    local currentLevel     = GetCurrentMapDungeonLevel()
    local currentName      = GetMapInfo()
    if not currentName and WorldMapFrameAreaLabel then
        local t = WorldMapFrameAreaLabel:GetText()
        if t and t ~= "" then currentName = t end
    end

    -- Only show markers on the top dungeon level.
    if currentLevel and currentLevel > 1 then
        if activeMarkersCount > 0 then ClearMarkers() end
        lastZoneName = nil
        return
    end

    -- Clear when inside an instance or on an invalid/continent-level map.
    if currentContinent == INVALID_ZONE or currentZone == INVALID_ZONE
       or not currentName then
        if activeMarkersCount > 0 then
            ClearMarkers()
            lastZoneName = nil
        end
        return
    end

    if currentName == lastZoneName then return end

    local now = GetTime()
    if now - lastUpdateTime < UPDATE_THROTTLE then return end
    lastUpdateTime = now

    lastZoneName = currentName

    ClearMarkers()

    local mapWidth  = WorldMapDetailFrame:GetWidth()
    local mapHeight = WorldMapDetailFrame:GetHeight()
    if mapWidth == 0 or mapHeight == 0 then return end

    local relevantPoints = pointsByMap[currentName]
    if not relevantPoints then return end

    local db               = ModernMapMarkersDB
    local showDungeons     = db.showDungeons
    local showRaids        = db.showRaids
    local showWorldBosses  = db.showWorldBosses
    local showBoats        = db.showBoats
    local showZeppelins    = db.showZeppelins
    local showTrams        = db.showTrams
    local showPortals      = db.showPortals
    local showPvP          = db.showPvP
    local showFlightPaths  = db.showFlightPaths
    local transportFaction = db.transportFaction
    local portalFaction    = db.portalFaction

    local texDungeon   = TEXTURES.dungeon
    local texRaid      = TEXTURES.raid
    local texWorldBoss = TEXTURES.worldboss
    local texZepp      = TEXTURES.zepp
    local texBoat      = TEXTURES.boat
    local texTram      = TEXTURES.tram
    local texPortal      = TEXTURES.portal
    local texPvp         = TEXTURES.pvp
    local texFlightPath  = TEXTURES.flightpath

    -- Entry fields (flat format):
    --   [1]=zoneName [2]=x [3]=y [4]=name [5]=kind [6]=info [7]=atlasID [8]=slot8
    local pointCount = #relevantPoints
    for i = 1, pointCount do
        local data    = relevantPoints[i]
        local kind    = data[5]
        local info    = data[6]
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
        elseif kind == "pvp" then
            shouldDisplay = showPvP
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texPvp
        elseif kind == "flightpath" then
            shouldDisplay = showFlightPaths
            if shouldDisplay and transportFaction ~= "all" then
                shouldDisplay = (info == transportFaction) or (info == "Neutral")
            end
            texture = texFlightPath
        end

        if shouldDisplay then
            local size = (kind == "boat" or kind == "zepp" or kind == "tram"
                or kind == "portal" or kind == "pvp" or kind == "flightpath")
                and MARKER_SIZE_SMALL or MARKER_SIZE_LARGE
            local pin = CreateMapPin(
                data[2] * mapWidth, data[3] * mapHeight,
                size, texture,
                data[4], info, data[7], kind, data[8])
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
    if pendingOriginName then
        local originName = pendingOriginName
        pendingOriginName = nil
        for i = 1, activeMarkersCount do
            local pin = activeMarkers[i]
            if pin and pin.transportDest and PinMatchesZone(pin, originName) then
                StartPinHighlight(pin)
                break
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
    showPortals        = true,
    showPvP            = true,
    showFlightPaths    = true,
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

local function PrimeAtlasSilently()
    if not Atlas_Refresh or not AtlasOptions then return end
    if not ATLAS_DROPDOWNS then return end
    WithContinentSort(function()
        -- Clamp AtlasType/AtlasZone to a position that actually exists
        -- before calling Atlas_Refresh. PE's Atlas fork omits many
        -- vanilla maps and has fewer dropdown types than stock (often
        -- just EK=1, Kalimdor=2, OutdoorRaids=3 under SortBy=1), so
        -- stale hardcoded values like (4, 15) made AtlasLoot's hooked
        -- Atlas_Refresh crash on pairs(ATLAS_DROPDOWNS[4]) == pairs(nil).
        local savedType = AtlasOptions.AtlasType
        local savedZone = AtlasOptions.AtlasZone

        local t = AtlasOptions.AtlasType
        if type(t) ~= "number" or type(ATLAS_DROPDOWNS[t]) ~= "table" then
            AtlasOptions.AtlasType = 1
            t = 1
        end
        local z = AtlasOptions.AtlasZone
        if type(z) ~= "number" or ATLAS_DROPDOWNS[t] == nil
           or ATLAS_DROPDOWNS[t][z] == nil then
            AtlasOptions.AtlasZone = 1
        end
        -- If even (1,1) is missing (shouldn't happen in practice), bail.
        if ATLAS_DROPDOWNS[AtlasOptions.AtlasType] == nil
           or ATLAS_DROPDOWNS[AtlasOptions.AtlasType][AtlasOptions.AtlasZone] == nil then
            AtlasOptions.AtlasType = savedType
            AtlasOptions.AtlasZone = savedZone
            return
        end
        Atlas_Refresh()

        -- Restore the user's last-viewed Atlas page if it pointed at a
        -- live entry. WithContinentSort already does this when a sort
        -- switch happened, but its same-sort fast path does not; doing
        -- it here covers both. ParkAtlasOnZone handles the case where
        -- the user's sort mode has since changed.
        if savedType and savedZone
           and ATLAS_DROPDOWNS[savedType]
           and ATLAS_DROPDOWNS[savedType][savedZone] ~= nil then
            AtlasOptions.AtlasType = savedType
            AtlasOptions.AtlasZone = savedZone
        end
    end)
end

local primerFrame = CreateFrame("Frame")

local function ScheduleAtlasPriming()
    primerFrame.timer = 0
    primerFrame:SetScript("OnUpdate", function()
        this.timer = this.timer + arg1
        if this.timer >= 0.5 then
            this:SetScript("OnUpdate", nil)
            PrimeAtlasSilently()
            HookAtlasToggle()
            -- Build the zone-name nav map here. PE has finished loading
            -- WorldMapArea.dbc by this point, and the world map isn't
            -- visible, so SetMapZoom side-effects are harmless.
            BuildZoneNav()
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
        lastZoneName = nil
        ScheduleAtlasPriming()

    elseif event == "WORLD_MAP_UPDATE" then
        if initialized then
            UpdateMarkers()
        end
    end
end)
