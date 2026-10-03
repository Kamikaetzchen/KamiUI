local UI = KamiUI

local Module = UI:NewModule("Characters")

Module.name = "KamiUI_Characters"
Module.version = "0.2.0"

local CHARACTER_WIDTH = 333
local SIDEBAR_WIDTH = 165
local SPLIT_WIDTH = CHARACTER_WIDTH - 2
local LIST_CONTENT_WIDTH = SPLIT_WIDTH - 14
local FRAME_WIDTH = CHARACTER_WIDTH + SIDEBAR_WIDTH
local FRAME_HEIGHT = 420
local HEADER_HEIGHT = 40
local SLOT_SIZE = 36
local SLOT_GAP = 3

local colors = {
    background = { 0.00, 0.00, 0.00, 0.40 },
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
    local pane = frame.characterPane or frame
    local top = -58

    button:ClearAllPoints()

    if definition.side == "LEFT" then
        button:SetPoint(
            "TOPLEFT",
            pane,
            "TOPLEFT",
            12,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    elseif definition.side == "RIGHT" then
        button:SetPoint(
            "TOPRIGHT",
            pane,
            "TOPRIGHT",
            -12,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    else
        button:SetPoint(
            "BOTTOM",
            pane,
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
local SetOuterPage

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

    if SetOuterPage then
        SetOuterPage(
            self.frame,
            self.frame.page or "character"
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


local function GetFactionData(index)
    if not C_Reputation or not C_Reputation.GetFactionDataByIndex then
        return nil
    end

    local data = SafeCall(C_Reputation.GetFactionDataByIndex, index)

    if type(data) ~= "table" then
        return nil
    end

    return data
end

local function GetFactionStandingLabel(reaction)
    if type(reaction) ~= "number" then
        return ""
    end

    local globalLabel = _G["FACTION_STANDING_LABEL" .. reaction]

    if type(globalLabel) == "string" then
        return globalLabel
    end

    if GetText then
        local label = SafeCall(
            GetText,
            "FACTION_STANDING_LABEL" .. reaction,
            UnitSex and UnitSex("player") or 2
        )

        if type(label) == "string" then
            return label
        end
    end

    return ""
end

local function GetFactionBarColor(reaction)
    local color = FACTION_BAR_COLORS
        and FACTION_BAR_COLORS[reaction or 4]

    if color then
        return color.r or color[1] or 0.18,
            color.g or color[2] or 0.55,
            color.b or color[3] or 0.18
    end

    return 0.18, 0.55, 0.18
end

local function SetReputationOptionState(option, checked, enabled)
    if checked then
        option.mark:Show()
    else
        option.mark:Hide()
    end

    if enabled then
        option:Enable()
        option:SetAlpha(1)
    else
        option:Disable()
        option:SetAlpha(0.45)
    end
end

local function CreateSidebarRow(parent, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    row:SetHeight(18)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", 0, 0)
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetTextColor(0.92, 0.92, 0.94)
    row.label = label

    local value = row:CreateFontString(nil, "OVERLAY")
    value:SetPoint("RIGHT", 0, 0)
    value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    value:SetTextColor(0.90, 0.90, 0.92)
    row.value = value

    return row
end

local function CreateSidebarHeader(parent, y, text)
    local header = CreateFrame("Button", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, y)
    header:SetHeight(17)

    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0.055)

    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", 0, 0)
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetTextColor(0.88, 0.72, 0.16)
    label:SetText(text)
    header.label = label

    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.04)

    return header
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

    local moveSpeed
    local currentSpeed, runSpeed = GetUnitSpeed
        and SafeCall(GetUnitSpeed, "player")
    local speed = runSpeed or currentSpeed
    local baseSpeed = BASE_MOVEMENT_SPEED or 7

    if CanAccessValue(speed)
        and type(speed) == "number"
        and speed >= 0
        and baseSpeed > 0
    then
        moveSpeed = speed / baseSpeed * 100
    end

    rows.moveSpeed.value:SetText(FormatStatValue(moveSpeed, "%"))

    local attributes = {
        { "strength", 1 },
        { "agility", 2 },
        { "stamina", 3 },
        { "intellect", 4 },
        { "spirit", 5 },
    }

    for _, data in ipairs(attributes) do
        local effective = select(2, SafeCall(UnitStat, "player", data[2]))
        rows[data[1]].value:SetText(FormatStatValue(effective))
    end

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
    rows.crit.value:SetText(FormatStatValue(SafeCall(GetCritChance), "%"))
    rows.hit.value:SetText(FormatStatValue(SafeCall(GetHitModifier), "%"))

    local _, effectiveArmor = SafeCall(UnitArmor, "player")
    rows.armor.value:SetText(FormatStatValue(effectiveArmor))
    rows.dodge.value:SetText(FormatStatValue(SafeCall(GetDodgeChance), "%"))
    rows.parry.value:SetText(FormatStatValue(SafeCall(GetParryChance), "%"))
    rows.block.value:SetText(FormatStatValue(SafeCall(GetBlockChance), "%"))

    local resistances = {
        { "fire", 2 },
        { "nature", 3 },
        { "frost", 4 },
        { "shadow", 5 },
        { "arcane", 6 },
    }

    for _, data in ipairs(resistances) do
        local base, total = SafeCall(UnitResistance, "player", data[2])
        local value = total

        if not CanAccessValue(value) or type(value) ~= "number" then
            value = base
        end

        rows[data[1]].value:SetText(FormatStatValue(value))
    end
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

            row:SetScript("OnEnter", function(self)
                if not self.setID then
                    return
                end

                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

                if GameTooltip.SetEquipmentSet then
                    GameTooltip:SetEquipmentSet(self.setID)
                    GameTooltip:Show()
                end
            end)

            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            pane.rows[index] = row
        end

        if row then
            local setID = ids[index]

            if setID then
                local name, icon, actualID, isEquipped,
                    _, _, _, numLost =
                    SafeCall(C_EquipmentSet.GetEquipmentSetInfo, setID)

                row.setID = actualID or setID
                row.icon:SetTexture(icon)
                row.name:SetText(name or "Set")

                if numLost and numLost > 0 then
                    row.name:SetTextColor(1.0, 0.28, 0.28)
                else
                    row.name:SetTextColor(0.92, 0.92, 0.94)
                end

                if isEquipped then
                    row.background:SetColorTexture(0.10, 0.52, 0.18, 0.26)
                else
                    row.background:SetColorTexture(1, 1, 1, 0.04)
                end

                row.selected:SetShown(
                    pane.selectedSetID == row.setID and not isEquipped
                )
                row.isEquipped = isEquipped == true
                row:Show()
            else
                row:Hide()
            end
        end
    end

    local hasSelection = pane.selectedSetID ~= nil
    local selectedEquipped = false

    if hasSelection and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
        local _, _, _, isEquipped =
            SafeCall(C_EquipmentSet.GetEquipmentSetInfo, pane.selectedSetID)
        selectedEquipped = isEquipped == true
    end

    pane.equip:SetEnabled(hasSelection and not selectedEquipped)
    pane.save:SetEnabled(hasSelection and not selectedEquipped)
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
        1, 1, 1, mode == "stats" and 0.18 or 0.07
    )
    sidebar.equipmentTab.background:SetColorTexture(
        1, 1, 1, mode == "equipment" and 0.18 or 0.07
    )

    if mode == "stats" then
        UpdateStatsPane(frame)
    else
        UpdateEquipmentPane(frame)
    end
end


local function CreateReputationOption(parent, labelText, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    button:SetHeight(20)

    local box = CreateFrame("Frame", nil, button)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)

    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    CreateBorder(box, colors.border)

    local mark = box:CreateFontString(nil, "OVERLAY")
    mark:SetPoint("CENTER", 0, 0)
    mark:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    mark:SetTextColor(0.90, 0.76, 0.18)
    mark:SetText("x")
    mark:Hide()
    button.mark = mark

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", box, "RIGHT", 7, 0)
    label:SetPoint("RIGHT", button, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetTextColor(0.90, 0.78, 0.22)
    label:SetText(labelText)
    button.label = label

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -2)
    highlight:SetColorTexture(1, 1, 1, 0.05)

    return button
end

local function UpdateReputationDetails(frame, index)
    local pane = frame.reputationPane

    if not pane then
        return
    end

    local data = index and GetFactionData(index)

    if not data or (data.isHeader and not data.isHeaderWithRep) then
        pane.selectedIndex = nil
        pane.detailName:SetText("Select a faction")
        pane.detailStanding:SetText("")
        pane.detailDescription:SetText("")
        pane.detailBar:SetMinMaxValues(0, 1)
        pane.detailBar:SetValue(0)
        pane.detailValue:SetText("")
        SetReputationOptionState(pane.atWarOption, false, false)
        SetReputationOptionState(pane.inactiveOption, false, false)
        SetReputationOptionState(pane.watchedOption, false, false)
        return
    end

    pane.selectedIndex = index
    pane.selectedFactionID = data.factionID

    local reaction = tonumber(data.reaction) or 4
    local lower = tonumber(data.currentReactionThreshold) or 0
    local upper = tonumber(data.nextReactionThreshold) or lower
    local standing = tonumber(data.currentStanding) or lower
    local current = math.max(0, standing - lower)
    local maximum = math.max(1, upper - lower)
    local r, g, b = GetFactionBarColor(reaction)

    pane.detailName:SetText(data.name or "Faction")
    pane.detailStanding:SetText(GetFactionStandingLabel(reaction))
    pane.detailDescription:SetText(data.description or "")
    pane.detailBar:SetMinMaxValues(0, maximum)
    pane.detailBar:SetValue(math.min(maximum, current))
    pane.detailBar:SetStatusBarColor(r, g, b, 0.85)
    pane.detailValue:SetText(
        string.format("%d / %d", current, maximum)
    )

    local isActive = true

    if C_Reputation and C_Reputation.IsFactionActive then
        local active = SafeCall(C_Reputation.IsFactionActive, index)

        if type(active) == "boolean" then
            isActive = active
        end
    end

    SetReputationOptionState(
        pane.atWarOption,
        data.atWarWith == true,
        data.canToggleAtWar == true
    )
    SetReputationOptionState(
        pane.inactiveOption,
        not isActive,
        data.canSetInactive == true
    )
    SetReputationOptionState(
        pane.watchedOption,
        data.isWatched == true,
        data.factionID ~= nil
    )
end

local function UpdateReputationPane(frame)
    local pane = frame.reputationPane

    if not pane or not C_Reputation or not C_Reputation.GetNumFactions then
        return
    end

    local numFactions = tonumber(
        SafeCall(C_Reputation.GetNumFactions)
    ) or 0
    local y = -4
    local selectedIndex

    for index = 1, math.max(numFactions, #pane.rows) do
        local row = pane.rows[index]

        if not row and index <= numFactions then
            row = CreateFrame("Button", nil, pane.listContent)

            local background = row:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints()
            background:SetColorTexture(0, 0, 0, 0)
            row.background = background

            local name = row:CreateFontString(nil, "OVERLAY")
            name:SetJustifyH("LEFT")
            name:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            row.name = name

            local bar = CreateFrame("StatusBar", nil, row)
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            row.bar = bar

            local barBackground = bar:CreateTexture(nil, "BACKGROUND")
            barBackground:SetAllPoints()
            barBackground:SetColorTexture(0, 0, 0, 0.50)

            local rank = bar:CreateFontString(nil, "OVERLAY")
            rank:SetPoint("CENTER", 0, 0)
            rank:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            rank:SetTextColor(0.92, 0.92, 0.94)
            row.rank = rank

            local selected = row:CreateTexture(nil, "BORDER")
            selected:SetAllPoints()
            selected:SetColorTexture(1, 1, 1, 0.09)
            selected:Hide()
            row.selected = selected

            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.06)

            pane.rows[index] = row
        end

        if row then
            local data = index <= numFactions and GetFactionData(index)

            if data then
                row.index = index
                row.factionID = data.factionID
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", pane.listContent, "TOPLEFT", 4, y)
                row:SetPoint("TOPRIGHT", pane.listContent, "TOPRIGHT", -4, y)

                if data.isHeader then
                    row:SetHeight(22)
                    row.background:SetColorTexture(1, 1, 1, 0.055)
                    row.name:ClearAllPoints()
                    row.name:SetPoint("LEFT", 6, 0)
                    row.name:SetPoint("RIGHT", -6, 0)
                    row.name:SetTextColor(0.88, 0.72, 0.16)
                    row.name:SetText(
                        string.format(
                            "%s %s",
                            data.isCollapsed and "+" or "-",
                            data.name or "Group"
                        )
                    )
                    row.bar:Hide()
                    row.selected:Hide()
                    row:SetScript("OnClick", function(self)
                        local headerData = GetFactionData(self.index)

                        if not headerData then
                            return
                        end

                        if headerData.isCollapsed then
                            if C_Reputation.ExpandFactionHeader then
                                SafeCall(
                                    C_Reputation.ExpandFactionHeader,
                                    self.index
                                )
                            end
                        elseif C_Reputation.CollapseFactionHeader then
                            SafeCall(
                                C_Reputation.CollapseFactionHeader,
                                self.index
                            )
                        end

                        UpdateReputationPane(frame)
                    end)

                    y = y - 24
                else
                    local reaction = tonumber(data.reaction) or 4
                    local lower = tonumber(data.currentReactionThreshold) or 0
                    local upper = tonumber(data.nextReactionThreshold) or lower
                    local standing = tonumber(data.currentStanding) or lower
                    local current = math.max(0, standing - lower)
                    local maximum = math.max(1, upper - lower)
                    local r, g, b = GetFactionBarColor(reaction)

                    row:SetHeight(30)
                    row.background:SetColorTexture(0, 0, 0, 0)
                    row.name:ClearAllPoints()
                    row.name:SetPoint(
                        "TOPLEFT",
                        data.isChild and 18 or 8,
                        -3
                    )
                    row.name:SetPoint("TOPRIGHT", -8, -3)
                    row.name:SetTextColor(0.92, 0.92, 0.94)
                    row.name:SetText(data.name or "Faction")

                    row.bar:ClearAllPoints()
                    row.bar:SetPoint("BOTTOMLEFT", 8, 3)
                    row.bar:SetPoint("BOTTOMRIGHT", -8, 3)
                    row.bar:SetHeight(10)
                    row.bar:SetMinMaxValues(0, maximum)
                    row.bar:SetValue(math.min(maximum, current))
                    row.bar:SetStatusBarColor(r, g, b, 0.82)
                    row.bar:Show()
                    row.rank:SetText(GetFactionStandingLabel(reaction))

                    local isSelected =
                        pane.selectedFactionID ~= nil
                        and pane.selectedFactionID == data.factionID
                    row.selected:SetShown(isSelected)

                    if isSelected then
                        selectedIndex = index
                    end

                    row:SetScript("OnClick", function(self)
                        pane.selectedFactionID = self.factionID
                        pane.selectedIndex = self.index

                        if C_Reputation.SetSelectedFaction then
                            SafeCall(
                                C_Reputation.SetSelectedFaction,
                                self.index
                            )
                        end

                        UpdateReputationPane(frame)
                    end)

                    y = y - 32
                end

                row:Show()
            else
                row:Hide()
            end
        end
    end

    pane.listContent:SetHeight(math.max(1, -y + 4))
    pane.UpdateScrollRange()

    if not selectedIndex then
        for index = 1, numFactions do
            local data = GetFactionData(index)

            if data and not data.isHeader then
                pane.selectedFactionID = data.factionID
                selectedIndex = index
                break
            end
        end
    end

    UpdateReputationDetails(frame, selectedIndex)
end

local function CreateReputationPane(frame)
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_HEIGHT)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    pane:Hide()
    pane.rows = {}
    frame.reputationPane = pane

    local listPanel = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", 0, 0)
    listPanel:SetWidth(SPLIT_WIDTH)
    listPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    listPanel:SetBackdropColor(0, 0, 0, 0.24)

    local list = CreateFrame("ScrollFrame", nil, listPanel)
    list:SetPoint("TOPLEFT", 1, -1)
    list:SetPoint("BOTTOMRIGHT", -1, 1)
    list:EnableMouseWheel(true)
    pane.list = list

    local content = CreateFrame("Frame", nil, list)
    content:SetWidth(LIST_CONTENT_WIDTH)
    content:SetHeight(1)
    list:SetScrollChild(content)
    pane.listContent = content

    local scrollbar = CreateFrame("Slider", nil, listPanel)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -3, -4)
    scrollbar:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -3, 4)
    scrollbar:SetWidth(6)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(20)
    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollbar:GetThumbTexture()

    if thumb then
        thumb:SetWidth(6)
        thumb:SetColorTexture(0.45, 0.45, 0.48, 0.65)
    end

    scrollbar:SetScript("OnValueChanged", function(_, value)
        list:SetVerticalScroll(value or 0)
    end)
    scrollbar:Hide()
    pane.scrollbar = scrollbar

    pane.UpdateScrollRange = function()
        local viewportHeight = list:GetHeight() or 0
        local contentHeight = content:GetHeight() or 0
        local maxScroll = math.max(0, contentHeight - viewportHeight)

        scrollbar:SetMinMaxValues(0, maxScroll)

        if maxScroll > 0 then
            local current = math.min(
                scrollbar:GetValue() or 0,
                maxScroll
            )
            scrollbar:SetValue(current)
            list:SetVerticalScroll(current)

            if thumb then
                local trackHeight = math.max(
                    1,
                    scrollbar:GetHeight() or 1
                )
                local thumbHeight = math.max(
                    20,
                    trackHeight
                        * viewportHeight
                        / math.max(contentHeight, 1)
                )
                thumb:SetHeight(
                    math.min(trackHeight, thumbHeight)
                )
            end

            scrollbar:Show()
        else
            scrollbar:SetValue(0)
            list:SetVerticalScroll(0)
            scrollbar:Hide()
        end
    end

    list:SetScript("OnMouseWheel", function(_, delta)
        local _, maxScroll = scrollbar:GetMinMaxValues()

        if not maxScroll or maxScroll <= 0 then
            return
        end

        scrollbar:SetValue(
            math.max(
                0,
                math.min(
                    maxScroll,
                    (scrollbar:GetValue() or 0) - delta * 32
                )
            )
        )
    end)

    list:SetScript("OnSizeChanged", function()
        pane.UpdateScrollRange()
    end)

    local detail = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    detail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    detail:SetBackdropColor(0, 0, 0, 0.30)
    pane.detail = detail

    local topDivider = pane:CreateTexture(nil, "OVERLAY")
    topDivider:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    topDivider:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
    topDivider:SetHeight(1)
    topDivider:SetColorTexture(unpack(colors.border))

    local splitDivider = pane:CreateTexture(nil, "OVERLAY")
    splitDivider:SetPoint(
        "TOPLEFT",
        pane,
        "TOPLEFT",
        SPLIT_WIDTH,
        0
    )
    splitDivider:SetPoint(
        "BOTTOMLEFT",
        pane,
        "BOTTOMLEFT",
        SPLIT_WIDTH,
        0
    )
    splitDivider:SetWidth(1)
    splitDivider:SetColorTexture(unpack(colors.border))

    local name = detail:CreateFontString(nil, "OVERLAY")
    name:SetPoint("TOPLEFT", 10, -12)
    name:SetPoint("TOPRIGHT", -10, -12)
    name:SetJustifyH("CENTER")
    name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    name:SetTextColor(0.94, 0.94, 0.96)
    pane.detailName = name

    local standing = detail:CreateFontString(nil, "OVERLAY")
    standing:SetPoint("TOP", name, "BOTTOM", 0, -2)
    standing:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    standing:SetTextColor(0.82, 0.72, 0.22)
    pane.detailStanding = standing

    local bar = CreateFrame("StatusBar", nil, detail)
    bar:SetPoint("TOPLEFT", 14, -58)
    bar:SetPoint("TOPRIGHT", -14, -58)
    bar:SetHeight(15)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    CreateBorder(bar, colors.border)
    pane.detailBar = bar

    local barBackground = bar:CreateTexture(nil, "BACKGROUND")
    barBackground:SetAllPoints()
    barBackground:SetColorTexture(0, 0, 0, 0.60)

    local value = bar:CreateFontString(nil, "OVERLAY")
    value:SetPoint("CENTER", 0, 0)
    value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    value:SetTextColor(0.95, 0.95, 0.97)
    pane.detailValue = value

    local description = detail:CreateFontString(nil, "OVERLAY")
    description:SetPoint("TOPLEFT", 12, -86)
    description:SetPoint("TOPRIGHT", -12, -86)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    description:SetTextColor(0.86, 0.86, 0.88)
    description:SetWordWrap(true)
    pane.detailDescription = description

    pane.atWarOption = CreateReputationOption(
        detail,
        "At War",
        -285
    )
    pane.inactiveOption = CreateReputationOption(
        detail,
        "Move to Inactive",
        -310
    )
    pane.watchedOption = CreateReputationOption(
        detail,
        "Show as Experience Bar",
        -335
    )

    pane.atWarOption:SetScript("OnClick", function()
        if pane.selectedIndex
            and C_Reputation
            and C_Reputation.ToggleFactionAtWar
        then
            SafeCall(
                C_Reputation.ToggleFactionAtWar,
                pane.selectedIndex
            )
            UpdateReputationPane(frame)
        end
    end)

    pane.inactiveOption:SetScript("OnClick", function()
        if not pane.selectedIndex
            or not C_Reputation
            or not C_Reputation.SetFactionActive
        then
            return
        end

        local isActive = true

        if C_Reputation.IsFactionActive then
            local active = SafeCall(
                C_Reputation.IsFactionActive,
                pane.selectedIndex
            )

            if type(active) == "boolean" then
                isActive = active
            end
        end

        SafeCall(
            C_Reputation.SetFactionActive,
            pane.selectedIndex,
            not isActive
        )
        UpdateReputationPane(frame)
    end)

    pane.watchedOption:SetScript("OnClick", function()
        if not pane.selectedIndex or not C_Reputation then
            return
        end

        if C_Reputation.SetWatchedFactionByIndex then
            SafeCall(
                C_Reputation.SetWatchedFactionByIndex,
                pane.selectedIndex
            )
        elseif pane.selectedFactionID
            and C_Reputation.SetWatchedFactionByID
        then
            SafeCall(
                C_Reputation.SetWatchedFactionByID,
                pane.selectedFactionID
            )
        end

        UpdateReputationPane(frame)
    end)

    SetReputationOptionState(pane.atWarOption, false, false)
    SetReputationOptionState(pane.inactiveOption, false, false)
    SetReputationOptionState(pane.watchedOption, false, false)
end


local function GetSkillLineData(index)
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
        local data = SafeCall(C_SkillInfo.GetSkillLineInfo, index)

        if type(data) == "table" then
            return data
        end
    end

    if not GetSkillLineInfo then
        return nil
    end

    local ok,
        name,
        isHeader,
        isExpanded,
        rank,
        tempPoints,
        modifier,
        maxRank,
        isAbandonable,
        stepCost,
        rankCost,
        minLevel,
        costType,
        description =
        pcall(GetSkillLineInfo, index)

    if not ok or not name then
        return nil
    end

    return {
        name = name,
        isHeader = isHeader and true or false,
        isCollapsed = isHeader and not isExpanded or false,
        rank = rank,
        tempPoints = tempPoints,
        modifier = modifier,
        maxRank = maxRank,
        isAbandonable = isAbandonable and true or false,
        stepCost = stepCost,
        rankCost = rankCost,
        minLevel = minLevel,
        costType = costType,
        description = description,
    }
end

local function ShouldShowSkillLineData(data)
    if not data then
        return false
    end

    if (tonumber(data.parentSkillLineID) or 0) ~= 0 then
        return false
    end

    if data.isHeader then
        return tonumber(data.skillID) ~= 7
    end

    return tonumber(data.skillLineCategoryID) ~= 7
end

local function GetNumSkillLinesValue()
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
        return tonumber(
            SafeCall(C_SkillInfo.GetNumSkillLines)
        ) or 0
    end

    if GetNumSkillLines then
        return tonumber(SafeCall(GetNumSkillLines)) or 0
    end

    return 0
end

local function SetSelectedSkillValue(index)
    if C_SkillInfo and C_SkillInfo.SetSelectedSkill then
        SafeCall(C_SkillInfo.SetSelectedSkill, index)
    elseif SetSelectedSkill then
        SafeCall(SetSelectedSkill, index)
    end
end

local function ExpandSkillHeaderValue(index)
    if C_SkillInfo and C_SkillInfo.ExpandSkillHeader then
        SafeCall(C_SkillInfo.ExpandSkillHeader, index)
    elseif ExpandSkillHeader then
        SafeCall(ExpandSkillHeader, index)
    end
end

local function CollapseSkillHeaderValue(index)
    if C_SkillInfo and C_SkillInfo.CollapseSkillHeader then
        SafeCall(C_SkillInfo.CollapseSkillHeader, index)
    elseif CollapseSkillHeader then
        SafeCall(CollapseSkillHeader, index)
    end
end

local function FormatSkillProgress(data)
    if not data then
        return ""
    end

    local rank = tonumber(data.rank) or 0
    local maximum = math.max(0, tonumber(data.maxRank) or 0)
    local bonus =
        (tonumber(data.tempPoints) or 0)
        + (tonumber(data.modifier) or 0)

    if bonus > 0 then
        return string.format(
            "%d |cff00ff00(+%d)|r / %d",
            rank,
            bonus,
            maximum
        )
    elseif bonus < 0 then
        return string.format(
            "%d |cffff4040(%d)|r / %d",
            rank,
            bonus,
            maximum
        )
    end

    return string.format("%d / %d", rank, maximum)
end

local function UpdateSkillsDetails(frame, index)
    local pane = frame.skillsPane

    if not pane then
        return
    end

    local data = index and GetSkillLineData(index)

    if not data or data.isHeader then
        pane.selectedIndex = nil
        pane.detailName:SetText("Select a skill")
        pane.detailDescription:SetText("")
        pane.detailBar:SetMinMaxValues(0, 1)
        pane.detailBar:SetValue(0)
        pane.detailValue:SetText("")
        return
    end

    pane.selectedIndex = index
    pane.selectedSkillID = data.skillID

    local rank = math.max(0, tonumber(data.rank) or 0)
    local maximum = math.max(1, tonumber(data.maxRank) or 1)

    pane.detailName:SetText(data.name or "Skill")
    pane.detailDescription:SetText(data.description or "")
    pane.detailBar:SetMinMaxValues(0, maximum)
    pane.detailBar:SetValue(math.min(maximum, rank))
    pane.detailBar:SetStatusBarColor(0.07, 0.37, 0.72, 0.90)
    pane.detailValue:SetText(FormatSkillProgress(data))
end

local function UpdateSkillsPane(frame)
    local pane = frame.skillsPane

    if not pane then
        return
    end

    local numSkills = GetNumSkillLinesValue()
    local y = -4
    local selectedIndex

    for index = 1, math.max(numSkills, #pane.rows) do
        local row = pane.rows[index]

        if not row and index <= numSkills then
            row = CreateFrame("Button", nil, pane.listContent)

            local background = row:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints()
            background:SetColorTexture(0, 0, 0, 0)
            row.background = background

            local name = row:CreateFontString(nil, "OVERLAY")
            name:SetJustifyH("LEFT")
            name:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            row.name = name

            local bar = CreateFrame("StatusBar", nil, row)
            bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            row.bar = bar

            local barBackground = bar:CreateTexture(nil, "BACKGROUND")
            barBackground:SetAllPoints()
            barBackground:SetColorTexture(0, 0, 0, 0.50)

            local value = bar:CreateFontString(nil, "OVERLAY")
            value:SetPoint("CENTER", 0, 0)
            value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            value:SetTextColor(0.94, 0.94, 0.96)
            row.value = value

            local selected = row:CreateTexture(nil, "BORDER")
            selected:SetAllPoints()
            selected:SetColorTexture(1, 1, 1, 0.09)
            selected:Hide()
            row.selected = selected

            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.06)

            pane.rows[index] = row
        end

        if row then
            local data = index <= numSkills
                and GetSkillLineData(index)

            if data and ShouldShowSkillLineData(data) then
                row.index = index
                row.skillID = data.skillID
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", pane.listContent, "TOPLEFT", 4, y)
                row:SetPoint("TOPRIGHT", pane.listContent, "TOPRIGHT", -4, y)

                if data.isHeader then
                    row:SetHeight(22)
                    row.background:SetColorTexture(1, 1, 1, 0.055)
                    row.name:ClearAllPoints()
                    row.name:SetPoint("LEFT", 6, 0)
                    row.name:SetPoint("RIGHT", -6, 0)
                    row.name:SetTextColor(0.88, 0.72, 0.16)
                    row.name:SetText(
                        string.format(
                            "%s %s",
                            data.isCollapsed and "+" or "-",
                            data.name or "Group"
                        )
                    )
                    row.bar:Hide()
                    row.selected:Hide()
                    row:SetScript("OnClick", function(self)
                        local headerData =
                            GetSkillLineData(self.index)

                        if not headerData then
                            return
                        end

                        if headerData.isCollapsed then
                            ExpandSkillHeaderValue(self.index)
                        else
                            CollapseSkillHeaderValue(self.index)
                        end

                        UpdateSkillsPane(frame)
                    end)

                    y = y - 24
                else
                    local rank = math.max(
                        0,
                        tonumber(data.rank) or 0
                    )
                    local maximum = math.max(
                        1,
                        tonumber(data.maxRank) or 1
                    )

                    row:SetHeight(30)
                    row.background:SetColorTexture(0, 0, 0, 0)
                    row.name:ClearAllPoints()
                    row.name:SetPoint("TOPLEFT", 8, -3)
                    row.name:SetPoint("TOPRIGHT", -8, -3)
                    row.name:SetTextColor(0.92, 0.92, 0.94)
                    row.name:SetText(data.name or "Skill")

                    row.bar:ClearAllPoints()
                    row.bar:SetPoint("BOTTOMLEFT", 8, 3)
                    row.bar:SetPoint("BOTTOMRIGHT", -8, 3)
                    row.bar:SetHeight(10)
                    row.bar:SetMinMaxValues(0, maximum)
                    row.bar:SetValue(math.min(maximum, rank))
                    row.bar:SetStatusBarColor(
                        0.07,
                        0.37,
                        0.72,
                        0.86
                    )
                    row.bar:Show()
                    row.value:SetText(FormatSkillProgress(data))

                    local isSelected =
                        pane.selectedSkillID ~= nil
                        and data.skillID ~= nil
                        and pane.selectedSkillID == data.skillID

                    if not pane.selectedSkillID then
                        isSelected =
                            pane.selectedIndex == index
                    end

                    row.selected:SetShown(isSelected)

                    if isSelected then
                        selectedIndex = index
                    end

                    row:SetScript("OnClick", function(self)
                        pane.selectedIndex = self.index
                        pane.selectedSkillID = self.skillID
                        SetSelectedSkillValue(self.index)
                        UpdateSkillsPane(frame)
                    end)

                    y = y - 32
                end

                row:Show()
            else
                row:Hide()
            end
        end
    end

    pane.listContent:SetHeight(math.max(1, -y + 4))
    pane.UpdateScrollRange()

    if not selectedIndex then
        local selectedFromAPI

        if C_SkillInfo and C_SkillInfo.GetSelectedSkill then
            selectedFromAPI = tonumber(
                SafeCall(C_SkillInfo.GetSelectedSkill)
            )
        elseif GetSelectedSkill then
            selectedFromAPI = tonumber(
                SafeCall(GetSelectedSkill)
            )
        end

        if selectedFromAPI
            and selectedFromAPI > 0
            and selectedFromAPI <= numSkills
        then
            local data = GetSkillLineData(selectedFromAPI)

            if data
                and not data.isHeader
                and ShouldShowSkillLineData(data)
            then
                pane.selectedIndex = selectedFromAPI
                pane.selectedSkillID = data.skillID
                selectedIndex = selectedFromAPI
            end
        end
    end

    if not selectedIndex then
        for index = 1, numSkills do
            local data = GetSkillLineData(index)

            if data
                and not data.isHeader
                and ShouldShowSkillLineData(data)
            then
                pane.selectedIndex = index
                pane.selectedSkillID = data.skillID
                selectedIndex = index
                break
            end
        end
    end

    UpdateSkillsDetails(frame, selectedIndex)
end

local function CreateSkillsPane(frame)
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_HEIGHT)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    pane:Hide()
    pane.rows = {}
    pane.elapsed = 0
    frame.skillsPane = pane

    local listPanel = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMLEFT", 0, 0)
    listPanel:SetWidth(SPLIT_WIDTH)
    listPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    listPanel:SetBackdropColor(0, 0, 0, 0.24)

    local list = CreateFrame("ScrollFrame", nil, listPanel)
    list:SetPoint("TOPLEFT", 1, -1)
    list:SetPoint("BOTTOMRIGHT", -1, 1)
    list:EnableMouseWheel(true)
    pane.list = list

    local content = CreateFrame("Frame", nil, list)
    content:SetWidth(LIST_CONTENT_WIDTH)
    content:SetHeight(1)
    list:SetScrollChild(content)
    pane.listContent = content

    local scrollbar = CreateFrame("Slider", nil, listPanel)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -3, -4)
    scrollbar:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -3, 4)
    scrollbar:SetWidth(6)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(20)
    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollbar:GetThumbTexture()

    if thumb then
        thumb:SetWidth(6)
        thumb:SetColorTexture(0.45, 0.45, 0.48, 0.65)
    end

    scrollbar:SetScript("OnValueChanged", function(_, value)
        list:SetVerticalScroll(value or 0)
    end)
    scrollbar:Hide()
    pane.scrollbar = scrollbar

    pane.UpdateScrollRange = function()
        local viewportHeight = list:GetHeight() or 0
        local contentHeight = content:GetHeight() or 0
        local maxScroll = math.max(
            0,
            contentHeight - viewportHeight
        )

        scrollbar:SetMinMaxValues(0, maxScroll)

        if maxScroll > 0 then
            local current = math.min(
                scrollbar:GetValue() or 0,
                maxScroll
            )
            scrollbar:SetValue(current)
            list:SetVerticalScroll(current)

            if thumb then
                local trackHeight = math.max(
                    1,
                    scrollbar:GetHeight() or 1
                )
                local thumbHeight = math.max(
                    20,
                    trackHeight
                        * viewportHeight
                        / math.max(contentHeight, 1)
                )
                thumb:SetHeight(
                    math.min(trackHeight, thumbHeight)
                )
            end

            scrollbar:Show()
        else
            scrollbar:SetValue(0)
            list:SetVerticalScroll(0)
            scrollbar:Hide()
        end
    end

    list:SetScript("OnMouseWheel", function(_, delta)
        local _, maxScroll = scrollbar:GetMinMaxValues()

        if not maxScroll or maxScroll <= 0 then
            return
        end

        scrollbar:SetValue(
            math.max(
                0,
                math.min(
                    maxScroll,
                    (scrollbar:GetValue() or 0) - delta * 32
                )
            )
        )
    end)

    list:SetScript("OnSizeChanged", function()
        pane.UpdateScrollRange()
    end)

    local detail = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    detail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    detail:SetBackdropColor(0, 0, 0, 0.30)
    pane.detail = detail

    local topDivider = pane:CreateTexture(nil, "OVERLAY")
    topDivider:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    topDivider:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, 0)
    topDivider:SetHeight(1)
    topDivider:SetColorTexture(unpack(colors.border))

    local splitDivider = pane:CreateTexture(nil, "OVERLAY")
    splitDivider:SetPoint(
        "TOPLEFT",
        pane,
        "TOPLEFT",
        SPLIT_WIDTH,
        0
    )
    splitDivider:SetPoint(
        "BOTTOMLEFT",
        pane,
        "BOTTOMLEFT",
        SPLIT_WIDTH,
        0
    )
    splitDivider:SetWidth(1)
    splitDivider:SetColorTexture(unpack(colors.border))

    local name = detail:CreateFontString(nil, "OVERLAY")
    name:SetPoint("TOPLEFT", 10, -14)
    name:SetPoint("TOPRIGHT", -10, -14)
    name:SetJustifyH("CENTER")
    name:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    name:SetTextColor(0.94, 0.94, 0.96)
    pane.detailName = name

    local bar = CreateFrame("StatusBar", nil, detail)
    bar:SetPoint("TOPLEFT", 14, -58)
    bar:SetPoint("TOPRIGHT", -14, -58)
    bar:SetHeight(15)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    CreateBorder(bar, colors.border)
    pane.detailBar = bar

    local barBackground = bar:CreateTexture(nil, "BACKGROUND")
    barBackground:SetAllPoints()
    barBackground:SetColorTexture(0, 0, 0, 0.60)

    local value = bar:CreateFontString(nil, "OVERLAY")
    value:SetPoint("CENTER", 0, 0)
    value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    value:SetTextColor(0.95, 0.95, 0.97)
    pane.detailValue = value

    local description = detail:CreateFontString(nil, "OVERLAY")
    description:SetPoint("TOPLEFT", 12, -86)
    description:SetPoint("TOPRIGHT", -12, -86)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    description:SetTextColor(0.86, 0.86, 0.88)
    description:SetWordWrap(true)
    pane.detailDescription = description

    pane:SetScript("OnShow", function()
        pane.elapsed = 0
        UpdateSkillsPane(frame)
    end)

    pane:SetScript("OnUpdate", function(_, elapsed)
        pane.elapsed = (pane.elapsed or 0) + elapsed

        if pane.elapsed < 0.5 then
            return
        end

        pane.elapsed = 0
        UpdateSkillsPane(frame)
    end)
end

local function SetOuterTabBackground(tab, r, g, b, a)
    for _, texture in ipairs(tab.backgrounds or {}) do
        texture:SetColorTexture(r, g, b, a)
    end
end

local function CreateOuterTabVisual(tab)
    local chamfer = 4
    local backgrounds = {}

    local upper = tab:CreateTexture(nil, "BACKGROUND")
    upper:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    upper:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    upper:SetPoint("BOTTOM", tab, "BOTTOM", 0, chamfer)
    backgrounds[#backgrounds + 1] = upper

    for row = 0, chamfer - 1 do
        local inset = chamfer - row
        local strip = tab:CreateTexture(nil, "BACKGROUND")
        strip:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", inset, row)
        strip:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -inset, row)
        strip:SetHeight(1)
        backgrounds[#backgrounds + 1] = strip
    end

    tab.backgrounds = backgrounds

    local borders = {}

    local top = tab:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    top:SetColorTexture(unpack(colors.border))
    borders[1] = top

    local bottom = tab:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", chamfer, 0)
    bottom:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -chamfer, 0)
    bottom:SetHeight(1)
    bottom:SetColorTexture(unpack(colors.border))
    borders[2] = bottom

    local left = tab:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, chamfer)
    left:SetWidth(1)
    left:SetColorTexture(unpack(colors.border))
    borders[3] = left

    local right = tab:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, chamfer)
    right:SetWidth(1)
    right:SetColorTexture(unpack(colors.border))
    borders[4] = right

    for step = 1, chamfer do
        local leftChamfer = tab:CreateTexture(nil, "OVERLAY")
        leftChamfer:SetPoint(
            "BOTTOMLEFT",
            tab,
            "BOTTOMLEFT",
            step - 1,
            chamfer - step
        )
        leftChamfer:SetSize(1, 1)
        leftChamfer:SetColorTexture(unpack(colors.border))

        local rightChamfer = tab:CreateTexture(nil, "OVERLAY")
        rightChamfer:SetPoint(
            "BOTTOMRIGHT",
            tab,
            "BOTTOMRIGHT",
            -(step - 1),
            chamfer - step
        )
        rightChamfer:SetSize(1, 1)
        rightChamfer:SetColorTexture(unpack(colors.border))
    end

    tab.borders = borders
end

SetOuterPage = function(frame, page)
    if page ~= "reputation" and page ~= "skills" then
        page = "character"
    end

    frame.page = page

    if frame.characterPane then
        frame.characterPane:SetShown(page == "character")
    end

    if frame.sidebar then
        frame.sidebar:SetShown(page == "character")
    end

    if frame.reputationPane then
        frame.reputationPane:SetShown(page == "reputation")
    end

    if frame.skillsPane then
        frame.skillsPane:SetShown(page == "skills")
    end

    if page == "character" then
        UpdatePlayerInfo(frame)
        frame.details:Show()
        frame.titleButton:Show()
        frame.titleArrow:Show()
    elseif page == "reputation" then
        frame.name:SetText("Reputation")
        frame.name:SetTextColor(0.88, 0.72, 0.16)
        frame.details:Hide()
        frame.titleButton:Hide()
        frame.titleArrow:Hide()
        UpdateReputationPane(frame)
    else
        frame.name:SetText("Skills")
        frame.name:SetTextColor(0.88, 0.72, 0.16)
        frame.details:Hide()
        frame.titleButton:Hide()
        frame.titleArrow:Hide()
        UpdateSkillsPane(frame)
    end

    for _, tab in ipairs(frame.tabs or {}) do
        local active = tab.page == page

        if tab.enabled then
            tab:SetAlpha(1)
            SetOuterTabBackground(
                tab,
                active and 0.04 or 0.00,
                active and 0.04 or 0.00,
                active and 0.05 or 0.00,
                active and 0.55 or 0.40
            )

            if tab.borders and tab.borders[1] then
                tab.borders[1]:SetShown(not active)
            end
        else
            tab:SetAlpha(0.45)
        end
    end
end

local function LayoutOuterTabs(frame)
    local tabWidth = 80

    for index, tab in ipairs(frame.tabs or {}) do
        tab:ClearAllPoints()
        tab:SetPoint(
            "TOPLEFT",
            frame,
            "BOTTOMLEFT",
            20 + (index - 1) * tabWidth,
            1
        )
    end
end

local function CreateSidebar(frame)
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        -1,
        -HEADER_HEIGHT
    )
    sidebar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sidebar:SetBackdropColor(0, 0, 0, 0.40)
    sidebar:SetBackdropBorderColor(unpack(colors.border))
    frame.sidebar = sidebar

    local statsTab = CreateFrame("Button", nil, sidebar)
    statsTab:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 1, -1)
    statsTab:SetPoint("TOPRIGHT", sidebar, "TOP", 0, -1)
    statsTab:SetHeight(24)
    statsTab:SetNormalFontObject("GameFontNormalSmall")
    statsTab:SetHighlightFontObject("GameFontHighlightSmall")
    statsTab:SetText("Stats")
    statsTab.background = statsTab:CreateTexture(nil, "BACKGROUND")
    statsTab.background:SetAllPoints()
    statsTab.background:SetColorTexture(1, 1, 1, 0.18)
    local statsBorders = CreateBorder(statsTab, colors.border)
    statsBorders[1]:Hide()
    statsBorders[3]:Hide()
    statsBorders[4]:Hide()

    local statsHighlight = statsTab:CreateTexture(nil, "HIGHLIGHT")
    statsHighlight:SetAllPoints()
    statsHighlight:SetColorTexture(1, 1, 1, 0.08)

    statsTab:SetScript("OnClick", function()
        SetSidebarMode(frame, "stats")
    end)
    sidebar.statsTab = statsTab

    local equipmentTab = CreateFrame("Button", nil, sidebar)
    equipmentTab:SetPoint("TOPLEFT", sidebar, "TOP", 0, -1)
    equipmentTab:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -1, -1)
    equipmentTab:SetHeight(24)
    equipmentTab:SetNormalFontObject("GameFontNormalSmall")
    equipmentTab:SetHighlightFontObject("GameFontHighlightSmall")
    equipmentTab:SetText("Equipment")
    equipmentTab.background = equipmentTab:CreateTexture(nil, "BACKGROUND")
    equipmentTab.background:SetAllPoints()
    equipmentTab.background:SetColorTexture(1, 1, 1, 0.07)
    local equipmentBorders = CreateBorder(equipmentTab, colors.border)
    equipmentBorders[1]:Hide()
    equipmentBorders[3]:Hide()
    equipmentBorders[4]:Hide()

    local tabDivider = equipmentTab:CreateTexture(nil, "OVERLAY")
    tabDivider:SetPoint("TOPLEFT")
    tabDivider:SetPoint("BOTTOMLEFT")
    tabDivider:SetWidth(1)
    tabDivider:SetColorTexture(unpack(colors.border))

    local equipmentHighlight = equipmentTab:CreateTexture(nil, "HIGHLIGHT")
    equipmentHighlight:SetAllPoints()
    equipmentHighlight:SetColorTexture(1, 1, 1, 0.08)

    equipmentTab:SetScript("OnClick", function()
        SetSidebarMode(frame, "equipment")
    end)
    sidebar.equipmentTab = equipmentTab

    local statsPane = CreateFrame("ScrollFrame", nil, sidebar)
    statsPane:SetPoint("TOPLEFT", 1, -25)
    statsPane:SetPoint("BOTTOMRIGHT", -1, 1)
    statsPane:EnableMouseWheel(true)
    statsPane.rows = {}
    sidebar.statsPane = statsPane

    local statsContent = CreateFrame("Frame", nil, statsPane)
    statsContent:SetWidth(SIDEBAR_WIDTH - 12)
    statsContent:SetHeight(1)
    statsPane:SetScrollChild(statsContent)
    statsPane.content = statsContent

    local statsScrollbar = CreateFrame("Slider", nil, statsPane)
    statsScrollbar:SetOrientation("VERTICAL")
    statsScrollbar:SetPoint("TOPRIGHT", statsPane, "TOPRIGHT", -3, -3)
    statsScrollbar:SetPoint("BOTTOMRIGHT", statsPane, "BOTTOMRIGHT", -3, 3)
    statsScrollbar:SetWidth(6)
    statsScrollbar:SetMinMaxValues(0, 0)
    statsScrollbar:SetValueStep(10)

    if statsScrollbar.SetObeyStepOnDrag then
        statsScrollbar:SetObeyStepOnDrag(false)
    end

    local scrollTrack = statsScrollbar:CreateTexture(nil, "BACKGROUND")
    scrollTrack:SetAllPoints()
    scrollTrack:SetColorTexture(1, 1, 1, 0.05)

    statsScrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local scrollThumb = statsScrollbar:GetThumbTexture()

    if scrollThumb then
        scrollThumb:SetWidth(6)
        scrollThumb:SetColorTexture(0.45, 0.45, 0.48, 0.65)
    end

    statsScrollbar:SetScript("OnValueChanged", function(_, value)
        statsPane:SetVerticalScroll(value or 0)
    end)
    statsScrollbar:Hide()
    statsPane.scrollbar = statsScrollbar

    local function UpdateStatsScrollRange()
        local viewportHeight = statsPane:GetHeight() or 0
        local contentHeight = statsContent:GetHeight() or 0
        local maxScroll = math.max(0, contentHeight - viewportHeight)

        statsScrollbar:SetMinMaxValues(0, maxScroll)

        if maxScroll > 0 then
            local current = math.min(statsScrollbar:GetValue() or 0, maxScroll)
            statsScrollbar:SetValue(current)
            statsPane:SetVerticalScroll(current)

            if scrollThumb then
                local trackHeight = math.max(1, statsScrollbar:GetHeight() or 1)
                local thumbHeight = math.max(
                    20,
                    trackHeight * viewportHeight / math.max(contentHeight, 1)
                )
                scrollThumb:SetHeight(math.min(trackHeight, thumbHeight))
            end

            statsScrollbar:Show()
        else
            statsScrollbar:SetValue(0)
            statsPane:SetVerticalScroll(0)
            statsScrollbar:Hide()
        end
    end

    statsPane:SetScript("OnMouseWheel", function(_, delta)
        local _, maxScroll = statsScrollbar:GetMinMaxValues()

        if not maxScroll or maxScroll <= 0 then
            return
        end

        statsScrollbar:SetValue(
            math.max(
                0,
                math.min(
                    maxScroll,
                    (statsScrollbar:GetValue() or 0) - delta * 28
                )
            )
        )
    end)

    statsPane:SetScript("OnSizeChanged", function()
        UpdateStatsScrollRange()
    end)

    local statLayout = {
        { header = "General" },
        { key = "health", label = "Health" },
        { key = "power", label = "Power" },
        { key = "moveSpeed", label = "Movement Speed" },

        { header = "Primary Attributes" },
        { key = "strength", label = "Strength" },
        { key = "agility", label = "Agility" },
        { key = "stamina", label = "Stamina" },
        { key = "intellect", label = "Intellect" },
        { key = "spirit", label = "Spirit" },

        { header = "Weapons" },
        { key = "attackPower", label = "Attack Power" },
        { key = "crit", label = "Crit" },
        { key = "hit", label = "Hit" },

        { header = "Defense" },
        { key = "armor", label = "Armor" },
        { key = "dodge", label = "Dodge" },
        { key = "parry", label = "Parry" },
        { key = "block", label = "Block" },

        { header = "Resistances" },
        { key = "fire", label = "Fire" },
        { key = "nature", label = "Nature" },
        { key = "frost", label = "Frost" },
        { key = "shadow", label = "Shadow" },
        { key = "arcane", label = "Arcane" },
    }

    local LayoutStatsContent
    local currentSection

    for _, data in ipairs(statLayout) do
        if data.header then
            currentSection = data.header

            local header = CreateSidebarHeader(
                statsContent,
                -4,
                data.header
            )
            header.section = data.header
            header.collapsed = false
            data.frame = header

            header:SetScript("OnClick", function(self)
                self.collapsed = not self.collapsed
                LayoutStatsContent()
            end)
        else
            local row = CreateSidebarRow(statsContent, -4)
            row:SetHeight(13)
            row.label:SetText(data.label)
            row.value:SetText("-")
            row.section = currentSection
            data.frame = row
            statsPane.rows[data.key] = row
        end
    end

    LayoutStatsContent = function()
        local y = -4
        local collapsed = false

        for _, data in ipairs(statLayout) do
            local widget = data.frame

            if data.header then
                collapsed = widget.collapsed == true
                widget:ClearAllPoints()
                widget:SetPoint(
                    "TOPLEFT",
                    statsContent,
                    "TOPLEFT",
                    6,
                    y
                )
                widget:SetPoint(
                    "TOPRIGHT",
                    statsContent,
                    "TOPRIGHT",
                    -6,
                    y
                )
                widget.label:SetText(
                    string.format(
                        "%s %s",
                        collapsed and "+" or "-",
                        data.header
                    )
                )
                widget:Show()
                y = y - 18
            elseif collapsed then
                widget:Hide()
            else
                widget:ClearAllPoints()
                widget:SetPoint(
                    "TOPLEFT",
                    statsContent,
                    "TOPLEFT",
                    8,
                    y
                )
                widget:SetPoint(
                    "TOPRIGHT",
                    statsContent,
                    "TOPRIGHT",
                    -8,
                    y
                )
                widget:Show()
                y = y - 14
            end
        end

        statsContent:SetHeight(math.max(1, -y + 4))
        UpdateStatsScrollRange()
    end

    LayoutStatsContent()

    local equipmentPane = CreateFrame("Frame", nil, sidebar)
    equipmentPane:SetPoint("TOPLEFT", 1, -25)
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
    equip:SetSize(66, 20)
    equip:SetPoint("BOTTOMRIGHT", equipmentPane, "BOTTOM", -3, 8)
    equip:SetNormalFontObject("GameFontNormalSmall")
    equip:SetHighlightFontObject("GameFontHighlightSmall")
    equip:SetText("Equip")

    local equipBackground = equip:CreateTexture(nil, "BACKGROUND")
    equipBackground:SetAllPoints()
    equipBackground:SetColorTexture(1, 1, 1, 0.12)
    CreateBorder(equip, colors.border)

    local equipHighlight = equip:CreateTexture(nil, "HIGHLIGHT")
    equipHighlight:SetAllPoints()
    equipHighlight:SetColorTexture(1, 1, 1, 0.10)

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
    save:SetSize(66, 20)
    save:SetPoint("BOTTOMLEFT", equipmentPane, "BOTTOM", 3, 8)
    save:SetNormalFontObject("GameFontNormalSmall")
    save:SetHighlightFontObject("GameFontHighlightSmall")
    save:SetText("Save")

    local saveBackground = save:CreateTexture(nil, "BACKGROUND")
    saveBackground:SetAllPoints()
    saveBackground:SetColorTexture(1, 1, 1, 0.12)
    CreateBorder(save, colors.border)

    local saveHighlight = save:CreateTexture(nil, "HIGHLIGHT")
    saveHighlight:SetAllPoints()
    saveHighlight:SetColorTexture(1, 1, 1, 0.10)

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

    local characterPane = CreateFrame("Frame", nil, frame)
    characterPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    characterPane:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    characterPane:SetWidth(CHARACTER_WIDTH - 1)
    frame.characterPane = characterPane

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT - 1)
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
    name:SetPoint("TOP", header, "TOP", 0, -5)
    name:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.name = name

    local details = header:CreateFontString(nil, "OVERLAY")
    details:SetPoint("TOP", name, "BOTTOM", 0, -1)
    details:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    details:SetTextColor(0.72, 0.72, 0.75)
    frame.details = details

    local titleButton = CreateFrame("Button", nil, header)
    titleButton:SetPoint("TOPLEFT", header, "TOPLEFT", 70, -1)
    titleButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -70, -1)
    titleButton:SetHeight(20)
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
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -3, -3)
    close:SetNormalFontObject("GameFontNormal")
    close:SetHighlightFontObject("GameFontHighlight")
    close:SetText("x")
    close:SetScript("OnClick", function()
        Module:Hide()
    end)

    local modelPanel = CreateFrame("Frame", nil, characterPane, "BackdropTemplate")
    modelPanel:SetPoint("TOP", characterPane, "TOP", 0, -54)
    modelPanel:SetPoint("BOTTOM", characterPane, "BOTTOM", 0, 58)
    modelPanel:SetWidth(230)
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
        local button = CreateEquipmentSlot(characterPane, definition)
        LayoutEquipmentSlot(button, definition, frame)
        frame.equipmentSlots[#frame.equipmentSlots + 1] = button
        frame.equipmentByKey[definition.key] = button
    end

    local tabs = {
        { label = "Character", page = "character", enabled = true },
        { label = "Reputation", page = "reputation", enabled = true },
        { label = "Skills", page = "skills", enabled = true },
    }

    frame.tabs = {}

    for index, definition in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(80, 22)
        tab:SetFrameLevel(frame:GetFrameLevel() + 2)
        tab:SetNormalFontObject("GameFontNormalSmall")
        tab:SetHighlightFontObject("GameFontHighlightSmall")
        tab:SetText(definition.label)

        CreateOuterTabVisual(tab)
        SetOuterTabBackground(
            tab,
            0.00,
            0.00,
            0.00,
            definition.enabled and 0.40 or 0.25
        )

        if index > 1 and tab.borders and tab.borders[3] then
            tab.borders[3]:Hide()
        end

        tab.page = definition.page
        tab.enabled = definition.enabled == true

        if definition.enabled then
            tab:SetScript("OnClick", function(self)
                SetOuterPage(frame, self.page)
            end)
        else
            tab:SetAlpha(0.45)
            tab:Disable()
        end

        frame.tabs[#frame.tabs + 1] = tab
    end

    CreateSidebar(frame)
    CreateReputationPane(frame)
    CreateSkillsPane(frame)
    SetOuterPage(frame, "character")
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

    UI:RegisterEvent("UPDATE_FACTION", function()
        if Module.frame
            and Module.frame.page == "reputation"
        then
            UpdateReputationPane(Module.frame)
        end
    end)

    UI:RegisterEvent("SKILL_LINES_CHANGED", function()
        if Module.frame
            and Module.frame.page == "skills"
        then
            UpdateSkillsPane(Module.frame)
        end
    end)

    for _, event in ipairs({
        "UNIT_STATS",
        "UNIT_MAXHEALTH",
        "UNIT_POWER_UPDATE",
        "UNIT_RESISTANCES",
        "UNIT_AURA",
        "UPDATE_SHAPESHIFT_FORM",
        "COMBAT_RATING_UPDATE",
        "PLAYER_DAMAGE_DONE_MODS",
    }) do
        UI:RegisterEvent(event, function(_, unit)
            if not unit or unit == "player" then
                Module:Refresh()
            end
        end)
    end
end

Module:Initialize()
