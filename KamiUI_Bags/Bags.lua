local UI = KamiUI

local Module = UI:NewModule("Bags")

Module.name = "KamiUI_Bags"
Module.version = "0.2.0"

local SLOT_SIZE = 36
local SLOT_SPACING = 3
local COLUMNS = 10
local FRAME_PADDING = 10
local HEADER_HEIGHT = 28
local FOOTER_HEIGHT = 24
local BAG_BAR_HEIGHT = 42

local defaults = {
    background = { 0.075, 0.025, 0.11, 0.80 },
    slotBackground = { 0.03, 0.03, 0.03, 0.55 },
    border = { 0.20, 0.16, 0.24, 1.00 },
}

local originalFunctions = {}
local pendingRebuild = false

local function EnsureDatabase()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.bags = KamiUIDB.bags or {}

    local db = KamiUIDB.bags

    if db.bagBarExpanded == nil then
        db.bagBarExpanded = false
    end

    return db
end

local function GetContainerNumSlots(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end

    if _G.GetContainerNumSlots then
        return _G.GetContainerNumSlots(bagID) or 0
    end

    return 0
end

local function GetContainerItemInfo(bagID, slotID)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bagID, slotID)
    end

    return nil
end

local function AddUniqueBag(bags, seen, bagID)
    if bagID == nil or seen[bagID] then
        return
    end

    seen[bagID] = true
    bags[#bags + 1] = bagID
end

local function GetInventoryBags()
    local bags = {}
    local seen = {}

    AddUniqueBag(bags, seen, BACKPACK_CONTAINER or 0)

    local normalBagCount = NUM_BAG_SLOTS or 4

    for bagID = 1, normalBagCount do
        AddUniqueBag(bags, seen, bagID)
    end

    local reagentBag

    if Enum and Enum.BagIndex then
        reagentBag = Enum.BagIndex.ReagentBag
    end

    if reagentBag == nil
        and NUM_REAGENTBAG_SLOTS
        and NUM_REAGENTBAG_SLOTS > 0
    then
        reagentBag = normalBagCount + 1
    end

    if reagentBag ~= nil and GetContainerNumSlots(reagentBag) > 0 then
        AddUniqueBag(bags, seen, reagentBag)
    end

    local keyring = KEYRING_CONTAINER

    if keyring == nil and Enum and Enum.BagIndex then
        keyring = Enum.BagIndex.Keyring
    end

    if keyring ~= nil and GetContainerNumSlots(keyring) > 0 then
        AddUniqueBag(bags, seen, keyring)
    end

    return bags
end

local function GetBagInventoryID(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(bagID)
    end

    if ContainerIDToInventoryID then
        return ContainerIDToInventoryID(bagID)
    end
end

local function CreateBackdrop(frame, color)
    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetAllPoints()
    backdrop:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(unpack(color or defaults.background))
    backdrop:SetBackdropBorderColor(unpack(defaults.border))
    backdrop:EnableMouse(false)

    return backdrop
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
        frame:SetPoint("CENTER", UIParent, "CENTER", 280, 0)
    end
end

local function StyleItemButton(button)
    if button.KamiStyled then
        return
    end

    button.KamiStyled = true
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    if button.NormalTexture then
        button.NormalTexture:SetAlpha(0)
    end

    if button.SetNormalTexture then
        button:SetNormalTexture(nil)
    end

    if button.IconBorder then
        button.IconBorder:SetAlpha(0)
    end

    if button.NewItemTexture then
        button.NewItemTexture:SetAlpha(0)
    end

    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:SetAlpha(0)
    end

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(defaults.slotBackground))
    button.KamiBackground = background

    local icon = button.icon or button.Icon

    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    local highlight = button:GetHighlightTexture()

    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.12)
        highlight:SetAllPoints()
    end

    if button.Count then
        button.Count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end
end

local function UpdateItemButton(button, bagID, slotID)
    button:SetID(slotID)

    if ContainerFrameItemButton_Update then
        ContainerFrameItemButton_Update(button)
    end

    local info = GetContainerItemInfo(bagID, slotID)
    local icon = button.icon or button.Icon

    if not info and icon then
        icon:SetTexture(nil)
    end
end

local function CreateBagCarrier(content, bagID)
    local carrier = CreateFrame("Frame", nil, content)
    carrier:SetAllPoints(content)
    carrier:SetID(bagID)
    carrier:Show()

    return carrier
end

local function CreateItemButton(content, carrier)
    local button = CreateFrame(
        "ItemButton",
        nil,
        carrier,
        "ContainerFrameItemButtonTemplate"
    )

    button:UnregisterAllEvents()
    StyleItemButton(button)

    return button
end

local function GetBagButtonTexture(bagID)
    if bagID == (BACKPACK_CONTAINER or 0) then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end

    local inventoryID = GetBagInventoryID(bagID)

    if inventoryID then
        return GetInventoryItemTexture("player", inventoryID)
    end
end

local function GetBagName(bagID)
    if bagID == (BACKPACK_CONTAINER or 0) then
        return BACKPACK_TOOLTIP or "Backpack"
    end

    if C_Container and C_Container.GetBagName then
        local name = C_Container.GetBagName(bagID)

        if name then
            return name
        end
    end

    local keyring = KEYRING_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

    if bagID == keyring then
        return KEYRING or "Keyring"
    end

    return "Bag " .. tostring(bagID)
end

local function CountFreeSlots(bagID)
    local slots = GetContainerNumSlots(bagID)
    local free = 0

    for slotID = 1, slots do
        if not GetContainerItemInfo(bagID, slotID) then
            free = free + 1
        end
    end

    return free
end

local function CreateBagBarButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(defaults.slotBackground))

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.count = count

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.12)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")

        local inventoryID = GetBagInventoryID(self.bagID)

        if inventoryID and GameTooltip:SetInventoryItem("player", inventoryID) then
            return
        end

        GameTooltip:SetText(GetBagName(self.bagID))
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function FormatMoney(copper)
    copper = copper or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100

    return string.format("%dg %ds %dc", gold, silver, bronze)
end

function Module:UpdateBagBar()
    local frame = self.frame

    if not frame then
        return
    end

    local bags = GetInventoryBags()

    for index, bagID in ipairs(bags) do
        local button = frame.bagBarButtons[index]

        if not button then
            button = CreateBagBarButton(frame.bagBar)
            frame.bagBarButtons[index] = button
        end

        button.bagID = bagID
        button.icon:SetTexture(GetBagButtonTexture(bagID))
        button.count:SetText(CountFreeSlots(bagID))
        button:ClearAllPoints()
        button:SetPoint(
            "LEFT",
            frame.bagBar,
            "LEFT",
            (index - 1) * 35,
            0
        )
        button:Show()
    end

    for index = #bags + 1, #frame.bagBarButtons do
        frame.bagBarButtons[index]:Hide()
    end
end

function Module:UpdateMoney()
    if self.frame and self.frame.money then
        self.frame.money:SetText(FormatMoney(GetMoney()))
    end
end

function Module:UpdateBagBarVisibility()
    local frame = self.frame

    if not frame then
        return
    end

    local expanded = EnsureDatabase().bagBarExpanded

    frame.bagBar:SetShown(expanded)
    frame.bagBarToggle:SetText(expanded and "Bags -" or "Bags +")

    self:Layout()
end

function Module:Layout()
    local frame = self.frame

    if not frame then
        return
    end

    local buttons = frame.itemButtons
    local buttonCount = #buttons
    local rows = math.max(1, math.ceil(buttonCount / COLUMNS))
    local bagBarOffset = EnsureDatabase().bagBarExpanded
        and BAG_BAR_HEIGHT
        or 0

    local contentTop = HEADER_HEIGHT + FRAME_PADDING + bagBarOffset

    frame.content:ClearAllPoints()
    frame.content:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        FRAME_PADDING,
        -contentTop
    )

    for index, button in ipairs(buttons) do
        local column = (index - 1) % COLUMNS
        local row = math.floor((index - 1) / COLUMNS)

        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            frame.content,
            "TOPLEFT",
            column * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )
    end

    local gridWidth = COLUMNS * SLOT_SIZE
        + (COLUMNS - 1) * SLOT_SPACING
    local gridHeight = rows * SLOT_SIZE
        + (rows - 1) * SLOT_SPACING

    frame:SetSize(
        gridWidth + FRAME_PADDING * 2,
        contentTop + gridHeight + FOOTER_HEIGHT + FRAME_PADDING
    )

    frame.content:SetSize(gridWidth, gridHeight)
end

function Module:Rebuild()
    if InCombatLockdown and InCombatLockdown() then
        pendingRebuild = true
        return
    end

    pendingRebuild = false

    local frame = self.frame

    if not frame then
        return
    end

    for _, button in ipairs(frame.itemButtons) do
        button:Hide()
    end

    local activeIndex = 0
    local bags = GetInventoryBags()

    for _, bagID in ipairs(bags) do
        local carrier = frame.bagCarriers[bagID]

        if not carrier then
            carrier = CreateBagCarrier(frame.content, bagID)
            frame.bagCarriers[bagID] = carrier
        end

        carrier:SetID(bagID)

        local slotCount = GetContainerNumSlots(bagID)

        for slotID = 1, slotCount do
            activeIndex = activeIndex + 1

            local button = frame.itemButtons[activeIndex]

            if not button or button:GetParent() ~= carrier then
                button = CreateItemButton(frame.content, carrier)
                frame.itemButtons[activeIndex] = button
            end

            button:Show()
            UpdateItemButton(button, bagID, slotID)
        end
    end

    for index = activeIndex + 1, #frame.itemButtons do
        frame.itemButtons[index]:Hide()
    end

    while #frame.itemButtons > activeIndex do
        frame.itemButtons[#frame.itemButtons] = nil
    end

    self:UpdateBagBar()
    self:UpdateMoney()
    self:Layout()
end

function Module:Refresh()
    local frame = self.frame

    if not frame or not frame:IsShown() then
        return
    end

    self:Rebuild()
end

function Module:Show()
    if not self.frame then
        return
    end

    self:Rebuild()
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

function Module:ResetPosition()
    local db = EnsureDatabase()
    db.position = nil

    if self.frame then
        ApplySavedPosition(self.frame)
    end

    UI:Print("Bag position reset")
end

local function CreateFrameUI()
    local frame = CreateFrame("Frame", "KamiUIBagFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(defaults.background))
    frame:SetBackdropBorderColor(unpack(defaults.border))

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -7)
    title:SetText("Bags")
    title:SetTextColor(0.92, 0.88, 1)
    frame.title = title

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -3)
    close:SetNormalFontObject("GameFontNormal")
    close:SetHighlightFontObject("GameFontHighlight")
    close:SetText("x")
    close:SetScript("OnClick", function()
        Module:Hide()
    end)
    frame.close = close

    local bagBarToggle = CreateFrame("Button", nil, frame)
    bagBarToggle:SetSize(52, 20)
    bagBarToggle:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
    bagBarToggle:SetNormalFontObject("GameFontNormalSmall")
    bagBarToggle:SetHighlightFontObject("GameFontHighlightSmall")
    bagBarToggle:SetScript("OnClick", function()
        local db = EnsureDatabase()
        db.bagBarExpanded = not db.bagBarExpanded
        Module:UpdateBagBarVisibility()
    end)
    frame.bagBarToggle = bagBarToggle

    local bagBar = CreateFrame("Frame", nil, frame)
    bagBar:SetHeight(32)
    bagBar:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -HEADER_HEIGHT - 4)
    bagBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FRAME_PADDING, -HEADER_HEIGHT - 4)
    frame.bagBar = bagBar
    frame.bagBarButtons = {}

    local content = CreateFrame("Frame", nil, frame)
    frame.content = content
    frame.itemButtons = {}
    frame.bagCarriers = {}

    local sort = CreateFrame("Button", nil, frame)
    sort:SetSize(34, 18)
    sort:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FRAME_PADDING, 4)
    sort:SetNormalFontObject("GameFontNormalSmall")
    sort:SetHighlightFontObject("GameFontHighlightSmall")
    sort:SetText("Sort")
    sort:SetScript("OnClick", function()
        if C_Container and C_Container.SortBags then
            C_Container.SortBags()
        elseif SortBags then
            SortBags()
        end
    end)
    frame.sort = sort

    local money = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_PADDING, 8)
    money:SetTextColor(0.85, 0.85, 0.85)
    frame.money = money

    frame:SetScript("OnShow", function()
        Module:Rebuild()
    end)

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
    end)

    ApplySavedPosition(frame)

    tinsert(UISpecialFrames, frame:GetName())

    return frame
end

local function InstallBagHooks()
    if Module.hooksInstalled then
        return
    end

    Module.hooksInstalled = true

    originalFunctions.ToggleAllBags = ToggleAllBags
    originalFunctions.OpenAllBags = OpenAllBags
    originalFunctions.CloseAllBags = CloseAllBags
    originalFunctions.ToggleBackpack = ToggleBackpack
    originalFunctions.ToggleBag = ToggleBag

    ToggleAllBags = function()
        Module:Toggle()
    end

    OpenAllBags = function()
        Module:Show()
    end

    CloseAllBags = function()
        Module:Hide()
    end

    ToggleBackpack = function()
        Module:Toggle()
    end

    ToggleBag = function()
        Module:Toggle()
    end
end

UI:RegisterCommand(
    "bags",
    "reset",
    function()
        Module:ResetPosition()
    end,
    "Reset bag position"
)

function Module:Initialize()
    EnsureDatabase()

    self.frame = CreateFrameUI()

    self:UpdateBagBarVisibility()
    self:Rebuild()

    InstallBagHooks()

    UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("BAG_UPDATE_COOLDOWN", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("ITEM_LOCK_CHANGED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MONEY", function()
        Module:UpdateMoney()
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingRebuild then
            Module:Rebuild()
        end
    end)
end

Module:Initialize()
