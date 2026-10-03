local UI = KamiUI

local Module = UI:NewModule("Characters")

Module.name = "KamiUI_Characters"
Module.version = "0.2.0"

local FRAME_WIDTH = 430
local FRAME_HEIGHT = 500
local SLOT_SIZE = 40
local SLOT_GAP = 4

local colors = {
    background = { 0.015, 0.015, 0.020, 0.94 },
    panel = { 0.025, 0.025, 0.035, 0.90 },
    slot = { 0.025, 0.025, 0.025, 0.95 },
    border = { 0.18, 0.18, 0.20, 1.00 },
    emptyBorder = { 0.22, 0.22, 0.24, 1.00 },
}

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

local function CreateEquipmentSlot(parent, definition)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SLOT_SIZE, SLOT_SIZE)
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

local function LayoutEquipmentSlot(button, definition, frame)
    local top = -82

    button:ClearAllPoints()

    if definition.side == "LEFT" then
        button:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            18,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    elseif definition.side == "RIGHT" then
        button:SetPoint(
            "TOPRIGHT",
            frame,
            "TOPRIGHT",
            -18,
            top - (definition.row - 1) * (SLOT_SIZE + SLOT_GAP)
        )
    else
        local totalWidth = SLOT_SIZE * 3 + SLOT_GAP * 2
        local startX = -totalWidth / 2 + SLOT_SIZE / 2
        local x = startX + (definition.column - 1) * (SLOT_SIZE + SLOT_GAP)

        button:SetPoint(
            "BOTTOM",
            frame,
            "BOTTOM",
            x,
            42
        )
    end
end

local function UpdateEquipmentSlot(button)
    local slotID = button.slotID

    if not slotID then
        button.icon:SetTexture(nil)
        button.label:Show()
        SetBorderColor(button, colors.emptyBorder)
        return
    end

    local texture = GetInventoryItemTexture("player", slotID)
    local link = GetInventoryItemLink("player", slotID)

    button.icon:SetTexture(texture)
    button.label:SetShown(not texture)

    if link and GetItemInfo then
        local _, _, quality = GetItemInfo(link)
        local color = quality
            and ITEM_QUALITY_COLORS
            and ITEM_QUALITY_COLORS[quality]

        if color then
            SetBorderColor(button, { color.r, color.g, color.b, 1 })
            return
        end
    end

    SetBorderColor(button, colors.emptyBorder)
end

local function UpdatePlayerInfo(frame)
    local name = GetFullPlayerName()
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

local function CreateFrameUI()
    local frame = CreateFrame(
        "Frame",
        "KamiUICharacterFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
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
    header:SetHeight(54)

    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetAllPoints()
    headerBackground:SetColorTexture(0.02, 0.02, 0.03, 0.96)

    local name = header:CreateFontString(nil, "OVERLAY")
    name:SetPoint("TOP", 0, -9)
    name:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.name = name

    local details = header:CreateFontString(nil, "OVERLAY")
    details:SetPoint("TOP", name, "BOTTOM", 0, -3)
    details:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    details:SetTextColor(0.72, 0.72, 0.75)
    frame.details = details

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
    modelPanel:SetPoint("TOPLEFT", 66, -70)
    modelPanel:SetPoint("BOTTOMRIGHT", -66, 92)
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

    for _, definition in ipairs(SLOT_LAYOUT) do
        local button = CreateEquipmentSlot(frame, definition)
        LayoutEquipmentSlot(button, definition, frame)
        frame.equipmentSlots[#frame.equipmentSlots + 1] = button
    end

    local tabs = {
        { label = "Character", enabled = true },
        { label = "Reputation", enabled = false },
        { label = "Skills", enabled = false },
    }

    frame.tabs = {}

    for index, definition in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(76, 22)
        tab:SetPoint(
            "RIGHT",
            frame,
            "RIGHT",
            76,
            110 - (index - 1) * 26
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

    frame:SetScript("OnShow", function()
        Module:Refresh()
    end)

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
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

    tinsert(UISpecialFrames, frame:GetName())

    return frame
end

function Module:Initialize()
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
end

Module:Initialize()
