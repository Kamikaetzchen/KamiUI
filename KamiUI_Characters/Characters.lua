local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Characters", "KamiUI_Characters")

Module.version = "0.2.0"

local LEFT_PANE_WIDTH = 323
local RIGHT_PANE_WIDTH = 210
local FRAME_WIDTH = LEFT_PANE_WIDTH + RIGHT_PANE_WIDTH

local CHARACTER_WIDTH = LEFT_PANE_WIDTH
local SIDEBAR_WIDTH = RIGHT_PANE_WIDTH
local SPLIT_WIDTH = LEFT_PANE_WIDTH - 2
local LIST_CONTENT_WIDTH = SPLIT_WIDTH - 14
local FRAME_HEIGHT = 420
local HEADER_HEIGHT = 40
local SLOT_SIZE = 36
local SLOT_GAP = 3

local CHARACTER_DATABASE_DEFAULTS = {
    data = {},
}

local function GetDatabase()
    return UI:GetDatabase("characters", CHARACTER_DATABASE_DEFAULTS)
end

local function ImportLegacyBagCharacters()
    local bagCharacters = KamiUIDB
        and KamiUIDB.bags
        and KamiUIDB.bags.characters

    if type(bagCharacters) ~= "table" then
        return
    end

    local characters = GetDatabase().data

    for key, legacy in pairs(bagCharacters) do
        if type(legacy) == "table" then
            local character = characters[key] or {}

            if character.name == nil then
                character.name = legacy.name
            end

            if character.firstName == nil then
                character.firstName = legacy.firstName
            end

            if character.surname == nil then
                character.surname = legacy.surname
            end

            if character.classFile == nil then
                character.classFile = legacy.classFile
            end

            if character.realm == nil then
                character.realm = legacy.realm
            end

            if character.money == nil then
                character.money = legacy.money
            end

            if character.updated == nil then
                character.updated = legacy.updated
            end

            if character.name then
                characters[key] = character
            end
        end
    end
end

local function UpdateCurrentCharacter()
    local db = GetDatabase()
    local key = UI:GetCurrentCharacterKey()
    local firstName, surname, fullName = UI:GetCurrentCharacterNames()
    local className, classFile = UnitClass("player")
    local character = db.data[key] or {}

    character.name = fullName
    character.firstName = firstName
    character.surname = surname
    character.className = className
    character.classFile = classFile
    character.level = UnitLevel and UnitLevel("player") or character.level or 0
    character.realm = GetRealmName and GetRealmName() or ""
    character.money = GetMoney and GetMoney() or character.money or 0
    character.updated = time and time() or 0

    db.data[key] = character

    return key, character
end

function Module:GetCurrentCharacterKey()
    return UI:GetCurrentCharacterKey()
end

function Module:GetCurrentCharacter()
    local key = UI:GetCurrentCharacterKey()

    return key, GetDatabase().data[key]
end

function Module:GetCharacter(key)
    return key and GetDatabase().data[key] or nil
end

function Module:GetCharacters()
    return GetDatabase().data
end

function Module:GetSortedCharacters()
    local characters = {}

    for key, character in pairs(GetDatabase().data) do
        characters[#characters + 1] = {
            key = key,
            character = character,
        }
    end

    return UI:SortCharacterEntries(characters)
end

function Module:UpdateCurrentCharacter()
    return UpdateCurrentCharacter()
end

function Module:GetViewedCharacter()
    local currentKey = UI:GetCurrentCharacterKey()
    local key = self.viewCharacterKey or currentKey

    return key, GetDatabase().data[key], key == currentKey
end

function Module:SetViewedCharacter(key)
    local currentKey = UI:GetCurrentCharacterKey()

    self.viewCharacterKey = key == currentKey and nil or key

    if self.frame then
        self.frame.page = "character"

        if self.frame.characterMenu then
            self.frame.characterMenu:Hide()
        end

        self:Refresh()
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

local function GetFullPlayerName()
    local _, _, fullName = UI:GetCurrentCharacterNames()

    return fullName
end

local function GetSlotID(slotKey)
    if not GetInventorySlotInfo then
        return nil
    end

    return GetInventorySlotInfo(slotKey)
end

local function SaveCurrentEquipmentSnapshot()
    local _, character = UpdateCurrentCharacter()

    if not character then
        return
    end

    character.equipment = character.equipment or {}

    for _, definition in ipairs(SLOT_LAYOUT) do
        local slotID = GetSlotID(definition.key)
        local texture = slotID
            and GetInventoryItemTexture
            and GetInventoryItemTexture("player", slotID)
        local link = slotID
            and GetInventoryItemLink
            and GetInventoryItemLink("player", slotID)
        local quality = slotID
            and GetInventoryItemQuality
            and GetInventoryItemQuality("player", slotID)

        if texture or link then
            character.equipment[definition.key] = {
                icon = texture,
                link = link,
                quality = quality,
            }
        else
            character.equipment[definition.key] = nil
        end
    end
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

local UpdateEquipmentIgnoreOverlays
local LoadEquipmentIgnoreState
local ApplyEquipmentIgnoreState

local function CreateEquipmentSlot(parent, definition)
    local slotSize = definition.size or SLOT_SIZE
    local button = Components:CreateItemSlot(parent, {
        size = slotSize,
        borderColor = Palette.emptyBorder,
        label = definition.label,
        labelFontSize = 8,
        labelColor = { 0.45, 0.45, 0.48, 1 },
        highlight = false,
    })

    button:RegisterForClicks(
        "LeftButtonUp",
        "RightButtonUp",
        "MiddleButtonUp"
    )
    button:RegisterForDrag("LeftButton")

    local ignoreOverlay = button:CreateTexture(nil, "OVERLAY", nil, 3)
    ignoreOverlay:SetPoint("CENTER")
    ignoreOverlay:SetSize(
        math.max(16, math.floor(slotSize * 0.62)),
        math.max(16, math.floor(slotSize * 0.62))
    )
    ignoreOverlay:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    ignoreOverlay:SetAlpha(0.95)
    ignoreOverlay:Hide()
    button.KamiIgnoreOverlay = ignoreOverlay

    button.slotKey = definition.key
    button.slotID = GetSlotID(definition.key)

    button:SetScript("OnEnter", function(self)
        if not self.slotID then
            return
        end

        local _, _, isCurrent = Module:GetViewedCharacter()

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        if isCurrent then
            if GameTooltip:SetInventoryItem("player", self.slotID) then
                GameTooltip:Show()
            else
                GameTooltip:SetText(self.slotKey)
                GameTooltip:Show()
            end
        elseif self.cachedLink then
            GameTooltip:SetHyperlink(self.cachedLink)
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
        local _, _, isCurrent = Module:GetViewedCharacter()

        if not isCurrent or not self.slotID then
            return
        end

        if mouseButton == "LeftButton" then
            PickupInventoryItem(self.slotID)
        elseif mouseButton == "RightButton" then
            UseInventoryItem(self.slotID)
        elseif mouseButton == "MiddleButton" then
            local frame = self:GetParent()
                and self:GetParent():GetParent()

            if not frame
                or not frame.sidebar
                or frame.sidebar.mode ~= "equipment"
                or not C_EquipmentSet
                or not C_EquipmentSet.IsSlotIgnoredForSave
            then
                return
            end

            local ignored = self.KamiIgnoreForSave

            if ignored == nil then
                ignored = UI:SafeCall(
                    C_EquipmentSet.IsSlotIgnoredForSave,
                    self.slotID
                ) == true
            end

            self.KamiIgnoreForSave = not ignored

            if frame.sidebar and frame.sidebar.equipmentPane then
                frame.sidebar.equipmentPane.ignoreDirty = true
            end

            if self.KamiIgnoreForSave then
                if C_EquipmentSet.IgnoreSlotForSave then
                    UI:SafeCall(
                        C_EquipmentSet.IgnoreSlotForSave,
                        self.slotID
                    )
                end
            elseif C_EquipmentSet.UnignoreSlotForSave then
                UI:SafeCall(
                    C_EquipmentSet.UnignoreSlotForSave,
                    self.slotID
                )
            end

            if UpdateEquipmentIgnoreOverlays then
                UpdateEquipmentIgnoreOverlays(frame)
            end
        end
    end)

    button:SetScript("OnDragStart", function(self)
        local _, _, isCurrent = Module:GetViewedCharacter()

        if isCurrent and self.slotID then
            PickupInventoryItem(self.slotID)
        end
    end)

    button:SetScript("OnReceiveDrag", function(self)
        local _, _, isCurrent = Module:GetViewedCharacter()

        if isCurrent and self.slotID then
            PickupInventoryItem(self.slotID)
        end
    end)

    return button
end

ApplyEquipmentIgnoreState = function(frame)
    if not frame or not C_EquipmentSet then
        return
    end

    if C_EquipmentSet.ClearIgnoredSlotsForSave then
        UI:SafeCall(C_EquipmentSet.ClearIgnoredSlotsForSave)
    end

    for _, button in ipairs(frame.equipmentSlots or {}) do
        if button.slotID then
            if button.KamiIgnoreForSave then
                if C_EquipmentSet.IgnoreSlotForSave then
                    UI:SafeCall(
                        C_EquipmentSet.IgnoreSlotForSave,
                        button.slotID
                    )
                end
            elseif C_EquipmentSet.UnignoreSlotForSave then
                UI:SafeCall(
                    C_EquipmentSet.UnignoreSlotForSave,
                    button.slotID
                )
            end
        end
    end
end

LoadEquipmentIgnoreState = function(frame, setID)
    if not frame then
        return
    end

    local ignoredSlots = {}

    if setID
        and C_EquipmentSet
        and C_EquipmentSet.GetIgnoredSlots
    then
        local saved = UI:SafeCall(C_EquipmentSet.GetIgnoredSlots, setID)

        if type(saved) == "table" then
            ignoredSlots = saved
        end
    end

    for _, button in ipairs(frame.equipmentSlots or {}) do
        button.KamiIgnoreForSave =
            button.slotID and ignoredSlots[button.slotID] == true or false
    end

    if frame.sidebar and frame.sidebar.equipmentPane then
        frame.sidebar.equipmentPane.loadedIgnoreSetID = setID
        frame.sidebar.equipmentPane.ignoreDirty = false
    end

    ApplyEquipmentIgnoreState(frame)
    UpdateEquipmentIgnoreOverlays(frame)
end

UpdateEquipmentIgnoreOverlays = function(frame)
    if not frame then
        return
    end

    local _, _, isCurrent = Module:GetViewedCharacter()
    local show = isCurrent
        and frame.sidebar
        and frame.sidebar.mode == "equipment"
        and C_EquipmentSet
        and C_EquipmentSet.IsSlotIgnoredForSave

    for _, button in ipairs(frame.equipmentSlots or {}) do
        local ignored = false

        if show and button.slotID then
            if button.KamiIgnoreForSave ~= nil then
                ignored = button.KamiIgnoreForSave == true
            else
                ignored = UI:SafeCall(
                    C_EquipmentSet.IsSlotIgnoredForSave,
                    button.slotID
                ) == true
            end
        end

        if button.KamiIgnoreOverlay then
            button.KamiIgnoreOverlay:SetShown(ignored)
        end
    end
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
            6,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    elseif definition.side == "RIGHT" then
        button:SetPoint(
            "TOPRIGHT",
            pane,
            "TOPRIGHT",
            -6,
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

local function UpdateEquipmentSlot(button)
    local slotID = button.slotID

    if not slotID then
        button.cachedLink = nil
        button.icon:SetTexture(nil)
        button.label:Show()
        Components:SetItemSlotBorderColor(button, Palette.emptyBorder)
        Components:SetItemSlotQuality(button, nil)
        return
    end

    local _, character, isCurrent = Module:GetViewedCharacter()
    local texture
    local link
    local quality

    if isCurrent then
        texture = GetInventoryItemTexture("player", slotID)
        link = GetInventoryItemLink("player", slotID)
        quality = GetInventoryItemQuality
            and GetInventoryItemQuality("player", slotID)
    else
        local item = character
            and character.equipment
            and character.equipment[button.slotKey]

        if item then
            texture = item.icon
            link = item.link
            quality = item.quality
        end
    end

    button.cachedLink = link
    button.icon:SetTexture(texture)
    button.label:SetShown(not texture)
    Components:SetItemSlotBorderColor(button, Palette.emptyBorder)

    if quality == nil and link and GetItemInfo then
        _, _, quality = GetItemInfo(link)
    end

    Components:SetItemSlotQuality(button, quality)
end

local SetSidebarMode
local SetOuterPage

local function UpdatePlayerInfo(frame)
    local _, character, isCurrent = Module:GetViewedCharacter()
    local name
    local level
    local className
    local classFile

    if isCurrent then
        name = GetTitledPlayerName()
        level = UnitLevel("player") or 0
        className, classFile = UnitClass("player")
    else
        name = character and character.name or "Unknown"
        level = character and character.level or 0
        className = character and character.className or ""
        classFile = character and character.classFile
    end

    local classColor = Palette:GetClassColor(classFile)

    if classColor then
        frame.name:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        frame.name:SetTextColor(1, 1, 1)
    end

    frame.name:SetText(name)

    local classLabel = className

    if not classLabel or classLabel == "" then
        classLabel = classFile or ""
    end

    local levelLabel = level and level > 0 and tostring(level) or "?"

    frame.details:SetText(
        string.format(
            "Level %s %s",
            levelLabel,
            classLabel
        )
    )

    if frame.model then
        if isCurrent and frame.model.SetUnit then
            frame.model:Show()
            frame.model:SetUnit("player")

            if frame.offlineLabel then
                frame.offlineLabel:Hide()
            end
        else
            if frame.model.ClearModel then
                frame.model:ClearModel()
            end

            frame.model:Hide()

            if frame.offlineLabel then
                frame.offlineLabel:SetText("Cached character")
                frame.offlineLabel:Show()
            end
        end
    end
end

function Module:Refresh()
    if not self.frame then
        return
    end

    SaveCurrentEquipmentSnapshot()
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

    self.viewCharacterKey = nil
    self.frame.page = "character"
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

local function FormatStatValue(value, suffix)
    if not UI:CanAccessValue(value) or type(value) ~= "number" then
        return "-"
    end

    if suffix then
        return string.format("%.1f%s", value, suffix)
    end

    return string.format("%.0f", value)
end

local function GetFactionData(index)
    if not C_Reputation or not C_Reputation.GetFactionDataByIndex then
        return nil
    end

    local data = UI:SafeCall(C_Reputation.GetFactionDataByIndex, index)

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
        local label = UI:SafeCall(
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

local ShowStatTooltip

local function CreateSidebarRow(parent, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    row:SetHeight(18)
    row:EnableMouse(true)

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

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.04)

    row:SetScript("OnEnter", function(self)
        if ShowStatTooltip then
            ShowStatTooltip(self)
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return row
end

local function CreateSidebarHeader(parent, y, text)
    local header = Components:CreateSection(parent, {
        text = text,
        collapsible = true,
        expanded = true,
    })

    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)

    return header
end

local function UpdateStatsPane(frame)
    local pane = frame.sidebar and frame.sidebar.statsPane

    if not pane then
        return
    end

    local rows = pane.rows
    local _, _, isCurrent = Module:GetViewedCharacter()

    if not isCurrent then
        for _, row in pairs(rows) do
            if row.value then
                row.value:SetText("-")
            end
        end

        rows.health.label:SetText("Health")
        rows.power.label:SetText("Power")
        return
    end
    local health = UnitHealthMax and UnitHealthMax("player")
    local power = UnitPowerMax and UnitPowerMax("player")
    local powerName = "Power"

    if UnitPowerType then
        local _, token = UnitPowerType("player")

        if token and UI:CanAccessValue(token) then
            powerName = token:sub(1, 1) .. token:sub(2):lower()
        end
    end

    rows.health.label:SetText("Health")
    rows.health.value:SetText(FormatStatValue(health))
    rows.power.label:SetText(powerName)
    rows.power.value:SetText(FormatStatValue(power))

    local moveSpeed
    local currentSpeed, runSpeed = GetUnitSpeed
        and UI:SafeCall(GetUnitSpeed, "player")
    local speed = runSpeed or currentSpeed
    local baseSpeed = BASE_MOVEMENT_SPEED or 7

    if UI:CanAccessValue(speed)
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
        local effective = select(2, UI:SafeCall(UnitStat, "player", data[2]))
        rows[data[1]].value:SetText(FormatStatValue(effective))
    end

    local baseAP, posAP, negAP = UI:SafeCall(UnitAttackPower, "player")
    local attackPower

    if UI:CanAccessValue(baseAP)
        and UI:CanAccessValue(posAP)
        and UI:CanAccessValue(negAP)
        and type(baseAP) == "number"
        and type(posAP) == "number"
        and type(negAP) == "number"
    then
        attackPower = baseAP + posAP + negAP
    end

    rows.attackPower.value:SetText(FormatStatValue(attackPower))
    rows.crit.value:SetText(FormatStatValue(UI:SafeCall(GetCritChance), "%"))
    rows.hit.value:SetText(FormatStatValue(UI:SafeCall(GetHitModifier), "%"))

    local _, effectiveArmor = UI:SafeCall(UnitArmor, "player")
    rows.armor.value:SetText(FormatStatValue(effectiveArmor))
    rows.dodge.value:SetText(FormatStatValue(UI:SafeCall(GetDodgeChance), "%"))
    rows.parry.value:SetText(FormatStatValue(UI:SafeCall(GetParryChance), "%"))
    rows.block.value:SetText(FormatStatValue(UI:SafeCall(GetBlockChance), "%"))

    local resistances = {
        { "fire", 2 },
        { "nature", 3 },
        { "frost", 4 },
        { "shadow", 5 },
        { "arcane", 6 },
    }

    for _, data in ipairs(resistances) do
        local base, total = UI:SafeCall(UnitResistance, "player", data[2])
        local value = total

        if not UI:CanAccessValue(value) or type(value) ~= "number" then
            value = base
        end

        rows[data[1]].value:SetText(FormatStatValue(value))
    end
end

local statProxyParent = CreateFrame("Frame")
statProxyParent:Hide()

local statProxies = {}

local primaryStatIndices = {
    strength = 1,
    agility = 2,
    stamina = 3,
    intellect = 4,
    spirit = 5,
}

local primaryStatTokens = {
    strength = "STRENGTH",
    agility = "AGILITY",
    stamina = "STAMINA",
    intellect = "INTELLECT",
    spirit = "SPIRIT",
}

local paperDollStatKeys = {
    strength = { "STRENGTH", "BASE_STATS1" },
    agility = { "AGILITY", "BASE_STATS2" },
    stamina = { "STAMINA", "BASE_STATS3" },
    intellect = { "INTELLECT", "BASE_STATS4" },
    spirit = { "SPIRIT", "BASE_STATS5" },
    moveSpeed = { "MOVESPEED", "MOVEMENT_SPEED" },
    attackPower = { "MELEE_AP", "MELEE_ATTACK_POWER" },
    crit = { "CRITCHANCE", "MELEE_CRIT" },
    hit = { "HITCHANCE", "MELEE_HIT" },
    armor = { "DEFENSES1", "ARMOR" },
    dodge = { "DEFENSES3", "DODGE" },
    parry = { "DEFENSES4", "PARRY" },
    block = { "DEFENSES5", "BLOCK" },
    fire = { "FIRE" },
    nature = { "NATURE" },
    frost = { "FROST" },
    shadow = { "SHADOW" },
    arcane = { "ARCANE" },
}

local resistanceIndices = {
    fire = 2,
    nature = 3,
    frost = 4,
    shadow = 5,
    arcane = 6,
}

local function GetStatProxy(key)
    local proxy = statProxies[key]

    if proxy then
        return proxy
    end

    local suffix = key:gsub("[^%w]", "")
    local name = "KamiUICharacterStatProxy" .. suffix

    proxy = CreateFrame("Frame", name, statProxyParent)
    proxy:SetSize(1, 1)

    local label = proxy:CreateFontString(name .. "Label", "OVERLAY")
    label:SetPoint("LEFT")
    label:Hide()

    local text = proxy:CreateFontString(name .. "StatText", "OVERLAY")
    text:SetPoint("LEFT")
    text:Hide()

    statProxies[key] = proxy

    return proxy
end

local function ResetStatProxy(proxy)
    proxy.tooltip = nil
    proxy.tooltip2 = nil
    proxy.tooltip3 = nil
    proxy.tooltip4 = nil
    proxy.tooltipSubtext = nil
    proxy.onEnterFunc = nil
    proxy.UpdateTooltip = nil
end

local function TryPaperDollStatInfo(proxy, key)
    if type(PAPERDOLL_STATINFO) ~= "table" then
        return false
    end

    for _, statKey in ipairs(paperDollStatKeys[key] or {}) do
        local info = PAPERDOLL_STATINFO[statKey]

        if info and type(info.updateFunc) == "function" then
            local ok = pcall(info.updateFunc, proxy, "player")

            if ok then
                return true
            end
        end
    end

    return false
end

local function UpdateBlizzardStatProxy(proxy, key)
    ResetStatProxy(proxy)

    if TryPaperDollStatInfo(proxy, key) then
        return true
    end

    local statIndex = primaryStatIndices[key]

    if statIndex and PaperDollFrame_SetStat then
        return pcall(PaperDollFrame_SetStat, proxy, statIndex)
    end

    if key == "moveSpeed" and PaperDollFrame_SetMovementSpeed then
        return pcall(PaperDollFrame_SetMovementSpeed, proxy, "player")
    elseif key == "attackPower" and PaperDollFrame_SetAttackPower then
        return pcall(PaperDollFrame_SetAttackPower, proxy, "player")
    elseif key == "crit" then
        if PaperDollFrame_SetMeleeCritChance then
            return pcall(PaperDollFrame_SetMeleeCritChance, proxy)
        elseif PaperDollFrame_SetCritChance then
            return pcall(PaperDollFrame_SetCritChance, proxy)
        end
    elseif key == "hit" and PaperDollFrame_SetRating and CR_HIT_MELEE then
        return pcall(PaperDollFrame_SetRating, proxy, CR_HIT_MELEE)
    elseif key == "armor" and PaperDollFrame_SetArmor then
        return pcall(PaperDollFrame_SetArmor, proxy, "player")
    elseif key == "dodge" and PaperDollFrame_SetDodge then
        return pcall(PaperDollFrame_SetDodge, proxy)
    elseif key == "parry" and PaperDollFrame_SetParry then
        return pcall(PaperDollFrame_SetParry, proxy)
    elseif key == "block" and PaperDollFrame_SetBlock then
        return pcall(PaperDollFrame_SetBlock, proxy)
    end

    local resistanceIndex = resistanceIndices[key]

    if resistanceIndex and PaperDollFrame_SetResistance then
        return pcall(
            PaperDollFrame_SetResistance,
            proxy,
            "player",
            resistanceIndex
        )
    end

    return false
end

local function AddBlizzardTooltipLine(text)
    if type(text) == "string" and text ~= "" then
        GameTooltip:AddLine(text, 0.82, 0.82, 0.84, true)
        return true
    end

    return false
end

local function GetPrimaryStatFallback(key)
    local statToken = primaryStatTokens[key]

    if not statToken then
        return nil
    end

    local _, classFile = UnitClass("player")

    if type(classFile) == "string" then
        local classText = _G[
            string.upper(classFile)
                .. "_"
                .. statToken
                .. "_TOOLTIP"
        ]

        if type(classText) == "string" then
            return classText
        end
    end

    local defaultText = _G["DEFAULT_" .. statToken .. "_TOOLTIP"]

    if type(defaultText) == "string" then
        return defaultText
    end

    return nil
end

ShowStatTooltip = function(row)
    local key = row.statKey

    if not key then
        return
    end

    local _, _, isCurrent = Module:GetViewedCharacter()

    if not isCurrent then
        return
    end

    local proxy = GetStatProxy(key)
    local updated = UpdateBlizzardStatProxy(proxy, key)
    local tooltip = updated and proxy.tooltip

    GameTooltip:SetOwner(row, "ANCHOR_LEFT")

    if type(tooltip) == "string" and tooltip ~= "" then
        GameTooltip:SetText(tooltip)
    else
        GameTooltip:SetText(
            row.label:GetText() or key,
            1.00,
            0.82,
            0.00
        )
        GameTooltip:AddDoubleLine(
            "Current",
            row.value:GetText() or "-",
            0.72, 0.72, 0.75,
            1.00, 1.00, 1.00
        )
    end

    local addedDetail = false

    for _, field in ipairs({
        "tooltip2",
        "tooltip3",
        "tooltip4",
        "tooltipSubtext",
    }) do
        if AddBlizzardTooltipLine(proxy[field]) then
            addedDetail = true
        end
    end

    if not addedDetail then
        AddBlizzardTooltipLine(GetPrimaryStatFallback(key))
    end

    GameTooltip:Show()
end

local function OpenEquipmentSetPopup(frame, setID, setName)
    if not GearManagerPopupFrame
        or not IconSelectorPopupFrameModes
    then
        return false
    end

    GearManagerPopupFrame:SetParent(frame)
    GearManagerPopupFrame:SetFrameStrata("DIALOG")
    GearManagerPopupFrame:SetFrameLevel(frame:GetFrameLevel() + 40)
    GearManagerPopupFrame:SetClampedToScreen(true)
    GearManagerPopupFrame:ClearAllPoints()
    GearManagerPopupFrame:SetPoint(
        "TOPLEFT",
        frame,
        "TOPRIGHT",
        4,
        0
    )

    if setID then
        GearManagerPopupFrame.mode =
            IconSelectorPopupFrameModes.Edit
        GearManagerPopupFrame.setID = setID
        GearManagerPopupFrame.origName = setName or ""
    else
        GearManagerPopupFrame.mode =
            IconSelectorPopupFrameModes.New
        GearManagerPopupFrame.setID = nil
        GearManagerPopupFrame.origName = ""
    end

    GearManagerPopupFrame:Show()

    return true
end

local function UpdateEquipmentPane(frame)
    local pane = frame.sidebar and frame.sidebar.equipmentPane

    if not pane then
        return
    end

    local ids = C_EquipmentSet
        and C_EquipmentSet.GetEquipmentSetIDs
        and UI:SafeCall(C_EquipmentSet.GetEquipmentSetIDs)
        or {}

    if type(ids) ~= "table" then
        ids = {}
    end

    pane.setIDs = ids

    if pane.pendingSetName
        and C_EquipmentSet
        and C_EquipmentSet.GetEquipmentSetID
    then
        local pendingID = UI:SafeCall(
            C_EquipmentSet.GetEquipmentSetID,
            pane.pendingSetName
        )

        if pendingID then
            pane.selectedSetID = pendingID
            pane.pendingSetName = nil

            if LoadEquipmentIgnoreState then
                LoadEquipmentIgnoreState(frame, pendingID)
            end
        end
    end

    for index = 1, math.max(#ids, #pane.rows) do
        local row = pane.rows[index]

        if not row and index <= 10 then
            row = CreateFrame("Button", nil, pane)
            row:SetPoint("TOPLEFT", pane, "TOPLEFT", 6, -(34 + (index - 1) * 28))
            row:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -6, -(34 + (index - 1) * 28))
            row:SetHeight(26)
            row:RegisterForDrag("LeftButton")

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.04)
            row.background = bg

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", 2, 0)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.icon = icon

            local edit = CreateFrame("Button", nil, row)
            edit:SetSize(16, 16)
            edit:SetPoint("RIGHT", row, "RIGHT", -19, 0)

            local editTexture = edit:CreateTexture(nil, "ARTWORK")
            editTexture:SetAllPoints()
            editTexture:SetTexture("Interface\\WorldMap\\GEAR_64GREY")
            editTexture:SetAlpha(0.55)
            edit.texture = editTexture
            row.edit = edit

            edit:SetScript("OnEnter", function(self)
                self.texture:SetAlpha(1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(
                    EQUIPMENT_SET_SETTINGS or "Edit equipment set"
                )
                GameTooltip:Show()
            end)

            edit:SetScript("OnLeave", function(self)
                self.texture:SetAlpha(0.55)
                GameTooltip:Hide()
            end)

            edit:SetScript("OnClick", function(self)
                local owner = self:GetParent()

                if owner.setID then
                    OpenEquipmentSetPopup(
                        frame,
                        owner.setID,
                        owner.setName
                    )
                end
            end)

            local delete = CreateFrame("Button", nil, row)
            delete:SetSize(14, 14)
            delete:SetPoint("RIGHT", row, "RIGHT", -2, 0)

            local deleteTexture = delete:CreateTexture(nil, "ARTWORK")
            deleteTexture:SetAllPoints()
            deleteTexture:SetTexture(
                "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
            )
            deleteTexture:SetAlpha(0.55)
            delete.texture = deleteTexture
            row.delete = delete

            delete:SetScript("OnEnter", function(self)
                self.texture:SetAlpha(1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(DELETE or "Delete")
                GameTooltip:Show()
            end)

            delete:SetScript("OnLeave", function(self)
                self.texture:SetAlpha(0.55)
                GameTooltip:Hide()
            end)

            delete:SetScript("OnClick", function(self)
                local owner = self:GetParent()

                if not owner.setID or not StaticPopup_Show then
                    return
                end

                local dialog = StaticPopup_Show(
                    "CONFIRM_DELETE_EQUIPMENT_SET",
                    owner.setName or "",
                    nil,
                    owner.setID
                )

                if not dialog and UIErrorsFrame then
                    UIErrorsFrame:AddMessage(
                        ERR_CLIENT_LOCKED_OUT or "Unable to delete set",
                        1.0,
                        0.1,
                        0.1,
                        1.0
                    )
                end
            end)

            local name = row:CreateFontString(nil, "OVERLAY")
            name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            name:SetPoint("RIGHT", edit, "LEFT", -4, 0)
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

                if LoadEquipmentIgnoreState then
                    LoadEquipmentIgnoreState(frame, self.setID)
                end

                UpdateEquipmentPane(frame)
            end)

            row:SetScript("OnDoubleClick", function(self)
                if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
                    UI:SafeCall(C_EquipmentSet.UseEquipmentSet, self.setID)
                elseif EquipmentManager_EquipSet then
                    UI:SafeCall(EquipmentManager_EquipSet, self.setID)
                end
            end)

            row:SetScript("OnDragStart", function(self)
                if self.setID
                    and C_EquipmentSet
                    and C_EquipmentSet.PickupEquipmentSet
                then
                    C_EquipmentSet.PickupEquipmentSet(self.setID)
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
                    UI:SafeCall(C_EquipmentSet.GetEquipmentSetInfo, setID)

                row.setID = actualID or setID
                row.setName = name or "Set"
                row.icon:SetTexture(icon)
                row.name:SetText(row.setName)

                if numLost and numLost > 0 then
                    row.name:SetTextColor(1.0, 0.28, 0.28)
                else
                    row.name:SetTextColor(0.92, 0.92, 0.94)
                end

                local isSelected = pane.selectedSetID == row.setID

                if isEquipped then
                    if isSelected then
                        row.background:SetColorTexture(0.14, 0.64, 0.24, 0.38)
                    else
                        row.background:SetColorTexture(0.10, 0.52, 0.18, 0.26)
                    end
                else
                    row.background:SetColorTexture(1, 1, 1, 0.04)
                end

                row.selected:SetShown(isSelected and not isEquipped)
                row.isEquipped = isEquipped == true
                row:Show()
            else
                row.setID = nil
                row.setName = nil
                row:Hide()
            end
        end
    end

    local hasSelection = pane.selectedSetID ~= nil
    local selectedEquipped = false

    if hasSelection and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
        local _, _, _, isEquipped =
            UI:SafeCall(C_EquipmentSet.GetEquipmentSetInfo, pane.selectedSetID)
        selectedEquipped = isEquipped == true
    end

    local equipEnabled = hasSelection and not selectedEquipped
    local saveEnabled = hasSelection
        and (not selectedEquipped or pane.ignoreDirty == true)

    pane.equip:SetEnabled(equipEnabled)
    pane.save:SetEnabled(saveEnabled)

    local equipText = pane.equip:GetFontString()
    local saveText = pane.save:GetFontString()

    if equipText then
        if equipEnabled then
            equipText:SetTextColor(1.00, 0.82, 0.00)
        else
            equipText:SetTextColor(0.45, 0.45, 0.48)
        end
    end

    if saveText then
        if saveEnabled then
            saveText:SetTextColor(1.00, 0.82, 0.00)
        else
            saveText:SetTextColor(0.45, 0.45, 0.48)
        end
    end
end

SetSidebarMode = function(frame, mode)
    local sidebar = frame.sidebar

    if not sidebar then
        return
    end

    local _, _, isCurrent = Module:GetViewedCharacter()

    if not isCurrent and mode == "equipment" then
        mode = "stats"
    end

    sidebar.equipmentTab:SetEnabled(isCurrent)
    sidebar.equipmentTab:SetAlpha(isCurrent and 1 or 0.35)
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

        local pane = sidebar.equipmentPane

        if pane
            and pane.selectedSetID
            and pane.loadedIgnoreSetID ~= pane.selectedSetID
            and LoadEquipmentIgnoreState
        then
            LoadEquipmentIgnoreState(frame, pane.selectedSetID)
        end
    end

    if UpdateEquipmentIgnoreOverlays then
        UpdateEquipmentIgnoreOverlays(frame)
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
    Styles:CreateBorder(box, Palette.border)

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
        local active = UI:SafeCall(C_Reputation.IsFactionActive, index)

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
        UI:SafeCall(C_Reputation.GetNumFactions)
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
                                UI:SafeCall(
                                    C_Reputation.ExpandFactionHeader,
                                    self.index
                                )
                            end
                        elseif C_Reputation.CollapseFactionHeader then
                            UI:SafeCall(
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
                            UI:SafeCall(
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
    local _, thumb = Components:StyleScrollBar(scrollbar)

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
    topDivider:SetColorTexture(unpack(Palette.border))

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
    splitDivider:SetColorTexture(unpack(Palette.border))

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
    Styles:CreateBorder(bar, Palette.border)
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
            UI:SafeCall(
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
            local active = UI:SafeCall(
                C_Reputation.IsFactionActive,
                pane.selectedIndex
            )

            if type(active) == "boolean" then
                isActive = active
            end
        end

        UI:SafeCall(
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
            UI:SafeCall(
                C_Reputation.SetWatchedFactionByIndex,
                pane.selectedIndex
            )
        elseif pane.selectedFactionID
            and C_Reputation.SetWatchedFactionByID
        then
            UI:SafeCall(
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
        local data = UI:SafeCall(C_SkillInfo.GetSkillLineInfo, index)

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
            UI:SafeCall(C_SkillInfo.GetNumSkillLines)
        ) or 0
    end

    if GetNumSkillLines then
        return tonumber(UI:SafeCall(GetNumSkillLines)) or 0
    end

    return 0
end

local function SetSelectedSkillValue(index)
    if C_SkillInfo and C_SkillInfo.SetSelectedSkill then
        UI:SafeCall(C_SkillInfo.SetSelectedSkill, index)
    elseif SetSelectedSkill then
        UI:SafeCall(SetSelectedSkill, index)
    end
end

local function ExpandSkillHeaderValue(index)
    if C_SkillInfo and C_SkillInfo.ExpandSkillHeader then
        UI:SafeCall(C_SkillInfo.ExpandSkillHeader, index)
    elseif ExpandSkillHeader then
        UI:SafeCall(ExpandSkillHeader, index)
    end
end

local function CollapseSkillHeaderValue(index)
    if C_SkillInfo and C_SkillInfo.CollapseSkillHeader then
        UI:SafeCall(C_SkillInfo.CollapseSkillHeader, index)
    elseif CollapseSkillHeader then
        UI:SafeCall(CollapseSkillHeader, index)
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
                UI:SafeCall(C_SkillInfo.GetSelectedSkill)
            )
        elseif GetSelectedSkill then
            selectedFromAPI = tonumber(
                UI:SafeCall(GetSelectedSkill)
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
    local _, thumb = Components:StyleScrollBar(scrollbar)

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
    topDivider:SetColorTexture(unpack(Palette.border))

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
    splitDivider:SetColorTexture(unpack(Palette.border))

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
    Styles:CreateBorder(bar, Palette.border)
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

local nativeCharacterPages = {
    pvp = {
        frameName = "PVPRankFrame",
        title = "Player vs. Player",
    },
    currency = {
        addon = "Blizzard_TokenUI",
        frameName = "TokenFrame",
        title = "Currency",
    },
    statistics = {
        addon = "Blizzard_Statistics",
        frameName = "StatisticsFrame",
        title = "Statistics",
    },
}

local function LoadNativePageAddon(config)
    if not config or not config.addon or _G[config.frameName] then
        return
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, config.addon)
    elseif LoadAddOn then
        pcall(LoadAddOn, config.addon)
    end
end

local function LayoutNativeCharacterPage(frame, page, nativeFrame)
    local leftPane = frame.nativeLeftPane
    local rightPane = frame.nativeRightPane

    nativeFrame:ClearAllPoints()
    nativeFrame:SetAllPoints(frame.nativePane)

    if page == "pvp" then
        if nativeFrame.SeasonTimerField then
            nativeFrame.SeasonTimerField:ClearAllPoints()
            nativeFrame.SeasonTimerField:SetPoint(
                "TOPRIGHT",
                leftPane,
                "TOPRIGHT",
                -8,
                -8
            )
        end

        if nativeFrame.MainInfoFrame then
            nativeFrame.MainInfoFrame:ClearAllPoints()
            nativeFrame.MainInfoFrame:SetPoint(
                "TOPLEFT",
                leftPane,
                "TOPLEFT",
                0,
                -18
            )
            nativeFrame.MainInfoFrame:SetPoint(
                "BOTTOMRIGHT",
                leftPane,
                "BOTTOMRIGHT",
                0,
                0
            )
        end

        if nativeFrame.DetailFrame then
            nativeFrame.DetailFrame:ClearAllPoints()
            nativeFrame.DetailFrame:SetPoint(
                "TOPLEFT",
                rightPane,
                "TOPLEFT",
                7,
                -8
            )
            nativeFrame.DetailFrame:SetPoint(
                "BOTTOMRIGHT",
                rightPane,
                "BOTTOMRIGHT",
                -7,
                8
            )
        end
    elseif page == "currency" then
        if nativeFrame.ScrollBox then
            nativeFrame.ScrollBox:ClearAllPoints()
            nativeFrame.ScrollBox:SetPoint(
                "TOPLEFT",
                leftPane,
                "TOPLEFT",
                8,
                -8
            )
            nativeFrame.ScrollBox:SetPoint(
                "BOTTOMRIGHT",
                leftPane,
                "BOTTOMRIGHT",
                -22,
                8
            )
        end

        if nativeFrame.ScrollBar and nativeFrame.ScrollBox then
            nativeFrame.ScrollBar:ClearAllPoints()
            nativeFrame.ScrollBar:SetPoint(
                "TOPLEFT",
                nativeFrame.ScrollBox,
                "TOPRIGHT",
                4,
                -2
            )
            nativeFrame.ScrollBar:SetPoint(
                "BOTTOMLEFT",
                nativeFrame.ScrollBox,
                "BOTTOMRIGHT",
                4,
                4
            )
        end

        if nativeFrame.LoadingSpinner then
            nativeFrame.LoadingSpinner:ClearAllPoints()
            nativeFrame.LoadingSpinner:SetPoint("CENTER", leftPane)
        end

        if nativeFrame.DetailFrame then
            nativeFrame.DetailFrame:ClearAllPoints()
            nativeFrame.DetailFrame:SetPoint(
                "TOPLEFT",
                rightPane,
                "TOPLEFT",
                7,
                -8
            )
            nativeFrame.DetailFrame:SetPoint(
                "BOTTOMRIGHT",
                rightPane,
                "BOTTOMRIGHT",
                -7,
                8
            )
        end
    elseif page == "statistics" then
        if nativeFrame.ScrollBox then
            nativeFrame.ScrollBox:ClearAllPoints()
            nativeFrame.ScrollBox:SetPoint(
                "TOPLEFT",
                leftPane,
                "TOPLEFT",
                8,
                -8
            )
            nativeFrame.ScrollBox:SetPoint(
                "BOTTOMRIGHT",
                leftPane,
                "BOTTOMRIGHT",
                -22,
                8
            )
        end

        if nativeFrame.ScrollBar and nativeFrame.ScrollBox then
            nativeFrame.ScrollBar:ClearAllPoints()
            nativeFrame.ScrollBar:SetPoint(
                "TOPLEFT",
                nativeFrame.ScrollBox,
                "TOPRIGHT",
                4,
                -2
            )
            nativeFrame.ScrollBar:SetPoint(
                "BOTTOMLEFT",
                nativeFrame.ScrollBox,
                "BOTTOMRIGHT",
                4,
                4
            )
        end
    end

    if (page == "currency" or page == "statistics")
        and nativeFrame.ScrollBar
    then
        Components:StyleScrollBar(nativeFrame.ScrollBar)
    end
end

local function HideNativeHeaderTextures(row, keepTexture)
    if row.KamiHeaderTexturesHidden then
        return
    end

    row.KamiHeaderTexturesHidden = true

    for index = 1, select("#", row:GetRegions()) do
        local region = select(index, row:GetRegions())

        if region
            and region.IsObjectType
            and region:IsObjectType("Texture")
            and region ~= keepTexture
        then
            region:SetAlpha(0)
        end
    end
end

local function HideNativeToggleTextures(button)
    if not button then
        return
    end

    local normal = button:GetNormalTexture()
    local pushed = button:GetPushedTexture()
    local highlight = button:GetHighlightTexture()

    if normal then
        normal:SetAlpha(0)
    end

    if pushed then
        pushed:SetAlpha(0)
    end

    if highlight then
        highlight:SetAlpha(0)
    end
end

local function EnsureNativeHeaderBackground(row)
    if row.KamiHeaderBackground then
        return row.KamiHeaderBackground
    end

    local background = row:CreateTexture(nil, "BACKGROUND", nil, 7)
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, 0.055)
    row.KamiHeaderBackground = background

    return background
end

local function StyleNativeHeader(
    row,
    label,
    text,
    collapsed,
    indent,
    refresh
)
    if not row or not label then
        return
    end

    HideNativeHeaderTextures(row, row.StateIcon)
    EnsureNativeHeaderBackground(row)

    if row.StateIcon then
        row.StateIcon:SetAlpha(0)
    end

    if row.ToggleCollapseButton then
        HideNativeToggleTextures(row.ToggleCollapseButton)
    end

    label:ClearAllPoints()
    label:SetPoint("LEFT", row, "LEFT", indent or 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetTextColor(0.88, 0.72, 0.16)
    label:SetText(
        string.format(
            "%s %s",
            collapsed and "+" or "-",
            text or ""
        )
    )

    if refresh
        and row.IsObjectType
        and row:IsObjectType("Button")
        and not row.KamiHeaderClickHooked
    then
        row.KamiHeaderClickHooked = true
        row:HookScript("OnClick", function()
            C_Timer.After(0, refresh)
        end)
    end

    if refresh
        and row.ToggleCollapseButton
        and not row.ToggleCollapseButton.KamiHeaderClickHooked
    then
        row.ToggleCollapseButton.KamiHeaderClickHooked = true
        row.ToggleCollapseButton:HookScript("OnClick", function()
            C_Timer.After(0, refresh)
        end)
    end
end

local function StyleNativeEntry(row, name, value)
    if not row then
        return
    end

    if name then
        name:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        name:SetTextColor(0.92, 0.92, 0.94)
    end

    if value then
        value:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        value:SetTextColor(0.90, 0.90, 0.92)
    end

    local highlight = row.Content
        and row.Content.BackgroundHighlight

    if highlight and highlight.TextureRegions then
        for _, texture in ipairs(highlight.TextureRegions) do
            texture:SetVertexColor(1, 1, 1)
        end
    end
end

local function StyleNativeCharacterPageList(frame, page, nativeFrame)
    local scrollBox = nativeFrame and nativeFrame.ScrollBox

    if not scrollBox or not scrollBox.ForEachFrame then
        return
    end

    local function Refresh()
        if nativeFrame:IsShown() then
            StyleNativeCharacterPageList(frame, page, nativeFrame)
        end
    end

    scrollBox:ForEachFrame(function(row)
        local data = row.elementData

        if page == "currency" then
            if data and data.isHeader then
                local collapsed = not data.isHeaderExpanded

                if row.Name then
                    StyleNativeHeader(
                        row,
                        row.Name,
                        data.name,
                        collapsed,
                        6,
                        Refresh
                    )
                elseif row.Text then
                    StyleNativeHeader(
                        row,
                        row.Text,
                        data.name,
                        collapsed,
                        14,
                        Refresh
                    )
                end
            elseif row.Content then
                StyleNativeEntry(
                    row,
                    row.Content.Name,
                    row.Content.Count
                )
            end
        elseif page == "statistics" then
            if data and data.isCategory then
                local collapsed = row.treeNode
                    and row.treeNode.IsCollapsed
                    and row.treeNode:IsCollapsed()

                if row.Name then
                    StyleNativeHeader(
                        row,
                        row.Name,
                        data.name,
                        collapsed == true,
                        6,
                        Refresh
                    )
                elseif row.Content and row.Content.Name then
                    StyleNativeHeader(
                        row,
                        row.Content.Name,
                        data.name,
                        collapsed == true,
                        14,
                        Refresh
                    )
                end
            elseif row.Content then
                StyleNativeEntry(
                    row,
                    row.Content.Name,
                    row.Content.Value
                )
            end
        end
    end)
end

local function EnsureNativeCharacterPage(frame, page)
    local config = nativeCharacterPages[page]

    if not config then
        return nil
    end

    LoadNativePageAddon(config)

    local nativeFrame = _G[config.frameName]

    if not nativeFrame then
        return nil
    end

    if nativeFrame:GetParent() ~= frame.nativePane then
        nativeFrame:SetParent(frame.nativePane)
        nativeFrame:SetFrameStrata(frame:GetFrameStrata())
        nativeFrame:SetFrameLevel(frame.nativePane:GetFrameLevel() + 1)
    end

    LayoutNativeCharacterPage(frame, page, nativeFrame)
    frame.nativePages[page] = nativeFrame

    if (page == "currency" or page == "statistics")
        and not nativeFrame.KamiListStyleHooked
        and hooksecurefunc
        and nativeFrame.Update
    then
        nativeFrame.KamiListStyleHooked = true

        hooksecurefunc(nativeFrame, "Update", function(self)
            C_Timer.After(0, function()
                if self:IsShown() then
                    StyleNativeCharacterPageList(
                        frame,
                        page,
                        self
                    )
                end
            end)
        end)
    end

    if page == "currency" or page == "statistics" then
        C_Timer.After(0, function()
            if nativeFrame:IsShown() then
                StyleNativeCharacterPageList(
                    frame,
                    page,
                    nativeFrame
                )
            end
        end)
    end

    return nativeFrame
end

local function HideNativeCharacterPages(frame, exceptPage)
    for page, nativeFrame in pairs(frame.nativePages or {}) do
        if page ~= exceptPage and nativeFrame then
            nativeFrame:Hide()
        end
    end
end

SetOuterPage = function(frame, page)
    local _, _, isCurrent = Module:GetViewedCharacter()
    local validPages = {
        character = true,
        reputation = true,
        skills = true,
        pvp = true,
        currency = true,
        statistics = true,
    }

    if not isCurrent or not validPages[page] then
        page = "character"
    end

    local nativePage = nativeCharacterPages[page]
    local nativeFrame

    if nativePage then
        nativeFrame = EnsureNativeCharacterPage(frame, page)

        if not nativeFrame then
            UI:Print("Blizzard " .. page .. " page is unavailable")
            page = "character"
            nativePage = nil
        end
    end

    frame.page = page
    HideNativeCharacterPages(frame, nativePage and page or nil)

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

    if frame.nativePane then
        frame.nativePane:SetShown(nativePage ~= nil)
    end

    if nativeFrame then
        nativeFrame:Show()
    end

    if page == "character" then
        UpdatePlayerInfo(frame)
        frame.details:Show()
        frame.titleButton:SetShown(isCurrent)
        frame.titleArrow:SetShown(isCurrent)
    elseif page == "reputation" then
        frame.name:SetText("Reputation")
        frame.name:SetTextColor(0.88, 0.72, 0.16)
        frame.details:Hide()
        frame.titleButton:Hide()
        frame.titleArrow:Hide()
        UpdateReputationPane(frame)
    elseif page == "skills" then
        frame.name:SetText("Skills")
        frame.name:SetTextColor(0.88, 0.72, 0.16)
        frame.details:Hide()
        frame.titleButton:Hide()
        frame.titleArrow:Hide()
        UpdateSkillsPane(frame)
    elseif nativePage then
        frame.name:SetText(nativePage.title)
        frame.name:SetTextColor(0.88, 0.72, 0.16)
        frame.details:Hide()
        frame.titleButton:Hide()
        frame.titleArrow:Hide()
    end

    for _, tab in ipairs(frame.tabs or {}) do
        local active = tab.page == page
        local available = tab.enabled
            and (isCurrent or tab.page == "character")

        tab:SetEnabled(available)

        Components:SetTabState(tab, active, available)
    end
end

local function LayoutOuterTabs(frame)
    local tabWidth = 76

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
    sidebar:SetBackdropBorderColor(unpack(Palette.border))
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
    local statsBorders = Styles:CreateBorder(statsTab, Palette.border)
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
    local equipmentBorders = Styles:CreateBorder(equipmentTab, Palette.border)
    equipmentBorders[1]:Hide()
    equipmentBorders[3]:Hide()
    equipmentBorders[4]:Hide()

    local tabDivider = equipmentTab:CreateTexture(nil, "OVERLAY")
    tabDivider:SetPoint("TOPLEFT")
    tabDivider:SetPoint("BOTTOMLEFT")
    tabDivider:SetWidth(1)
    tabDivider:SetColorTexture(unpack(Palette.border))

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

    local _, scrollThumb = Components:StyleScrollBar(statsScrollbar)

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

        local paneWidth = statsPane:GetWidth() or 0

        if maxScroll > 0 then
            statsContent:SetWidth(math.max(1, paneWidth - 9))
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
            statsContent:SetWidth(math.max(1, paneWidth))
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
                self:SetExpanded(not self.collapsed)
                LayoutStatsContent()
            end)
        else
            local row = CreateSidebarRow(statsContent, -4)
            row:SetHeight(13)
            row.label:SetText(data.label)
            row.value:SetText("-")
            row.section = currentSection
            row.statKey = data.key
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
                    0,
                    y
                )
                widget:SetPoint(
                    "TOPRIGHT",
                    statsContent,
                    "TOPRIGHT",
                    0,
                    y
                )
                widget:SetExpanded(not collapsed)
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
    empty:SetPoint("TOPLEFT", equipmentPane, "TOPLEFT", 8, -10)
    empty:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    empty:SetTextColor(0.55, 0.55, 0.58)
    empty:SetText("Equipment Sets")
    equipmentPane.empty = empty

    local newSet = CreateFrame("Button", nil, equipmentPane)
    newSet:SetSize(44, 18)
    newSet:SetPoint("TOPRIGHT", equipmentPane, "TOPRIGHT", -6, -5)
    newSet:SetNormalFontObject("GameFontNormalSmall")
    newSet:SetHighlightFontObject("GameFontHighlightSmall")
    newSet:SetText("New")

    local newBackground = newSet:CreateTexture(nil, "BACKGROUND")
    newBackground:SetAllPoints()
    newBackground:SetColorTexture(1, 1, 1, 0.10)
    Styles:CreateBorder(newSet, Palette.border)

    local newHighlight = newSet:CreateTexture(nil, "HIGHLIGHT")
    newHighlight:SetAllPoints()
    newHighlight:SetColorTexture(1, 1, 1, 0.10)
    equipmentPane.newSet = newSet

    local createDialog = CreateFrame(
        "Frame",
        nil,
        equipmentPane,
        "BackdropTemplate"
    )
    createDialog:SetSize(145, 78)
    createDialog:SetPoint("CENTER", equipmentPane, "CENTER", 0, 12)
    createDialog:SetFrameLevel(equipmentPane:GetFrameLevel() + 20)
    createDialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    createDialog:SetBackdropColor(0, 0, 0, 0.96)
    createDialog:SetBackdropBorderColor(unpack(Palette.border))
    createDialog:Hide()
    equipmentPane.createDialog = createDialog

    local dialogTitle = createDialog:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    dialogTitle:SetPoint("TOP", 0, -7)
    dialogTitle:SetText("New Equipment Set")

    local nameInput = CreateFrame(
        "EditBox",
        nil,
        createDialog,
        "InputBoxTemplate"
    )
    nameInput:SetSize(125, 20)
    nameInput:SetPoint("TOP", dialogTitle, "BOTTOM", 0, -6)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(31)
    createDialog.nameInput = nameInput

    local createButton = CreateFrame("Button", nil, createDialog)
    createButton:SetSize(56, 18)
    createButton:SetPoint("BOTTOMLEFT", createDialog, "BOTTOMLEFT", 9, 7)
    createButton:SetNormalFontObject("GameFontNormalSmall")
    createButton:SetHighlightFontObject("GameFontHighlightSmall")
    createButton:SetText("Create")

    local createBackground = createButton:CreateTexture(nil, "BACKGROUND")
    createBackground:SetAllPoints()
    createBackground:SetColorTexture(1, 1, 1, 0.12)
    Styles:CreateBorder(createButton, Palette.border)

    local createHighlight = createButton:CreateTexture(nil, "HIGHLIGHT")
    createHighlight:SetAllPoints()
    createHighlight:SetColorTexture(1, 1, 1, 0.10)

    local cancelButton = CreateFrame("Button", nil, createDialog)
    cancelButton:SetSize(56, 18)
    cancelButton:SetPoint("BOTTOMRIGHT", createDialog, "BOTTOMRIGHT", -9, 7)
    cancelButton:SetNormalFontObject("GameFontNormalSmall")
    cancelButton:SetHighlightFontObject("GameFontHighlightSmall")
    cancelButton:SetText("Cancel")

    local cancelBackground = cancelButton:CreateTexture(nil, "BACKGROUND")
    cancelBackground:SetAllPoints()
    cancelBackground:SetColorTexture(1, 1, 1, 0.08)
    Styles:CreateBorder(cancelButton, Palette.border)

    local cancelHighlight = cancelButton:CreateTexture(nil, "HIGHLIGHT")
    cancelHighlight:SetAllPoints()
    cancelHighlight:SetColorTexture(1, 1, 1, 0.08)

    local function CloseCreateDialog()
        nameInput:ClearFocus()
        createDialog:Hide()
    end

    local function CreateEquipmentSet()
        local name = nameInput:GetText() or ""

        if strtrim then
            name = strtrim(name)
        else
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
        end

        if name == ""
            or not C_EquipmentSet
            or not C_EquipmentSet.CreateEquipmentSet
        then
            return
        end

        equipmentPane.pendingSetName = name
        UI:SafeCall(C_EquipmentSet.CreateEquipmentSet, name)
        CloseCreateDialog()

        C_Timer.After(0, function()
            UpdateEquipmentPane(frame)
        end)
    end

    newSet:SetScript("OnClick", function()
        if OpenEquipmentSetPopup(frame) then
            return
        end

        nameInput:SetText("")
        createDialog:Show()
        nameInput:SetFocus()
    end)

    createButton:SetScript("OnClick", CreateEquipmentSet)
    cancelButton:SetScript("OnClick", CloseCreateDialog)
    nameInput:SetScript("OnEnterPressed", CreateEquipmentSet)
    nameInput:SetScript("OnEscapePressed", CloseCreateDialog)

    equipmentPane:SetScript("OnHide", function()
        CloseCreateDialog()
    end)

    local equip = CreateFrame("Button", nil, equipmentPane)
    equip:SetSize(66, 20)
    equip:SetPoint("BOTTOMRIGHT", equipmentPane, "BOTTOM", -3, 8)
    equip:SetNormalFontObject("GameFontNormalSmall")
    equip:SetHighlightFontObject("GameFontHighlightSmall")
    equip:SetText("Equip")

    local equipBackground = equip:CreateTexture(nil, "BACKGROUND")
    equipBackground:SetAllPoints()
    equipBackground:SetColorTexture(1, 1, 1, 0.12)
    Styles:CreateBorder(equip, Palette.border)

    local equipHighlight = equip:CreateTexture(nil, "HIGHLIGHT")
    equipHighlight:SetAllPoints()
    equipHighlight:SetColorTexture(1, 1, 1, 0.10)

    equip:SetScript("OnClick", function()
        local setID = equipmentPane.selectedSetID

        if not setID then
            return
        end

        if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
            UI:SafeCall(C_EquipmentSet.UseEquipmentSet, setID)
        elseif EquipmentManager_EquipSet then
            UI:SafeCall(EquipmentManager_EquipSet, setID)
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
    Styles:CreateBorder(save, Palette.border)

    local saveHighlight = save:CreateTexture(nil, "HIGHLIGHT")
    saveHighlight:SetAllPoints()
    saveHighlight:SetColorTexture(1, 1, 1, 0.10)

    save:SetScript("OnClick", function()
        local setID = equipmentPane.selectedSetID

        if setID
            and C_EquipmentSet
            and C_EquipmentSet.SaveEquipmentSet
        then
            if ApplyEquipmentIgnoreState then
                ApplyEquipmentIgnoreState(frame)
            end

            UI:SafeCall(C_EquipmentSet.SaveEquipmentSet, setID)
            equipmentPane.ignoreDirty = false

            C_Timer.After(0, function()
                if LoadEquipmentIgnoreState then
                    LoadEquipmentIgnoreState(frame, setID)
                end
            end)
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

    Styles:ApplyBackdrop(
        frame,
        Palette.window.neutral,
        Palette.border
    )

    local characterPane = CreateFrame("Frame", nil, frame)
    characterPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    characterPane:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    characterPane:SetWidth(CHARACTER_WIDTH - 1)
    frame.characterPane = characterPane

    local nativePane = CreateFrame("Frame", nil, frame)
    nativePane:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        1,
        -HEADER_HEIGHT
    )
    nativePane:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -1,
        1
    )
    nativePane:SetFrameLevel(frame:GetFrameLevel() + 1)
    nativePane:Hide()
    frame.nativePane = nativePane
    frame.nativePages = {}

    local nativeLeftPane = CreateFrame("Frame", nil, nativePane)
    nativeLeftPane:SetPoint("TOPLEFT")
    nativeLeftPane:SetPoint("BOTTOMLEFT")
    nativeLeftPane:SetWidth(LEFT_PANE_WIDTH - 2)
    frame.nativeLeftPane = nativeLeftPane

    local nativeRightPane = CreateFrame("Frame", nil, nativePane)
    nativeRightPane:SetPoint(
        "TOPLEFT",
        nativeLeftPane,
        "TOPRIGHT",
        1,
        0
    )
    nativeRightPane:SetPoint("BOTTOMRIGHT")
    frame.nativeRightPane = nativeRightPane

    local nativeDivider = nativePane:CreateTexture(nil, "OVERLAY")
    nativeDivider:SetPoint(
        "TOPLEFT",
        nativeLeftPane,
        "TOPRIGHT",
        0,
        0
    )
    nativeDivider:SetPoint(
        "BOTTOMLEFT",
        nativeLeftPane,
        "BOTTOMRIGHT",
        0,
        0
    )
    nativeDivider:SetWidth(1)
    nativeDivider:SetColorTexture(unpack(Palette.border))

    local header = Components:CreateWindowHeader(frame, {
        height = HEADER_HEIGHT - 1,
        hasSubtitle = true,
        draggable = true,
        onDragStop = function()
            UI:SaveFramePosition(frame, GetDatabase())
        end,
    })
    frame.header = header

    local characterButton = CreateFrame("Button", nil, header)
    characterButton:SetSize(22, 22)
    characterButton:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -4)
    characterButton:SetFrameLevel(header:GetFrameLevel() + 10)

    local characterIcon = characterButton:CreateTexture(nil, "ARTWORK")
    characterIcon:SetAllPoints()
    characterIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    characterIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    characterButton.icon = characterIcon
    frame.characterButton = characterButton

    local characterMenu = Components:CreatePopupMenu(
        frame,
        header,
        {
            point = "TOPLEFT",
            relativePoint = "BOTTOMLEFT",
            x = 3,
            y = -2,
            width = 210,
            frameLevel = frame:GetFrameLevel() + 30,
            backgroundColor = { 0, 0, 0, 0.94 },
            borderColor = Palette.border,
            fontSize = 9,
        }
    )
    frame.characterMenu = characterMenu

    local function RebuildCharacterMenu()
        local characters = Module:GetSortedCharacters()

        for index, entry in ipairs(characters) do
            local button = Components:AcquirePopupMenuButton(
                characterMenu,
                index
            )

            local character = entry.character
            button.text:SetText(
                Components:FormatCharacterLabel(character)
            )
            button.characterKey = entry.key
            button:SetScript("OnClick", function(self)
                Module:SetViewedCharacter(self.characterKey)
            end)
            button:Show()

        end

        Components:FinishPopupMenu(
            characterMenu,
            #characters
        )
    end

    characterButton:SetScript("OnClick", function()
        if characterMenu:IsShown() then
            characterMenu:Hide()
        else
            RebuildCharacterMenu()
            characterMenu:Show()
        end
    end)

    characterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Characters")
        GameTooltip:Show()
    end)

    characterButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local name = header.Title
    frame.name = name

    local details = header.Subtitle
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
    titleMenu:SetBackdropBorderColor(unpack(Palette.border))
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
        UI:SaveFramePosition(frame, GetDatabase())

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

    local close = CreateFrame("Button", nil, header)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -3, -3)
    close:SetFrameLevel(header:GetFrameLevel() + 10)
    close:RegisterForClicks("LeftButtonUp")
    close:SetNormalFontObject("GameFontNormal")
    close:SetHighlightFontObject("GameFontHighlight")
    close:SetText("x")
    close:SetScript("OnClick", function()
        Module:Hide()
    end)
    frame.close = close

    local modelPanel = CreateFrame("Frame", nil, characterPane, "BackdropTemplate")
    modelPanel:SetPoint("TOP", characterPane, "TOP", 0, -54)
    modelPanel:SetPoint("BOTTOM", characterPane, "BOTTOM", 0, 58)
    modelPanel:SetWidth(230)
    modelPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    modelPanel:SetBackdropColor(unpack(Palette.panelStrong))
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

    local offlineLabel = modelPanel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    offlineLabel:SetPoint("CENTER", modelPanel, "CENTER", 0, 0)
    offlineLabel:SetTextColor(0.60, 0.60, 0.64)
    offlineLabel:SetText("Cached character")
    offlineLabel:Hide()
    frame.offlineLabel = offlineLabel

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
        { label = "PvP", page = "pvp", enabled = true },
        {
            label = "Currency",
            page = "currency",
            enabled = true,
        },
        {
            label = "Statistics",
            page = "statistics",
            enabled = true,
        },
    }

    frame.tabs = {}

    for index, definition in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(76, 22)
        tab:SetFrameLevel(frame:GetFrameLevel() + 2)
        tab:SetNormalFontObject("GameFontNormalSmall")
        tab:SetHighlightFontObject("GameFontHighlightSmall")
        tab:SetText(definition.label)

        Components:StyleTab(tab, {
            orientation = "bottom",
            joinLeft = index > 1,
            enabled = definition.enabled == true,
        })

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
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        Module:Refresh()
    end)

    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        GameTooltip:Hide()

        if frame.titleMenu then
            frame.titleMenu:Hide()
        end

        if frame.characterMenu then
            frame.characterMenu:Hide()
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

    UI:ApplyFramePosition(frame, GetDatabase(), "position", 0, 10)

    return frame
end

function Module:Initialize()
    GetDatabase()
    ImportLegacyBagCharacters()
    UpdateCurrentCharacter()
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
        UpdateCurrentCharacter()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MONEY", function()
        UpdateCurrentCharacter()
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
