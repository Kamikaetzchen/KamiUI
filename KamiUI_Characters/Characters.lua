local UI = KamiUI

local Module = UI:NewModule("Characters")

Module.name = "KamiUI_Characters"
Module.version = "0.2.0"

local FRAME_WIDTH = 360
local FRAME_HEIGHT = 420
local SLOT_SIZE = 36
local SLOT_GAP = 3
local SIDEBAR_WIDTH = 165

local colors = {
    background = { 0.00, 0.00, 0.00, 0.25 },
    panel = { 0.00, 0.00, 0.00, 0.40 },
    slot = { 0.00, 0.00, 0.00, 0.55 },
    border = { 0.16, 0.16, 0.18, 1.00 },
    emptyBorder = { 0.22, 0.22, 0.24, 1.00 },
}

local function EnsureDatabase()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.characters = KamiUIDB.characters or {}

    return KamiUIDB.characters
end

local function SavePosition(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not frameX or not frameY or not parentX or not parentY then
        return
    end

    EnsureDatabase().position = {
        x = frameX - parentX,
        y = frameY - parentY,
    }
end

local function ApplySavedPosition(frame)
    local position = EnsureDatabase().position

    frame:ClearAllPoints()

    if position then
        frame:SetPoint(
            "CENTER",
            UIParent,
            "CENTER",
            position.x or 0,
            position.y or 0
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    end
end

local SLOT_LAYOUT = {
    -- left column
    { key = "HeadSlot",          label = "Head",      side = "LEFT",  row = 1 },
    { key = "NeckSlot",          label = "Neck",      side = "LEFT",  row = 2 },
    { key = "ShoulderSlot",      label = "Shoulder",  side = "LEFT",  row = 3 },
    { key = "BackSlot",          label = "Back",      side = "LEFT",  row = 4 },
    { key = "ChestSlot",         label = "Chest",     side = "LEFT",  row = 5 },
    { key = "ShirtSlot",         label = "Shirt",     side = "LEFT",  row = 6 },
    { key = "TabardSlot",        label = "Tabard",    side = "LEFT",  row = 7 },
    { key = "WristSlot",         label = "Wrist",     side = "LEFT",  row = 8 },

    -- right column
    { key = "HandsSlot",         label = "Hands",     side = "RIGHT", row = 1 },
    { key = "WaistSlot",         label = "Waist",     side = "RIGHT", row = 2 },
    { key = "LegsSlot",          label = "Legs",      side = "RIGHT", row = 3 },
    { key = "FeetSlot",          label = "Feet",      side = "RIGHT", row = 4 },
    { key = "Finger0Slot",       label = "Ring",      side = "RIGHT", row = 5 },
    { key = "Finger1Slot",       label = "Ring",      side = "RIGHT", row = 6 },
    { key = "Trinket0Slot",      label = "Trinket",   side = "RIGHT", row = 7 },
    { key = "Trinket1Slot",      label = "Trinket",   side = "RIGHT", row = 8 },

    -- bottom row
    { key = "MainHandSlot",      label = "Main Hand", side = "BOTTOM", column = 1 },
    { key = "SecondaryHandSlot", label = "Off Hand",  side = "BOTTOM", column = 2 },
    { key = "RangedSlot",        label = "Ranged",    side = "BOTTOM", column = 3 },
    { key = "AmmoSlot",          label = "Ammo",      side = "BOTTOM", column = 4, size = 24 },
}

local function SetBorderColor(button, color)
    for _, edge in ipairs(button.KamiBorders or {}) do
        edge:SetColorTexture(unpack(color))
    end
end

local function CreateBorder(parent, color)
    local edges = {}

    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    top:SetColorTexture(unpack(color))
    edges[#edges + 1] = top

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    bottom:SetColorTexture(unpack(color))
    edges[#edges + 1] = bottom

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    left:SetColorTexture(unpack(color))
    edges[#edges + 1] = left

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    right:SetColorTexture(unpack(color))
    edges[#edges + 1] = right

    return edges
end

local function GetFullPlayerName()
    local first, surname = UnitName("player")
    first = first or "Player"

    if surname and surname ~= "" then
        return first .. " " .. surname
    end

    return first
end

local function GetSlotID(slotKey)
    if not GetInventorySlotInfo then
        return nil
    end

    return GetInventorySlotInfo(slotKey)
end

local function TrimTitleLabel(title)
    if not title or title == "" then
        return "No Title"
    end

    local label = string.gsub(title, "%%s", "")
    label = string.gsub(label, "^%s+", "")
    label = string.gsub(label, "%s+$", "")
    label = string.gsub(label, "^,%s*", "")
    label = string.gsub(label, "%s*,%s*$", "")

    return label ~= "" and label or "No Title"
end

local function GetKnownTitles()
    local titles = {
        {
            id = -1,
            label = "No Title",
        },
    }

    if not GetNumTitles or not IsTitleKnown or not GetTitleName then
        return titles
    end

    for id = 1, GetNumTitles() do
        if IsTitleKnown(id) then
            titles[#titles + 1] = {
                id = id,
                label = TrimTitleLabel(GetTitleName(id)),
            }
        end
    end

    table.sort(titles, function(a, b)
        if a.id == -1 then
            return true
        elseif b.id == -1 then
            return false
        end

        return a.label < b.label
    end)

    return titles
end

local function GetTitledPlayerName()
    local name = GetFullPlayerName()
    local current = GetCurrentTitle and GetCurrentTitle() or -1

    if current and current > 0 and GetTitleName then
        local title = GetTitleName(current)

        if title and string.find(title, "%%s") then
            local ok, formatted = pcall(string.format, title, name)

            if ok and formatted then
                return formatted
            end
        end
    end

    return name
end

local function CreateEquipmentSlot(parent, definition)
    local button = CreateFrame("Button", nil, parent)
    local slotSize = definition.size or SLOT_SIZE

    button:SetSize(slotSize, slotSize)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(colors.slot))
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER")
    label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    label:SetTextColor(0.45, 0.45, 0.48)
    label:SetText(definition.label)
    button.label = label

    button.KamiBorders = CreateBorder(button, colors.emptyBorder)

    local rarityGlow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    rarityGlow:SetPoint("CENTER", button, "CENTER", 1, 0)
    rarityGlow:SetSize(slotSize + 26, slotSize + 26)
    rarityGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    rarityGlow:SetBlendMode("ADD")
    rarityGlow:SetAlpha(0.45)
    rarityGlow:Hide()
    button.KamiRarityGlow = rarityGlow

    button.slotKey = definition.key
    button.slotID = GetSlotID(definition.key)

    button:SetScript("OnEnter", function(self)
        if not self.slotID then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if GameTooltip:SetInventoryItem("player", self.slotID) then
            GameTooltip:Show()
        else
            GameTooltip:SetText(self.slotKey)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if not self.slotID then
            return
        end

        if mouseButton == "LeftButton" then
            PickupInventoryItem(self.slotID)
        elseif mouseButton == "RightButton" then
            UseInventoryItem(self.slotID)
        end
    end)

    button:SetScript("OnDragStart", function(self)
        if self.slotID then
            PickupInventoryItem(self.slotID)
        end
    end)

    button:SetScript("OnReceiveDrag", function(self)
        if self.slotID then
            PickupInventoryItem(self.slotID)
        end
    end)

    return button
end

local BOTTOM_SLOT_X = {
    MainHandSlot = -60,
    SecondaryHandSlot = -21,
    RangedSlot = 18,
    AmmoSlot = 61,
}

local function LayoutEquipmentSlot(button, definition, frame)
    local top = -58

    button:ClearAllPoints()

    if definition.side == "LEFT" then
        button:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            12,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    elseif definition.side == "RIGHT" then
        button:SetPoint(
            "TOPRIGHT",
            frame,
            "TOPRIGHT",
            -12,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    else
        button:SetPoint(
            "BOTTOM",
            frame,
            "BOTTOM",
            BOTTOM_SLOT_X[definition.key] or 0,
            definition.key == "AmmoSlot" and 20 or 14
        )
    end
end

local function UpdateRarityGlow(button, quality)
    local glow = button.KamiRarityGlow

    if not glow then
        return
    end

    if quality == nil or quality <= 1 then
        glow:Hide()
        return
    end

    local color = ITEM_QUALITY_COLORS
        and ITEM_QUALITY_COLORS[quality]

    if color then
        glow:SetVertexColor(color.r, color.g, color.b, 1)
        glow:Show()
    else
        glow:Hide()
    end
end

local function UpdateEquipmentSlot(button)
    local slotID = button.slotID

    if not slotID then
        button.icon:SetTexture(nil)
        button.label:Show()
        SetBorderColor(button, colors.emptyBorder)
        UpdateRarityGlow(button, nil)
        return
    end

    local texture = GetInventoryItemTexture("player", slotID)
    local link = GetInventoryItemLink("player", slotID)
    local quality = GetInventoryItemQuality
        and GetInventoryItemQuality("player", slotID)

    button.icon:SetTexture(texture)
    button.label:SetShown(not texture)
    SetBorderColor(button, colors.emptyBorder)

    if quality == nil and link and GetItemInfo then
        _, _, quality = GetItemInfo(link)
    end

    UpdateRarityGlow(button, quality)
end

local SetSidebarMode

local function UpdatePlayerInfo(frame)
    local name = GetTitledPlayerName()
    local level = UnitLevel("player") or 0
    local className, classFile = UnitClass("player")
    local classColor = classFile
        and RAID_CLASS_COLORS
        and RAID_CLASS_COLORS[classFile]

    if classColor then
        frame.name:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        frame.name:SetTextColor(1, 1, 1)
    end

    frame.name:SetText(name)
    frame.details:SetText(
        string.format(
            "Level %d %s",
            level,
            className or ""
        )
    )

    if frame.model and frame.model.SetUnit then
        frame.model:SetUnit("player")
    end
end

function Module:Refresh()
    if not self.frame then
        return
    end

    UpdatePlayerInfo(self.frame)

    for _, button in ipairs(self.frame.equipmentSlots or {}) do
        UpdateEquipmentSlot(button)
    end

    if self.frame.sidebar then
        SetSidebarMode(
            self.frame,
            self.frame.sidebar.mode or "stats"
        )
    end
end

function Module:Show()
    if not self.frame then
        return
    end

    self:Refresh()
    self.frame:Show()
end

function Module:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Module:Toggle()
    if not self.frame then
        return
    end

    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

local function CanAccessValue(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end

    if issecretvalue then
        return not issecretvalue(value)
    end

    return true
end

local function FormatStatValue(value, suffix)
    if not CanAccessValue(value) or type(value) ~= "number" then
        return "-"
    end

    if suffix then
        return string.format("%.1f%s", value, suffix)
    end

    return string.format("%.0f", value)
end

local function SafeCall(func, ...)
    if not func then
        return nil
    end

    local ok, a, b, c, d, e, f, g, h = pcall(func, ...)

    if not ok then
        return nil
    end

    return a, b, c, d, e, f, g, h
end

local function CreateSidebarRow(parent, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    row:SetHeight(18)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", 0, 0)
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetTextColor(0.82, 0.72, 0.22)
    row.label = label

    local value = row:CreateFontString(nil, "OVERLAY")
    value:SetPoint("RIGHT", 0, 0)
    value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    value:SetTextColor(0.90, 0.90, 0.92)
    row.value = value

    return row
end

local function UpdateStatsPane(frame)
    local pane = frame.sidebar and frame.sidebar.statsPane

    if not pane then
        return
    end

    local rows = pane.rows
    local health = UnitHealthMax and UnitHealthMax("player")
    local power = UnitPowerMax and UnitPowerMax("player")
    local powerName = "Power"

    if UnitPowerType then
        local _, token = UnitPowerType("player")

        if token and CanAccessValue(token) then
            powerName = token:sub(1, 1) .. token:sub(2):lower()
        end
    end

    rows.health.label:SetText("Health")
    rows.health.value:SetText(FormatStatValue(health))
    rows.power.label:SetText(powerName)
    rows.power.value:SetText(FormatStatValue(power))

    local attributes = {
        { "strength", "Strength", 1 },
        { "agility", "Agility", 2 },
        { "stamina", "Stamina", 3 },
        { "intellect", "Intellect", 4 },
        { "spirit", "Spirit", 5 },
    }

    for _, data in ipairs(attributes) do
        local effective = select(2, SafeCall(UnitStat, "player", data[3]))
        rows[data[1]].label:SetText(data[2])
        rows[data[1]].value:SetText(FormatStatValue(effective))
    end

    local _, effectiveArmor = SafeCall(UnitArmor, "player")
    rows.armor.value:SetText(FormatStatValue(effectiveArmor))

    local baseAP, posAP, negAP = SafeCall(UnitAttackPower, "player")
    local attackPower

    if CanAccessValue(baseAP)
        and CanAccessValue(posAP)
        and CanAccessValue(negAP)
        and type(baseAP) == "number"
        and type(posAP) == "number"
        and type(negAP) == "number"
    then
        attackPower = baseAP + posAP + negAP
    end

    rows.attackPower.value:SetText(FormatStatValue(attackPower))

    local crit = SafeCall(GetCritChance)
    rows.crit.value:SetText(FormatStatValue(crit, "%"))

    local hit = SafeCall(GetHitModifier)
    rows.hit.value:SetText(FormatStatValue(hit, "%"))
end

local function UpdateEquipmentPane(frame)
    local pane = frame.sidebar and frame.sidebar.equipmentPane

    if not pane then
        return
    end

    local ids = C_EquipmentSet
        and C_EquipmentSet.GetEquipmentSetIDs
        and SafeCall(C_EquipmentSet.GetEquipmentSetIDs)
        or {}

    if type(ids) ~= "table" then
        ids = {}
    end

    pane.setIDs = ids

    for index = 1, math.max(#ids, #pane.rows) do
        local row = pane.rows[index]

        if not row and index <= 10 then
            row = CreateFrame("Button", nil, pane)
            row:SetPoint("TOPLEFT", pane, "TOPLEFT", 6, -(34 + (index - 1) * 28))
            row:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -6, -(34 + (index - 1) * 28))
            row:SetHeight(26)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.04)
            row.background = bg

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", 2, 0)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.icon = icon

            local name = row:CreateFontString(nil, "OVERLAY")
            name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            name:SetJustifyH("LEFT")
            name:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            row.name = name

            local selected = row:CreateTexture(nil, "BORDER")
            selected:SetAllPoints()
            selected:SetColorTexture(1.0, 0.82, 0.0, 0.10)
            selected:Hide()
            row.selected = selected

            row:SetScript("OnClick", function(self)
                pane.selectedSetID = self.setID
                UpdateEquipmentPane(frame)
            end)

            row:SetScript("OnDoubleClick", function(self)
                if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
                    SafeCall(C_EquipmentSet.UseEquipmentSet, self.setID)
                elseif EquipmentManager_EquipSet then
                    SafeCall(EquipmentManager_EquipSet, self.setID)
                end
            end)

            pane.rows[index] = row
        end

        if row then
            local setID = ids[index]

            if setID then
                local name, icon, actualID, isEquipped =
                    SafeCall(C_EquipmentSet.GetEquipmentSetInfo, setID)

                row.setID = actualID or setID
                row.icon:SetTexture(icon)
                row.name:SetText(
                    isEquipped and ((name or "Set") .. "  |cff66ff66*|r")
                        or (name or "Set")
                )
                row.selected:SetShown(pane.selectedSetID == row.setID)
                row:Show()
            else
                row:Hide()
            end
        end
    end

    local hasSelection = pane.selectedSetID ~= nil
    pane.equip:SetEnabled(hasSelection)
    pane.save:SetEnabled(hasSelection)
end

SetSidebarMode = function(frame, mode)
    local sidebar = frame.sidebar

    if not sidebar then
        return
    end

    sidebar.mode = mode
    sidebar.statsPane:SetShown(mode == "stats")
    sidebar.equipmentPane:SetShown(mode == "equipment")

    sidebar.statsTab.background:SetColorTexture(
        1, 1, 1, mode == "stats" and 0.10 or 0.03
    )
    sidebar.equipmentTab.background:SetColorTexture(
        1, 1, 1, mode == "equipment" and 0.10 or 0.03
    )

    if mode == "stats" then
        UpdateStatsPane(frame)
    else
        UpdateEquipmentPane(frame)
    end
end

local function LayoutOuterTabs(frame)
    local offset = SIDEBAR_WIDTH + 4

    for index, tab in ipairs(frame.tabs or {}) do
        tab:ClearAllPoints()
        tab:SetPoint(
            "RIGHT",
            frame,
            "RIGHT",
            72 + offset,
            92 - (index - 1) * 24
        )
    end
end

local function CreateSidebar(frame)
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetSize(SIDEBAR_WIDTH, FRAME_HEIGHT - 50)
    sidebar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, -48)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sidebar:SetBackdropColor(0, 0, 0, 0.78)
    sidebar:SetBackdropBorderColor(unpack(colors.border))
    frame.sidebar = sidebar

    local statsTab = CreateFrame("Button", nil, sidebar)
    statsTab:SetPoint("TOPLEFT", 5, -5)
    statsTab:SetSize(72, 22)
    statsTab:SetNormalFontObject("GameFontNormalSmall")
    statsTab:SetHighlightFontObject("GameFontHighlightSmall")
    statsTab:SetText("Stats")
    statsTab.background = statsTab:CreateTexture(nil, "BACKGROUND")
    statsTab.background:SetAllPoints()
    statsTab.background:SetColorTexture(1, 1, 1, 0.10)
    statsTab:SetScript("OnClick", function()
        SetSidebarMode(frame, "stats")
    end)
    sidebar.statsTab = statsTab

    local equipmentTab = CreateFrame("Button", nil, sidebar)
    equipmentTab:SetPoint("LEFT", statsTab, "RIGHT", 4, 0)
    equipmentTab:SetSize(78, 22)
    equipmentTab:SetNormalFontObject("GameFontNormalSmall")
    equipmentTab:SetHighlightFontObject("GameFontHighlightSmall")
    equipmentTab:SetText("Equipment")
    equipmentTab.background = equipmentTab:CreateTexture(nil, "BACKGROUND")
    equipmentTab.background:SetAllPoints()
    equipmentTab.background:SetColorTexture(1, 1, 1, 0.03)
    equipmentTab:SetScript("OnClick", function()
        SetSidebarMode(frame, "equipment")
    end)
    sidebar.equipmentTab = equipmentTab

    local statsPane = CreateFrame("Frame", nil, sidebar)
    statsPane:SetPoint("TOPLEFT", 1, -31)
    statsPane:SetPoint("BOTTOMRIGHT", -1, 1)
    statsPane.rows = {}
    sidebar.statsPane = statsPane

    local statRows = {
        { key = "health", label = "Health" },
        { key = "power", label = "Power" },
        { key = "strength", label = "Strength" },
        { key = "agility", label = "Agility" },
        { key = "stamina", label = "Stamina" },
        { key = "intellect", label = "Intellect" },
        { key = "spirit", label = "Spirit" },
        { key = "armor", label = "Armor" },
        { key = "attackPower", label = "Attack Power" },
        { key = "crit", label = "Crit" },
        { key = "hit", label = "Hit" },
    }

    for index, data in ipairs(statRows) do
        local row = CreateSidebarRow(
            statsPane,
            -(8 + (index - 1) * 22)
        )
        row.label:SetText(data.label)
        row.value:SetText("-")
        statsPane.rows[data.key] = row
    end

    local equipmentPane = CreateFrame("Frame", nil, sidebar)
    equipmentPane:SetPoint("TOPLEFT", 1, -31)
    equipmentPane:SetPoint("BOTTOMRIGHT", -1, 1)
    equipmentPane.rows = {}
    equipmentPane:Hide()
    sidebar.equipmentPane = equipmentPane

    local empty = equipmentPane:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("TOP", 0, -12)
    empty:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    empty:SetTextColor(0.55, 0.55, 0.58)
    empty:SetText("Equipment Sets")
    equipmentPane.empty = empty

    local equip = CreateFrame("Button", nil, equipmentPane)
    equip:SetSize(58, 20)
    equip:SetPoint("BOTTOMLEFT", 8, 8)
    equip:SetNormalFontObject("GameFontNormalSmall")
    equip:SetHighlightFontObject("GameFontHighlightSmall")
    equip:SetText("Equip")
    equip:SetScript("OnClick", function()
        local setID = equipmentPane.selectedSetID

        if not setID then
            return
        end

        if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
            SafeCall(C_EquipmentSet.UseEquipmentSet, setID)
        elseif EquipmentManager_EquipSet then
            SafeCall(EquipmentManager_EquipSet, setID)
        end
    end)
    equipmentPane.equip = equip

    local save = CreateFrame("Button", nil, equipmentPane)
    save:SetSize(58, 20)
    save:SetPoint("LEFT", equip, "RIGHT", 6, 0)
    save:SetNormalFontObject("GameFontNormalSmall")
    save:SetHighlightFontObject("GameFontHighlightSmall")
    save:SetText("Save")
    save:SetScript("OnClick", function()
        local setID = equipmentPane.selectedSetID

        if setID
            and C_EquipmentSet
            and C_EquipmentSet.SaveEquipmentSet
        then
            SafeCall(C_EquipmentSet.SaveEquipmentSet, setID)
        end
    end)
    equipmentPane.save = save

    SetSidebarMode(frame, "stats")
end

local function CreateFrameUI()
    local frame = CreateFrame(
        "Frame",
        "KamiUICharacterFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(colors.background))
    frame:SetBackdropBorderColor(unpack(colors.border))

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(48)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetAllPoints()
    headerBackground:SetColorTexture(0.00, 0.00, 0.00, 0.45)

    local name = header:CreateFontString(nil, "OVERLAY")
    name:SetPoint("TOP", 0, -7)
    name:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.name = name

    local details = header:CreateFontString(nil, "OVERLAY")
    details:SetPoint("TOP", name, "BOTTOM", 0, -2)
    details:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    details:SetTextColor(0.72, 0.72, 0.75)
    frame.details = details

    local titleButton = CreateFrame("Button", nil, header)
    titleButton:SetPoint("TOPLEFT", header, "TOPLEFT", 70, -2)
    titleButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -70, -2)
    titleButton:SetHeight(22)
    frame.titleButton = titleButton

    local titleArrow = titleButton:CreateFontString(nil, "OVERLAY")
    titleArrow:SetPoint("LEFT", name, "RIGHT", 4, 0)
    titleArrow:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    titleArrow:SetTextColor(0.65, 0.65, 0.68)
    titleArrow:SetText("v")
    frame.titleArrow = titleArrow

    local titleMenu = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )
    titleMenu:SetPoint("TOP", header, "BOTTOM", 0, -2)
    titleMenu:SetWidth(220)
    titleMenu:SetFrameLevel(frame:GetFrameLevel() + 30)
    titleMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    titleMenu:SetBackdropColor(0, 0, 0, 0.94)
    titleMenu:SetBackdropBorderColor(unpack(colors.border))
    titleMenu:EnableMouse(true)
    titleMenu:EnableMouseWheel(true)
    titleMenu.buttons = {}
    titleMenu.offset = 0
    titleMenu:Hide()
    frame.titleMenu = titleMenu

    local function RebuildTitleMenu()
        local titles = GetKnownTitles()
        local maxVisible = 12
        local maxOffset = math.max(0, #titles - maxVisible)

        titleMenu.offset = math.max(
            0,
            math.min(titleMenu.offset or 0, maxOffset)
        )

        local visibleCount = math.min(maxVisible, #titles)

        for row = 1, maxVisible do
            local button = titleMenu.buttons[row]

            if not button then
                button = CreateFrame("Button", nil, titleMenu)
                button:SetHeight(19)
                button:SetPoint(
                    "TOPLEFT",
                    titleMenu,
                    "TOPLEFT",
                    4,
                    -(4 + (row - 1) * 19)
                )
                button:SetPoint(
                    "TOPRIGHT",
                    titleMenu,
                    "TOPRIGHT",
                    -4,
                    -(4 + (row - 1) * 19)
                )

                local text = button:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormalSmall"
                )
                text:SetPoint("LEFT", 3, 0)
                text:SetPoint("RIGHT", -3, 0)
                text:SetJustifyH("LEFT")
                button.text = text

                local highlight = button:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(1, 1, 1, 0.08)

                titleMenu.buttons[row] = button
            end

            local entry = titles[(titleMenu.offset or 0) + row]

            if entry then
                button.titleID = entry.id
                button.text:SetText(entry.label)
                button:SetScript("OnClick", function(self)
                    if SetCurrentTitle then
                        SetCurrentTitle(self.titleID)
                    end

                    titleMenu:Hide()
                    Module:Refresh()
                end)
                button:Show()
            else
                button:Hide()
            end
        end

        titleMenu:SetHeight(math.max(27, visibleCount * 19 + 8))
    end

    titleMenu:SetScript("OnMouseWheel", function(_, delta)
        local titles = GetKnownTitles()
        local maxOffset = math.max(0, #titles - 12)

        titleMenu.offset = math.max(
            0,
            math.min((titleMenu.offset or 0) - delta, maxOffset)
        )

        RebuildTitleMenu()
    end)

    titleButton:RegisterForDrag("LeftButton")
    titleButton:SetScript("OnDragStart", function(self)
        self.dragging = true
        titleMenu:Hide()
        frame:StartMoving()
    end)
    titleButton:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        SavePosition(frame)

        C_Timer.After(0, function()
            self.dragging = false
        end)
    end)
    titleButton:SetScript("OnClick", function(self)
        if self.dragging then
            return
        end

        if titleMenu:IsShown() then
            titleMenu:Hide()
            return
        end

        titleMenu.offset = 0
        RebuildTitleMenu()
        titleMenu:Show()
    end)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetNormalFontObject("GameFontNormal")
    close:SetHighlightFontObject("GameFontHighlight")
    close:SetText("x")
    close:SetScript("OnClick", function()
        Module:Hide()
    end)

    local modelPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    modelPanel:SetPoint("TOPLEFT", 51, -54)
    modelPanel:SetPoint("BOTTOMRIGHT", -51, 58)
    modelPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    modelPanel:SetBackdropColor(unpack(colors.panel))
    modelPanel:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)

    local model = CreateFrame("PlayerModel", nil, modelPanel)
    model:SetPoint("TOPLEFT", 1, -1)
    model:SetPoint("BOTTOMRIGHT", -1, 1)
    model:SetUnit("player")

    if model.SetPortraitZoom then
        model:SetPortraitZoom(0)
    end

    if model.SetPosition then
        model:SetPosition(0, 0, 0)
    end

    frame.model = model

    frame.equipmentSlots = {}
    frame.equipmentByKey = {}

    for _, definition in ipairs(SLOT_LAYOUT) do
        local button = CreateEquipmentSlot(frame, definition)
        LayoutEquipmentSlot(button, definition, frame)
        frame.equipmentSlots[#frame.equipmentSlots + 1] = button
        frame.equipmentByKey[definition.key] = button
    end

    local tabs = {
        { label = "Character", enabled = true },
        { label = "Reputation", enabled = false },
        { label = "Skills", enabled = false },
    }

    frame.tabs = {}

    for index, definition in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(72, 20)
        tab:SetPoint(
            "RIGHT",
            frame,
            "RIGHT",
            72,
            92 - (index - 1) * 24
        )
        tab:SetNormalFontObject("GameFontNormalSmall")
        tab:SetHighlightFontObject("GameFontHighlightSmall")
        tab:SetText(definition.label)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(
            definition.enabled and 0.08 or 0.03,
            definition.enabled and 0.08 or 0.03,
            definition.enabled and 0.10 or 0.04,
            0.95
        )

        CreateBorder(tab, colors.border)

        if not definition.enabled then
            tab:SetAlpha(0.45)
            tab:Disable()
        end

        frame.tabs[#frame.tabs + 1] = tab
    end

    CreateSidebar(frame)
    LayoutOuterTabs(frame)

    frame:SetScript("OnShow", function()
        Module:Refresh()
    end)

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()

        if frame.titleMenu then
            frame.titleMenu:Hide()
        end
    end)

    frame:EnableKeyboard(true)

    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
    end

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(false)
            end

            Module:Hide()
            return
        end

        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(true)
        end
    end)

    ApplySavedPosition(frame)
    tinsert(UISpecialFrames, frame:GetName())

    return frame
end

function Module:Initialize()
    EnsureDatabase()
    self.frame = CreateFrameUI()
    self:Refresh()

    local hotkeyButton = CreateFrame(
        "Button",
        "KamiUICharactersHotkeyButton",
        UIParent
    )

    hotkeyButton:SetScript("OnClick", function()
        Module:Toggle()
    end)

    self.hotkeyButton = hotkeyButton

    if SetOverrideBindingClick then
        SetOverrideBindingClick(
            hotkeyButton,
            true,
            "C",
            "KamiUICharactersHotkeyButton",
            "LeftButton"
        )
    end

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("UNIT_MODEL_CHANGED", function(_, unit)
        if unit == "player" then
            Module:Refresh()
        end
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("KNOWN_TITLES_UPDATE", function()
        Module:Refresh()

        if Module.frame
            and Module.frame.titleMenu
            and Module.frame.titleMenu:IsShown()
        then
            Module.frame.titleMenu:Hide()
        end
    end)

    UI:RegisterEvent("EQUIPMENT_SETS_CHANGED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("EQUIPMENT_SWAP_FINISHED", function()
        Module:Refresh()
    end)
end

Module:Initialize()
