-- ModernMapMarkers_UI.lua (WotLK 3.3.5a)
-- Marker label, destination popup, filter dropdown, Find Marker panel, slash command.

local strfind    = string.find
local strsub     = string.sub
local tsort      = table.sort
local tinsert    = table.insert
local math_floor = math.floor
local math_min   = math.min
local sformat    = string.format
local slower     = string.lower

-- ============================================================
-- Marker label
-- ============================================================

local markerLabel

local function CreateMarkerLabel()
    markerLabel = CreateFrame("Frame", "MMMMarkerLabelFrame", WorldMapDetailFrame)
    markerLabel:SetFrameStrata("TOOLTIP")
    markerLabel:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 10)
    markerLabel:SetWidth(400)
    markerLabel:SetHeight(60)

    local areaLabel = WorldMapFrameAreaLabel
    markerLabel:SetPoint("TOP", areaLabel or WorldMapDetailFrame, "TOP", 0, areaLabel and 0 or -10)

    markerLabel.name = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.name:SetPoint("TOP", markerLabel, "TOP", 0, 0)
    markerLabel.name:SetJustifyH("CENTER")
    if areaLabel then
        local fn, fs, ff = areaLabel:GetFont()
        markerLabel.name:SetFont(fn, fs, ff)
        local r, g, b, a = areaLabel:GetShadowColor()
        markerLabel.name:SetShadowColor(r, g, b, a)
        local sx, sy = areaLabel:GetShadowOffset()
        markerLabel.name:SetShadowOffset(sx, sy)
        local tr, tg, tb = areaLabel:GetTextColor()
        markerLabel.name:SetTextColor(tr, tg, tb)
    else
        markerLabel.name:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE, THICKOUTLINE")
        markerLabel.name:SetShadowColor(0, 0, 0, 1)
        markerLabel.name:SetShadowOffset(1, -1)
        markerLabel.name:SetTextColor(1, 0.82, 0)
    end

    markerLabel.info = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.info:SetPoint("TOP", markerLabel.name, "BOTTOM", 0, -2)
    markerLabel.info:SetJustifyH("CENTER")
    markerLabel.info:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    markerLabel.info:SetShadowColor(0, 0, 0, 1)
    markerLabel.info:SetShadowOffset(1, -1)

    markerLabel.hint = markerLabel:CreateFontString(nil, "OVERLAY")
    markerLabel.hint:SetPoint("TOP", markerLabel.info, "BOTTOM", 0, -2)
    markerLabel.hint:SetJustifyH("CENTER")
    markerLabel.hint:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    markerLabel.hint:SetShadowColor(0, 0, 0, 1)
    markerLabel.hint:SetShadowOffset(1, -1)
    markerLabel.hint:SetTextColor(0.8, 0.8, 0.8)

    markerLabel:Hide()
end

local FACTION_COLORS = {
    Alliance = {0.15, 0.59, 0.75},
    Horde    = {0.89, 0.16, 0.10},
    Neutral  = {1,    0.82, 0   },
}

local function GetLevelColor(level)
    local delta = level - UnitLevel("player")
    if     delta >= 5  then return 1,    0.1,  0.1
    elseif delta >= 1  then return 1,    0.5,  0.25
    elseif delta >= -4 then return 1,    1,    0
    elseif delta >= -9 then return 0.25, 0.75, 0.25
    else                    return 0.6,  0.6,  0.6
    end
end

function MMM.ShowMarkerInfo(name, info, hint)
    if not markerLabel then CreateMarkerLabel() end
    if WorldMapFrameAreaLabel then WorldMapFrameAreaLabel:Hide() end
    markerLabel.name:SetText(name)

    if info and info ~= "" then
        local color = FACTION_COLORS[info]
        if color then
            markerLabel.info:SetTextColor(color[1], color[2], color[3])
            markerLabel.info:SetText("(" .. info .. ")")
        else
            local _, _, _, maxStr = strfind(info, "^(%d+)-(%d+)$")
            local maxLevel = tonumber(maxStr or info)
            if maxLevel then
                local r, g, b = GetLevelColor(maxLevel)
                markerLabel.info:SetTextColor(1, 0.82, 0)
                markerLabel.info:SetText("(Level " .. sformat("|cFF%02X%02X%02X%s|r", r*255, g*255, b*255, info) .. ")")
            else
                markerLabel.info:SetTextColor(1, 0.82, 0)
                markerLabel.info:SetText("(" .. info .. ")")
            end
        end
        markerLabel.info:Show()
    else
        markerLabel.info:Hide()
    end

    if hint and hint ~= "" then
        markerLabel.hint:SetText(hint); markerLabel.hint:Show()
    else
        markerLabel.hint:Hide()
    end
    markerLabel:Show()
end

function MMM.HideMarkerInfo()
    if markerLabel then markerLabel:Hide() end
    if WorldMapFrameAreaLabel then WorldMapFrameAreaLabel:Show() end
end

-- ============================================================
-- Destination popup menu (transports with 3+ destinations)
-- ============================================================

local destMenu
local destMenuPin

local function HideDestMenu()
    if destMenu then
        destMenu:Hide()
        destMenu.intercept:Hide()
    end
    destMenuPin = nil
end

function MMM.HideDestMenu() HideDestMenu() end

local function CreateDestMenu()
    destMenu = CreateFrame("Frame", "MMMDestMenu", WorldMapDetailFrame)
    destMenu:SetFrameStrata("TOOLTIP")
    destMenu:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 20)
    destMenu:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={left=4, right=4, top=4, bottom=4},
    })
    destMenu:SetBackdropColor(0, 0, 0, 0.85)
    destMenu.buttons = {}
    destMenu:Hide()

    destMenu.intercept = CreateFrame("Button", nil, WorldMapDetailFrame)
    destMenu.intercept:SetAllPoints(WorldMapDetailFrame)
    destMenu.intercept:SetFrameStrata("TOOLTIP")
    destMenu.intercept:SetFrameLevel(WorldMapDetailFrame:GetFrameLevel() + 19)
    destMenu.intercept:SetScript("OnClick", HideDestMenu)
    destMenu.intercept:Hide()
end

local MENU_BUTTON_HEIGHT = 22
local MENU_BUTTON_WIDTH  = 160
local MENU_PADDING       = 8

function MMM.ShowDestMenu(pin)
    if not destMenu then CreateDestMenu() end
    if destMenuPin == pin and destMenu:IsShown() then HideDestMenu(); return end

    destMenuPin = pin
    local dest  = pin.transportDest
    local count = #dest

    for i = 1, count do
        if not destMenu.buttons[i] then
            local btn = CreateFrame("Button", nil, destMenu)
            btn:SetHeight(MENU_BUTTON_HEIGHT)
            btn:SetNormalFontObject("GameFontNormalSmall")
            btn:SetHighlightFontObject("GameFontHighlightSmall")
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            btn:SetScript("OnClick", function()
                -- Multi-dest entries are {"ZoneName","Label"} tables.
                local d           = this.destTable[this.destIndex]
                local destName    = d[1]
                local currentName = GetMapInfo()
                HideDestMenu()
                if destName == currentName then
                    MMM.pendingHighlight = this.ownerName
                    MMM.UpdateMarkers()
                else
                    MMM.NavigateToTransportDest(destName, currentName)
                end
            end)
            destMenu.buttons[i] = btn
        end
        local btn = destMenu.buttons[i]
        btn.destIndex = i
        btn.destTable = dest
        btn.ownerName = pin.markerName
        btn:SetText(dest[i][2] or dest[i][1] or ("Destination " .. i))
        btn:SetWidth(MENU_BUTTON_WIDTH)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", destMenu, "TOPLEFT", MENU_PADDING, -(MENU_PADDING + (i-1)*MENU_BUTTON_HEIGHT))
        btn:Show()
    end

    for i = count + 1, #destMenu.buttons do destMenu.buttons[i]:Hide() end
    destMenu:SetWidth(MENU_BUTTON_WIDTH + MENU_PADDING * 2)
    destMenu:SetHeight(MENU_BUTTON_HEIGHT * count + MENU_PADDING * 2)
    destMenu:ClearAllPoints()
    destMenu:SetPoint("BOTTOMLEFT", pin, "TOPRIGHT", 4, -4)
    destMenu:Show()
    destMenu.intercept:Show()
end

-- ============================================================
-- Filter dropdown
-- ============================================================

local function ApplyChange()
    MMM.ForceRedraw()
    MMM.UpdateMarkers()
end

function InitFilterDropdown()
    local db = ModernMapMarkersDB

    local function addToggle(text, key)
        local info = {text=text, checked=db[key], keepShownOnClick=1}
        info.func = function() db[key] = not db[key]; ApplyChange() end
        UIDropDownMenu_AddButton(info, 1)
    end

    local function addHeader(text)
        UIDropDownMenu_AddButton({text=text, isTitle=1, notCheckable=1}, 1)
    end

    local function addFactionRadio(text, dbKey, value)
        local info = {text=text, keepShownOnClick=1}
        info.checked = function() return db[dbKey] == value end
        info.func = function()
            db[dbKey] = value
            ApplyChange()
            local i = 1
            while true do
                local btn = getglobal("DropDownList1Button"..i)
                if not btn then break end
                local chk = getglobal("DropDownList1Button"..i.."Check")
                if chk and type(btn.checked) == "function" then
                    if btn.checked() then chk:Show() else chk:Hide() end
                end
                i = i + 1
            end
        end
        UIDropDownMenu_AddButton(info, 1)
    end

    local info = {text="All Markers", checked=db.showMarkers, keepShownOnClick=1}
    info.func = function()
        db.showMarkers = not db.showMarkers
        if not db.showMarkers then MMM.ClearMarkers(); MMM.SetUpdateEnabled(false)
        else MMM.SetUpdateEnabled(true) end
        ApplyChange()
    end
    UIDropDownMenu_AddButton(info, 1)

    addToggle("Dungeons",     "showDungeons")
    addToggle("Raids",        "showRaids")
    addToggle("World Bosses", "showWorldBosses")
    addHeader("Transports")
    addToggle("Boats",        "showBoats")
    addToggle("Zeppelins",    "showZeppelins")
    addToggle("Trams",        "showTrams")
    addToggle("Portals",      "showPortals")
    addToggle("Flight Paths", "showFlightPaths")
    addHeader("Vendors")
    addToggle("PvP",          "showPvP")
    addHeader("Transport Faction")
    addFactionRadio("Show All",             "transportFaction", "all")
    addFactionRadio("|cFF2592C5Alliance|r", "transportFaction", "Alliance")
    addFactionRadio("|cFFE32A19Horde|r",    "transportFaction", "Horde")
    addHeader("Portal Faction")
    addFactionRadio("Show All",             "portalFaction", "all")
    addFactionRadio("|cFF2592C5Alliance|r", "portalFaction", "Alliance")
    addFactionRadio("|cFFE32A19Horde|r",    "portalFaction", "Horde")
end

-- ============================================================
-- Find Marker panel
-- ============================================================

local FIND_CONTINENTS = {
    {id=1, label="Kalimdor"},
    {id=2, label="Eastern Kingdoms"},
    {id=3, label="Outland"},
    {id=4, label="Northrend"},
}
local FIND_TYPES = {
    {id="dungeon",   label="Dungeons"},
    {id="raid",      label="Raids"},
    {id="worldboss", label="World Bosses"},
}

local PANEL_WIDTH      = 260
local ROW_HEIGHT       = 16
local MAX_VISIBLE_ROWS = 12
local BUTTON_HEIGHT    = 20
local BUTTON_SPACING   = 2
local PANEL_PADDING    = 8
local CONT_PER_ROW     = 2
local LIST_AREA_TOP    = PANEL_PADDING + (BUTTON_HEIGHT + BUTTON_SPACING) * 3 + 4

local findActiveContinent = 1
local findActiveType      = "dungeon"
local findDisplayList     = {}
local findScratchList     = {}   -- reused scratch, avoids alloc on each rebuild
local findVisibleTypes    = {}   -- reused in UpdateFindButtonStates
local findTotalSlots      = 0
local findPanel
local findContButtons     = {}
local findTypeButtons     = {}
local findRowButtons      = {}
local findScrollFrame

local function CreateSelectorButton(name, parent, width, text)
    local btn = CreateFrame("Button", name, parent)
    btn:SetWidth(width)
    btn:SetHeight(BUTTON_HEIGHT)
    btn:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=2, right=2, top=2, bottom=2},
    })
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    label:SetText(text)
    btn.label = label
    btn:SetScript("OnEnter", function()
        if not this.isActive then this:SetBackdropColor(0.3, 0.3, 0.3, 1) end
    end)
    btn:SetScript("OnLeave", function()
        if not this.isActive then this:SetBackdropColor(0.15, 0.15, 0.15, 1) end
    end)
    btn.isActive = false
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    return btn
end

local function SetSelectorActive(btn, active)
    btn.isActive = active
    if active then
        btn:SetBackdropColor(0.2, 0.4, 0.7, 1)
        btn:SetBackdropBorderColor(0.4, 0.6, 1.0, 1)
        btn.label:SetTextColor(1, 1, 1)
    else
        btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        btn.label:SetTextColor(0.8, 0.8, 0.8)
    end
end

local function SortByLevelThenName(a, b)
    local _, _, av = strfind(a.description or "", "^(%d+)")
    local _, _, bv = strfind(b.description or "", "^(%d+)")
    local an, bn = tonumber(av) or 0, tonumber(bv) or 0
    if an == bn then return (a.name or "") < (b.name or "") end
    return an < bn
end

local function DrawFindRows()
    local offset = FauxScrollFrame_GetOffset(findScrollFrame)
    for i = 1, MAX_VISIBLE_ROWS do
        local row     = findRowButtons[i]
        local slotIdx = offset + i
        -- Reset highlight before assigning new content.
        row.hlTex:Hide()

        if slotIdx <= findTotalSlots then
            local slot = findDisplayList[slotIdx]
            if slot.kind == "name" then
                row:EnableMouse(true)
                row.nameRow = nil
                row.nameText:SetTextColor(1, 1, 1)
                row.nameText:SetText(slot.text)
                row.lvlText:SetText(slot.lvlText or "")
                local rw = row.rowWidth or row:GetWidth()
                row.rowWidth = rw
                row.nameText:SetWidth(rw - row.lvlText:GetStringWidth() - 16)
                row.dataZoneName = slot.zoneName
                row.dataName     = slot.dataName
                if slot.hasComment and i < MAX_VISIBLE_ROWS then
                    row.hlTex:ClearAllPoints()
                    row.hlTex:SetPoint("TOPLEFT",     row, "TOPLEFT",     0,  0)
                    row.hlTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -ROW_HEIGHT)
                else
                    row.hlTex:SetAllPoints(row)
                end
            else
                local parent = findDisplayList[slotIdx - 1]
                row:EnableMouse(true)
                row.nameText:SetText(slot.text)
                row.nameText:SetTextColor(0.55, 0.55, 0.55)
                local rw = row.rowWidth or row:GetWidth()
                row.rowWidth = rw
                row.nameText:SetWidth(rw - 8)
                row.lvlText:SetText("")
                row.dataZoneName = parent.zoneName
                row.dataName     = parent.dataName
                row.nameRow      = findRowButtons[i - 1]
            end
            row:Show()
        else
            row.nameText:SetText("")
            row.lvlText:SetText("")
            row.nameText:SetTextColor(1, 1, 1)
            row.dataZoneName = nil
            row.dataName     = nil
            row.hlTex:SetAllPoints(row)
            row.nameRow = nil
            row:Hide()
        end
    end
end

local function RebuildFindList()
    local flatData = MMM.GetFlatData()
    wipe(findScratchList)
    for i = 1, #flatData do
        local d = flatData[i]
        if d.continent == findActiveContinent and d.type == findActiveType then
            tinsert(findScratchList, d)
        end
    end
    tsort(findScratchList, SortByLevelThenName)

    wipe(findDisplayList)
    for i = 1, #findScratchList do
        local data     = findScratchList[i]
        local baseName = data.name
        local comment
        local nl = strfind(baseName, "\n")
        if nl then
            comment  = strsub(baseName, nl + 1)
            baseName = strsub(baseName, 1, nl - 1)
        end

        local lvlStr = ""
        if data.description then
            local _, _, _, maxStr = strfind(data.description, "^(%d+)-(%d+)$")
            local maxLevel = tonumber(maxStr or data.description)
            if maxLevel then
                local r, g, b = GetLevelColor(maxLevel)
                lvlStr = sformat("Level |cff%02X%02X%02X%s|r", r*255, g*255, b*255, data.description)
            else
                lvlStr = "Level " .. data.description
            end
        end

        tinsert(findDisplayList, {
            kind="name", text=baseName, lvlText=lvlStr,
            zoneName=data.zoneName,
            dataName=data.name, hasComment=(comment ~= nil),
        })

        if comment then
            local s = comment
            local _, ce = strfind(s, "^|c%x%x%x%x%x%x%x%x")
            if ce then s = strsub(s, ce + 1) end
            local rs = strfind(s, "|r$")
            if rs then s = strsub(s, 1, rs - 1) end
            tinsert(findDisplayList, {kind="comment", text=s})
        end
    end

    findTotalSlots = #findDisplayList
    findPanel:SetHeight(LIST_AREA_TOP + math_min(findTotalSlots, MAX_VISIBLE_ROWS) * ROW_HEIGHT + PANEL_PADDING + 4)
    FauxScrollFrame_SetOffset(findScrollFrame, 0)
    FauxScrollFrame_Update(findScrollFrame, findTotalSlots, MAX_VISIBLE_ROWS, ROW_HEIGHT)
    DrawFindRows()
end

local function UpdateFindButtonStates()
    for i = 1, #FIND_CONTINENTS do
        SetSelectorActive(findContButtons[i], FIND_CONTINENTS[i].id == findActiveContinent)
    end

    local flatData    = MMM.GetFlatData()
    local typeVisible = {}
    for i = 1, #FIND_TYPES do typeVisible[i] = false end
    for di = 1, #flatData do
        local d = flatData[di]
        if d.continent == findActiveContinent then
            for i = 1, #FIND_TYPES do
                if FIND_TYPES[i].id == d.type then typeVisible[i] = true end
            end
        end
    end

    -- Fall back to first visible type if the active type has no data here.
    local valid = false
    for i = 1, #FIND_TYPES do
        if FIND_TYPES[i].id == findActiveType and typeVisible[i] then valid = true; break end
    end
    if not valid then
        for i = 1, #FIND_TYPES do
            if typeVisible[i] then findActiveType = FIND_TYPES[i].id; break end
        end
    end

    wipe(findVisibleTypes)
    for i = 1, #FIND_TYPES do
        if typeVisible[i] then tinsert(findVisibleTypes, findTypeButtons[i]); findTypeButtons[i]:Show()
        else findTypeButtons[i]:Hide() end
    end
    local n      = #findVisibleTypes
    local btnW   = (PANEL_WIDTH - PANEL_PADDING*2 - BUTTON_SPACING*(n-1)) / n
    local anchor = findContButtons[CONT_PER_ROW + 1]
    for j = 1, n do
        local btn = findVisibleTypes[j]
        btn:SetWidth(btnW)
        btn:ClearAllPoints()
        if j == 1 then
            btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -BUTTON_SPACING)
        else
            btn:SetPoint("TOPLEFT", findVisibleTypes[j-1], "TOPRIGHT", BUTTON_SPACING, 0)
        end
    end
    for i = 1, #FIND_TYPES do
        SetSelectorActive(findTypeButtons[i], FIND_TYPES[i].id == findActiveType)
    end
end

local function CreateFindPanel(anchorFrame)
    findPanel = CreateFrame("Frame", "MMMFindPanel", WorldMapFrame)
    findPanel:SetFrameStrata("HIGH")
    findPanel:SetFrameLevel(100)
    findPanel:SetWidth(PANEL_WIDTH)
    findPanel:SetHeight(100)
    findPanel:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", -16, 0)
    findPanel:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={left=4, right=4, top=4, bottom=4},
    })
    findPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    findPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    findPanel:Hide()

    local halfWidth = (PANEL_WIDTH - PANEL_PADDING*2 - BUTTON_SPACING) / 2
    for i = 1, #FIND_CONTINENTS do
        local cont = FIND_CONTINENTS[i]
        local col  = (i-1) % CONT_PER_ROW
        local row  = math_floor((i-1) / CONT_PER_ROW)
        local btn  = CreateSelectorButton("MMMFind_Cont"..i, findPanel, halfWidth, cont.label)
        if col == 0 then
            if row == 0 then
                btn:SetPoint("TOPLEFT", findPanel, "TOPLEFT", PANEL_PADDING, -PANEL_PADDING)
            else
                btn:SetPoint("TOPLEFT", findContButtons[i-CONT_PER_ROW], "BOTTOMLEFT", 0, -BUTTON_SPACING)
            end
        else
            btn:SetPoint("TOPLEFT", findContButtons[i-1], "TOPRIGHT", BUTTON_SPACING, 0)
        end
        local c = cont.id
        btn:SetScript("OnClick", function()
            findActiveContinent = c; UpdateFindButtonStates(); RebuildFindList()
        end)
        findContButtons[i] = btn
    end

    local numType  = #FIND_TYPES
    local typeWidth = (PANEL_WIDTH - PANEL_PADDING*2 - BUTTON_SPACING*(numType-1)) / numType
    local contRow2 = findContButtons[CONT_PER_ROW + 1]
    for i = 1, numType do
        local tp  = FIND_TYPES[i]
        local btn = CreateSelectorButton("MMMFind_Type"..i, findPanel, typeWidth, tp.label)
        if i == 1 then
            btn:SetPoint("TOPLEFT", contRow2, "BOTTOMLEFT", 0, -BUTTON_SPACING)
        else
            btn:SetPoint("TOPLEFT", findTypeButtons[i-1], "TOPRIGHT", BUTTON_SPACING, 0)
        end
        local t = tp.id
        btn:SetScript("OnClick", function()
            findActiveType = t; UpdateFindButtonStates(); RebuildFindList()
        end)
        findTypeButtons[i] = btn
    end

    findScrollFrame = CreateFrame("ScrollFrame", "MMMFindScroll", findPanel, "FauxScrollFrameTemplate")
    findScrollFrame:SetPoint("TOPLEFT",     findPanel, "TOPLEFT",     PANEL_PADDING,      -LIST_AREA_TOP)
    findScrollFrame:SetPoint("BOTTOMRIGHT", findPanel, "BOTTOMRIGHT", -PANEL_PADDING - 22, PANEL_PADDING)
    findScrollFrame:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(this, arg1, ROW_HEIGHT, DrawFindRows)
    end)

    for i = 1, MAX_VISIBLE_ROWS do
        local row = CreateFrame("Button", "MMMFind_Row"..i, findPanel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", findScrollFrame, "TOPLEFT", 0, -((i-1)*ROW_HEIGHT))
        row:SetPoint("RIGHT",   findScrollFrame, "RIGHT",   0,  0)

        local hlTex = row:CreateTexture(nil, "OVERLAY")
        hlTex:SetAllPoints(row)
        hlTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hlTex:SetBlendMode("ADD")
        hlTex:SetAlpha(0.7)
        hlTex:Hide()
        row.hlTex = hlTex

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT",     row, "TOPLEFT",     4, 0)
        nameText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetJustifyV("MIDDLE")
        row.nameText = nameText

        local lvlText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lvlText:SetPoint("TOPRIGHT",    row, "TOPRIGHT",    -4, 0)
        lvlText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
        lvlText:SetJustifyH("RIGHT")
        lvlText:SetJustifyV("MIDDLE")
        row.lvlText = lvlText

        row:SetScript("OnClick", function()
            if this.dataZoneName then
                MMM.FindMarker(this.dataZoneName, this.dataName)
            end
        end)
        row:SetScript("OnEnter", function()
            if this.dataName then
                if this.nameRow then this.nameRow.hlTex:Show() else this.hlTex:Show() end
            end
        end)
        row:SetScript("OnLeave", function()
            if this.nameRow then this.nameRow.hlTex:Hide() else this.hlTex:Hide() end
        end)

        row:Hide()
        findRowButtons[i] = row
    end

    local origOnHide = WorldMapFrame:GetScript("OnHide")
    WorldMapFrame:SetScript("OnHide", function()
        if origOnHide then origOnHide(this) end
        findPanel:Hide()
    end)
end

-- ============================================================
-- Find Marker navigation
-- ============================================================

function MMM.FindMarker(zoneName, markerName)
    if not WorldMapFrame:IsVisible() then ShowUIPanel(WorldMapFrame) end
    PlaySoundFile("Sound\\Interface\\MapPing.wav")
    MMM.pendingHighlight = markerName
    if GetMapInfo() == zoneName then
        MMM.ForceRedraw()
        MMM.UpdateMarkers()
    else
        MMM.NavigateByName(zoneName)
    end
end

-- ============================================================
-- ElvUI skinning
-- ============================================================

-- elvuiE and elvuiS are set once and reused so we never call GetModule twice.
local elvuiE
local elvuiS
local elvuiSkinDropdownsDone = false
local elvuiSkinPanelDone     = false

local function ElvUI_SkinDropdowns()
    if elvuiSkinDropdownsDone then return end
    if not elvuiS then return end
    if MMMFilterDropdown then elvuiS:HandleDropDownBox(MMMFilterDropdown, 120) end
    if MMMFindDropdown   then elvuiS:HandleDropDownBox(MMMFindDropdown,   120) end
    elvuiSkinDropdownsDone = true
end

local function ElvUI_SkinPanel()
    if elvuiSkinPanelDone then return end
    if not elvuiS or not findPanel then return end

    findPanel:SetTemplate("Default")

    for i = 1, #FIND_CONTINENTS do
        if findContButtons[i] then elvuiS:HandleButton(findContButtons[i]) end
    end
    for i = 1, #FIND_TYPES do
        if findTypeButtons[i] then elvuiS:HandleButton(findTypeButtons[i]) end
    end

    if MMMFindScrollScrollBar then elvuiS:HandleScrollBar(MMMFindScrollScrollBar) end

    for i = 1, MAX_VISIBLE_ROWS do
        local row = findRowButtons[i]
        if row and row.hlTex then
            row.hlTex:SetTexture(elvuiE.Media.Textures.Highlight)
            row.hlTex:SetVertexColor(1, 1, 1, 0.3)
            row.hlTex:SetBlendMode("BLEND")
        end
    end

    elvuiSkinPanelDone = true
end

-- ============================================================
-- Dropdowns
-- ============================================================

local function PositionDropdowns()
    if not MMMFilterDropdown then return end

    -- Magnify minimode: WorldMap_ToggleSizeDown sets WORLDMAP_SETTINGS.size to
    -- WORLDMAP_WINDOWED_SIZE. In that state WorldMapPositioningGuide is not a
    -- reliable anchor, so pin the dropdowns just below the close button instead.
    local isMinimode = WORLDMAP_SETTINGS
                       and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE

    local hasMapster        = IsAddOnLoaded("Mapster")
    local hasQuestie        = IsAddOnLoaded("Questie-335")
    local hasWDM            = IsAddOnLoaded("WDM")
    local hasPfQuest        = (IsAddOnLoaded("pfQuest") or IsAddOnLoaded("pfQuest-wotlk")) and pfQuestMapDropdown ~= nil
    local hasElvUI          = elvuiS ~= nil
    local hasElvUISmallerMap = hasElvUI and elvuiE.global and elvuiE.global.general and elvuiE.global.general.smallerWorldMap
    MMMFilterDropdown:ClearAllPoints()
    if isMinimode then
        -- Anchor to the close button which exists and is correctly placed in
        -- both fullscreen and windowed (minimode) map frames.
        MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrameCloseButton, "BOTTOMLEFT", 18, -8)
    elseif hasPfQuest then
        -- pfQuest places pfQuestMapDropdown at TOPRIGHT of WorldMapButton.
        -- Stack MMM directly below it so they form a clean column.
        MMMFilterDropdown:SetPoint("TOPRIGHT", pfQuestMapDropdown, "BOTTOMRIGHT", 0, 0)
    elseif hasElvUISmallerMap then
        if (hasMapster and hasQuestie) or hasWDM then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrameCloseButton, "BOTTOMLEFT", 18, -79)
        elseif hasMapster then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrameCloseButton, "BOTTOMLEFT", 18, -50)
        elseif hasQuestie or hasWDM then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrameCloseButton, "BOTTOMLEFT", 18, -79)
        else
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrameCloseButton, "BOTTOMLEFT", 18, -50)
        end
    elseif hasElvUI then
        if (hasMapster and hasQuestie) or hasWDM then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", -18, -111)
        elseif hasMapster then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", -18, -79)
        elseif hasQuestie or hasWDM then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -188, -111)
        else
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -188, -79)
        end
    else
        if (hasMapster and hasQuestie) or hasWDM then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", 2, -111)
        elseif hasMapster then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", 2, -79)
        elseif hasQuestie or hasWDM then
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -168, -111)
        else
            MMMFilterDropdown:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -168, -79)
        end
    end
    MMMFindDropdown:ClearAllPoints()
    MMMFindDropdown:SetPoint("TOPRIGHT", MMMFilterDropdown, "BOTTOMRIGHT", 0, 0)

    -- Re-anchor the find panel if it was already created, so the next
    -- time it opens it uses the correct direction for the current mode.
    if findPanel then
        findPanel:Hide()  -- force closed on mode change; stale position is confusing
        findPanel:ClearAllPoints()
        if isMinimode then
            findPanel:SetPoint("BOTTOMRIGHT", MMMFindDropdown, "TOPRIGHT", -16, 0)
        else
            findPanel:SetPoint("TOPRIGHT", MMMFindDropdown, "BOTTOMRIGHT", -16, 0)
        end
    end
end

-- Public wrapper so Magnify (and any other addon) can re-position the
-- dropdowns after switching map modes without accessing the local upvalue.
function MMM.PositionDropdowns()
    PositionDropdowns()
end

-- Called once after ElvUI:Initialize() completes.
local function ElvUI_OnReady()
    if not ElvUI then return end
    elvuiE = ElvUI[1]
    if not elvuiE then return end
    elvuiS = elvuiE:GetModule("Skins")
    if not elvuiS then return end
    ElvUI_SkinDropdowns()
    PositionDropdowns()
    -- Panel skin deferred until panel is created (ElvUI_SkinPanel called from OnClick).
end

local function ElvUI_Hook()
    if not ElvUI then return end
    local E = ElvUI[1]
    if not E then return end
    if E.initialized then
        ElvUI_OnReady()
    else
        hooksecurefunc(E, "Initialize", ElvUI_OnReady)
    end
end

local function CreateDropdowns()
    local parent = WorldMapFrame
    local filterDropdown = CreateFrame("Frame", "MMMFilterDropdown", parent, "UIDropDownMenuTemplate")
    local findDropdown   = CreateFrame("Frame", "MMMFindDropdown",   parent, "UIDropDownMenuTemplate")
    local baseLevel = parent:GetFrameLevel() + 10

    filterDropdown:SetFrameStrata(parent:GetFrameStrata())
    filterDropdown:SetFrameLevel(baseLevel)
    findDropdown:SetFrameStrata(parent:GetFrameStrata())
    findDropdown:SetFrameLevel(baseLevel)

    local filterBtn = getglobal("MMMFilterDropdownButton")
    if filterBtn then filterBtn:SetFrameLevel(baseLevel + 2) end
    local findBtn = getglobal("MMMFindDropdownButton")
    if findBtn then findBtn:SetFrameLevel(baseLevel + 2) end

    PositionDropdowns()

    UIDropDownMenu_SetWidth(filterDropdown, 120)
    UIDropDownMenu_SetButtonWidth(filterDropdown, 125)
    UIDropDownMenu_SetWidth(findDropdown, 120)
    UIDropDownMenu_SetButtonWidth(findDropdown, 125)
    UIDropDownMenu_SetText(filterDropdown, "Filter Markers")
    UIDropDownMenu_SetText(findDropdown,   "Find Marker")
    UIDropDownMenu_Initialize(findDropdown, function() end)

    if findBtn then
        findBtn:SetScript("OnClick", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            if not findPanel then
                CreateFindPanel(findDropdown)
                ElvUI_SkinPanel()
            end
            if findPanel:IsShown() then
                findPanel:Hide()
            else
                -- Re-anchor the panel each time it opens so minimode
                -- (smaller frame, no room below) opens upward instead.
                findPanel:ClearAllPoints()
                local isMini = WORLDMAP_SETTINGS
                               and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
                if isMini then
                    findPanel:SetPoint("BOTTOMRIGHT", MMMFindDropdown, "TOPRIGHT", -16, 0)
                else
                    findPanel:SetPoint("TOPRIGHT", MMMFindDropdown, "BOTTOMRIGHT", -16, 0)
                end
                -- Open on the player's current continent if valid (1-4).
                local c = GetCurrentMapContinent()
                if c >= 1 and c <= 4 then findActiveContinent = c end
                UpdateFindButtonStates()
                RebuildFindList()
                findPanel:Show()
            end
        end)
    end
end

-- ============================================================
-- Slash command
-- ============================================================

SLASH_MMM1 = "/mmm"
SlashCmdList["MMM"] = function(msg)
    if msg and slower(msg) == "hints" then
        ModernMapMarkersDB.showTransportHints = not ModernMapMarkersDB.showTransportHints
        MMM.RefreshVisibleTooltip()
        return
    end
    if msg and slower(msg) == "debug" then
        -- Temporary diagnostic: dump current zone identity and the
        -- zone-name nav map. Removed before final release (Task 13).
        local cc   = GetCurrentMapContinent()
        local cz   = GetCurrentMapZone()
        local name = GetMapInfo() or "(nil)"
        local areaLabel = WorldMapFrameAreaLabel and WorldMapFrameAreaLabel:GetText() or "(nil)"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700MMM debug|r")
        DEFAULT_CHAT_FRAME:AddMessage("  GetCurrentMapContinent="..tostring(cc)
                                    .."  GetCurrentMapZone="..tostring(cz))
        DEFAULT_CHAT_FRAME:AddMessage("  GetMapInfo="..tostring(name))
        DEFAULT_CHAT_FRAME:AddMessage("  AreaLabel="..tostring(areaLabel))
        if MMM.BuildZoneNav then MMM.BuildZoneNav() end
        -- Enumerate C1/C2 zones via GetMapZones so the user can verify
        -- ordering and internal-name mapping.
        for c = 1, 2 do
            local zones = { GetMapZones(c) }
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cFF88CCFF  Continent "..c..": "..#zones.." zones|r")
            for z = 1, #zones do
                SetMapZoom(c, z)
                local internal = GetMapInfo() or "(?)"
                DEFAULT_CHAT_FRAME:AddMessage(
                    "    ["..c..","..z.."] "..zones[z].." -> "..internal)
            end
        end
        -- Restore a safe map view.
        if cc and cc > 0 then
            if cz and cz > 0 then SetMapZoom(cc, cz) else SetMapZoom(cc) end
        end
        return
    end
    if msg and msg ~= "" then return end
    if MMMFilterDropdown then
        if MMMFilterDropdown:IsShown() then MMMFilterDropdown:Hide()
        else MMMFilterDropdown:Show() end
    end
    if MMMFindDropdown then
        if MMMFindDropdown:IsShown() then
            MMMFindDropdown:Hide()
            if findPanel then findPanel:Hide() end
        else
            MMMFindDropdown:Show()
        end
    end
end

-- ============================================================
-- Initialisation
-- ============================================================

local function InitDropdowns()
    CreateDropdowns()
    if MMMFilterDropdown then
        UIDropDownMenu_Initialize(MMMFilterDropdown, InitFilterDropdown)
    end
    ElvUI_Hook()
end

-- Stock-UI fallback: re-position dropdowns when the user toggles map size
-- via Blizzard's built-in buttons. Magnify (and similar) call
-- MMM.PositionDropdowns() directly; this hook covers the no-Magnify case.
-- Idempotent with external callers.
local _origToggleSizeUp   = WorldMap_ToggleSizeUp
local _origToggleSizeDown = WorldMap_ToggleSizeDown
WorldMap_ToggleSizeUp   = function(...) if _origToggleSizeUp   then _origToggleSizeUp(...)   end PositionDropdowns() end
WorldMap_ToggleSizeDown = function(...) if _origToggleSizeDown then _origToggleSizeDown(...) end PositionDropdowns() end

local uiFrame = CreateFrame("Frame")
uiFrame:RegisterEvent("VARIABLES_LOADED")
uiFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
uiFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        InitDropdowns()
        this:UnregisterEvent("VARIABLES_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not MMMFilterDropdown then InitDropdowns() end
        PositionDropdowns()
        this:UnregisterEvent("PLAYER_ENTERING_WORLD")

        -- pfQuest creates pfQuestMapDropdown lazily inside AddWorldMapIntegration
        -- which may run after VARIABLES_LOADED. Re-position once on the first
        -- map open to guarantee pfQuestMapDropdown exists before we anchor to it.
        local mmmFirstMapOpen = true
        local origOnShow = WorldMapFrame:GetScript("OnShow")
        WorldMapFrame:SetScript("OnShow", function()
            if origOnShow then origOnShow(this) end
            if mmmFirstMapOpen then
                mmmFirstMapOpen = false
                PositionDropdowns()
            end
        end)

        -- Hook the size-toggle globals so minimode repositioning works
        -- even when Magnify is not installed. Magnify also calls
        -- MMM.PositionDropdowns() from its own SetupWorldMapFrame hook,
        -- so both paths are covered regardless of addon load order.
        local _origToggleSizeUp   = WorldMap_ToggleSizeUp
        local _origToggleSizeDown = WorldMap_ToggleSizeDown
        WorldMap_ToggleSizeUp = function(...)
            if _origToggleSizeUp then _origToggleSizeUp(...) end
            PositionDropdowns()
        end
        WorldMap_ToggleSizeDown = function(...)
            if _origToggleSizeDown then _origToggleSizeDown(...) end
            PositionDropdowns()
        end
    end
end)
