local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Bank", "KamiUI_Bags")

local SLOT_SIZE = 36
local SLOT_SPACING = 3
local COLUMNS = 10
local FRAME_PADDING = 10
local HEADER_HEIGHT = 28
local FOOTER_HEIGHT = 24
local BAG_BAR_HEIGHT = 42

local defaults = {
}

local bankOpen = false
local pendingRefresh = false
local sortingBank = false
local hiddenBankParent = CreateFrame("Frame")
hiddenBankParent:Hide()

local BANK_DATABASE_DEFAULTS = {
    characters = {},
    bankHiddenTabs = {},
    bankBagBarExpanded = false,
}

local function GetDatabase()
    return UI:GetDatabase("bags", BANK_DATABASE_DEFAULTS)
end

local BANK_TAB_FALLBACK_ICON = 5524917

local function GetBankTabIcon(data, info)
    if info and info.iconFileID then
        return info.iconFileID
    end

    local icon = data and data.icon

    if icon and icon ~= 134400 then
        return icon
    end

    return BANK_TAB_FALLBACK_ICON
end

local function GetCharacterBankBagIDs()
    local bags = {}

    if not Enum or not Enum.BagIndex then
        return bags
    end

    for index = 1, 9 do
        local bagID = Enum.BagIndex["CharacterBankTab_" .. index]

        if bagID then
            bags[#bags + 1] = {
                bagID = bagID,
                index = index,
            }
        end
    end

    return bags
end

local function GetBankTabs()
    local tabs = {}
    local tabData = {}

    if C_Bank
        and C_Bank.FetchPurchasedBankTabData
        and Enum
        and Enum.BankType
        and Enum.BankType.Character
    then
        tabData = C_Bank.FetchPurchasedBankTabData(
            Enum.BankType.Character
        ) or {}
    end

    local purchasedCount = #tabData
    local bankBagSlots = Enum
        and Enum.BagIndex
        and Enum.BagIndex.Characterbanktab

    for _, entry in ipairs(GetCharacterBankBagIDs()) do
        local bagID = entry.bagID
        local slotCount = UI:GetContainerNumSlots(bagID)
        local data = tabData[entry.index]
        local info

        if bankBagSlots and entry.index > 1 then
            info = UI:GetContainerItemInfo(bankBagSlots, entry.index)
        end

        local purchased = entry.index <= purchasedCount
            or slotCount > 0
            or info ~= nil

        if purchased then
            local _, family = UI:GetContainerNumFreeSlots(bagID)
            local emptyBagSlot = entry.index > 1
                and slotCount == 0
                and info == nil
            local icon = emptyBagSlot
                and "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
                or GetBankTabIcon(data, info)

            tabs[#tabs + 1] = {
                bagID = bagID,
                index = entry.index,
                name = emptyBagSlot
                    and "Empty Bank Bag Slot"
                    or (data and data.name)
                    or (entry.index == 1
                        and "Bank"
                        or "Bank Bag " .. entry.index - 1),
                icon = icon,
                family = family or 0,
                slotCount = slotCount,
                emptyBagSlot = emptyBagSlot,
            }
        end
    end

    return tabs
end

local function SaveCurrentBank()
    if not bankOpen then
        return
    end

    local db = GetDatabase()
    local key = UI:GetCurrentCharacterKey()
    local characters = UI:GetCharactersModule()

    if characters and characters.UpdateCurrentCharacter then
        characters:UpdateCurrentCharacter()
    end

    local character = db.characters[key] or {}

    character.bankItems = {}
    character.bank = {
        tabs = {},
        updated = time and time() or 0,
    }

    for _, tab in ipairs(GetBankTabs()) do
        local savedTab = {
            bagID = tab.bagID,
            index = tab.index,
            name = tab.name,
            icon = tab.icon,
            family = tab.family,
            slotCount = tab.slotCount,
            slots = {},
        }

        for slotID = 1, tab.slotCount do
            local info = UI:GetContainerItemInfo(tab.bagID, slotID)

            if info then
                local itemName

                if info.hyperlink and GetItemInfo then
                    itemName = GetItemInfo(info.hyperlink)
                end

                savedTab.slots[slotID] = {
                    itemID = info.itemID,
                    link = info.hyperlink,
                    icon = info.iconFileID,
                    count = info.stackCount or 1,
                    quality = info.quality,
                    name = itemName,
                }

                if info.itemID then
                    character.bankItems[info.itemID] =
                        (character.bankItems[info.itemID] or 0)
                        + (info.stackCount or 1)
                end
            end
        end

        character.bank.tabs[#character.bank.tabs + 1] = savedTab
    end

    db.characters[key] = character
end

local function GetViewedCharacter()
    local db = GetDatabase()
    local currentKey = UI:GetCurrentCharacterKey()
    local key = Module.viewCharacterKey or currentKey

    return key, db.characters[key], key == currentKey
end

local function GetSortedCharacters()
    local characters = {}

    for key, character in pairs(GetDatabase().characters) do
        characters[#characters + 1] = {
            key = key,
            character = character,
            profile = UI:GetCharacterProfile(key, character),
        }
    end

    return UI:SortCharacterEntries(
        characters,
        function(entry)
            return entry.profile
        end
    )
end

local itemDragFrame = CreateFrame("Frame")
itemDragFrame:Hide()
itemDragFrame:SetScript("OnUpdate", function(self)
    if IsMouseButtonDown("LeftButton") then
        return
    end

    self:Hide()

    if not CursorHasItem or not CursorHasItem() then
        return
    end

    local frame = Module.frame

    if not frame or not frame:IsShown() then
        return
    end

    local _, _, isCurrent = GetViewedCharacter()

    if not isCurrent then
        return
    end

    local cursorX, cursorY = GetCursorPosition()

    for _, button in ipairs(frame.activeButtons or {}) do
        if button:IsShown() and button:GetParent():IsShown() then
            local scale = button:GetEffectiveScale()
            local x = cursorX / scale
            local y = cursorY / scale
            local left, bottom, width, height = button:GetRect()

            if left
                and bottom
                and x >= left
                and x <= left + width
                and y >= bottom
                and y <= bottom + height
            then
                local bagID = button.GetBagID
                    and button:GetBagID()
                    or button:GetParent():GetID()
                local slotID = button:GetID()

                C_Container.PickupContainerItem(bagID, slotID)
                return
            end
        end
    end

    local bagFrame = _G.KamiUIBagFrame

    if bagFrame
        and bagFrame:IsShown()
        and bagFrame.liveInventory
    then
        for _, button in ipairs(bagFrame.activeButtons or {}) do
            if button:IsShown() and button:GetParent():IsShown() then
                local scale = button:GetEffectiveScale()
                local x = cursorX / scale
                local y = cursorY / scale
                local left, bottom, width, height = button:GetRect()

                if left
                    and bottom
                    and x >= left
                    and x <= left + width
                    and y >= bottom
                    and y <= bottom + height
                then
                    local bagID = button.GetBagID
                        and button:GetBagID()
                        or button:GetParent():GetID()
                    local slotID = button:GetID()

                    C_Container.PickupContainerItem(bagID, slotID)
                    return
                end
            end
        end
    end
end)

local function UpdateItemButton(button, bagID, slotID, family)
    if button.SetBagID then
        button:SetBagID(bagID)
    elseif button.SetAttribute then
        button:SetAttribute("bagid", bagID)
    end

    button:SetID(slotID)

    local color = Palette:GetBagFamilyColor(family)

    Components:SetItemSlotBorderColor(button, color)

    if ContainerFrameItemButton_Update then
        ContainerFrameItemButton_Update(button)
    end

    Components:SuppressItemButtonFlash(button)

    local info = UI:GetContainerItemInfo(bagID, slotID)
    local icon = button.icon or button.Icon

    if info then
        Components:SetItemSlotQuality(button, info.quality)

        local search = Module.frame
            and Module.frame.search
            and Module.frame.search:GetText()
            or ""
        local filtered = false

        if search ~= "" then
            local itemName

            if info.hyperlink and GetItemInfo then
                itemName = GetItemInfo(info.hyperlink)
            end

            local haystack = string.lower(itemName or info.hyperlink or "")
            filtered = not string.find(
                haystack,
                string.lower(search),
                1,
                true
            )
        end

        local alpha = filtered and 0.20 or 1.00
        button:SetAlpha(alpha)

        if icon then
            icon:SetTexture(info.iconFileID)
            icon:SetAlpha(alpha)
        end

        if button.Count then
            local count = info.stackCount or 1
            button.Count:SetText(count > 1 and count or "")
            button.Count:SetAlpha(alpha)
            button.Count:Show()
        end
    else
        Components:SetItemSlotQuality(button, nil)
        button:SetAlpha(1)

        if icon then
            icon:SetTexture(nil)
            icon:SetAlpha(1)
        end

        if button.Count then
            button.Count:SetText("")
            button.Count:SetAlpha(1)
        end
    end
end

local function UpdateCachedItemButton(button, slot, tab)
    button.bagID = tab.bagID

    local borderColor = Palette:GetBagFamilyColor(tab.family)
    local search = Module.frame
        and Module.frame.search
        and Module.frame.search:GetText()
        or ""
    local alpha = 1

    if slot and search ~= "" then
        local haystack = string.lower(slot.name or slot.link or "")

        if not string.find(
            haystack,
            string.lower(search),
            1,
            true
        ) then
            alpha = 0.20
        end
    end

    Components:SetItemSlotData(button, {
        link = slot and slot.link or nil,
        icon = slot and slot.icon or nil,
        count = slot and slot.count or 0,
        quality = slot and slot.quality or nil,
        borderColor = borderColor,
        alpha = alpha,
    })
end

function Module:SetBagSlotHighlight(bagID, shown)
    self.highlightedBagID = shown and bagID or nil

    local frame = self.frame

    if not frame then
        return
    end

    for _, button in ipairs(frame.activeButtons or {}) do
        if not button.KamiBagHighlight then
            local highlight = button:CreateTexture(nil, "ARTWORK", nil, 7)
            highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            highlight:SetColorTexture(1, 1, 1, 0.14)
            highlight:Hide()
            button.KamiBagHighlight = highlight
        end

        local buttonBagID = button.GetBagID
            and button:GetBagID()
            or button.bagID

        button.KamiBagHighlight:SetShown(
            shown and buttonBagID == bagID
        )
    end
end

local function CreateBankBagButton(parent)
    local button = Components:CreateItemSlot(parent, {
        size = 32,
        count = true,
        countFontSize = 9,
        rarityGlow = false,
        border = false,
    })

    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local function PickupBankBag(self)
        if self.isCached or self.tabIndex == 1 then
            return
        end

        local bankBagSlots = Enum
            and Enum.BagIndex
            and Enum.BagIndex.Characterbanktab

        if bankBagSlots then
            C_Container.PickupContainerItem(bankBagSlots, self.tabIndex)
        end
    end

    button:SetScript("OnClick", function(self)
        if CursorHasItem and CursorHasItem() and not self.isCached then
            PickupBankBag(self)
            return
        end

        local db = GetDatabase()
        db.bankHiddenTabs[self.bagID] = not db.bankHiddenTabs[self.bagID]
        Module:Rebuild()
    end)

    button:SetScript("OnDragStart", PickupBankBag)
    button:SetScript("OnReceiveDrag", PickupBankBag)

    button:SetScript("OnEnter", function(self)
        Module:SetBagSlotHighlight(self.bagID, true)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tabName or "Bank")

        if self.emptyBagSlot then
            GameTooltip:AddLine("Drag a bag here", 0.75, 0.75, 0.75)
        else
            GameTooltip:AddLine(
                "Click: show/hide bank bag",
                0.75,
                0.75,
                0.75
            )

            if not self.isCached and self.tabIndex and self.tabIndex > 1 then
                GameTooltip:AddLine(
                    "Drag: equip/swap bank bag",
                    0.75,
                    0.75,
                    0.75
                )
            end
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        Module:SetBagSlotHighlight(self.bagID, false)
        GameTooltip:Hide()
    end)

    return button
end

local function CreateBankPurchaseButton(parent)
    local button = CreateFrame(
        "Button",
        nil,
        parent,
        "BankPanelPurchaseButtonScriptTemplate"
    )
    button:SetSize(32, 32)
    button:SetAttribute(
        "overrideBankType",
        Enum and Enum.BankType and Enum.BankType.Character
    )

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(Palette.slot))
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetDesaturated(true)
    icon:SetAlpha(0.45)
    button.icon = icon

    local plus = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    plus:SetPoint("CENTER", 0, 0)
    plus:SetText("+")
    plus:SetTextColor(1, 0.82, 0, 0.95)
    button.plus = plus

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.12)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Buy Bank Slot")

        if C_Bank and C_Bank.FetchNextPurchasableBankTabData
            and Enum and Enum.BankType
        then
            local data = C_Bank.FetchNextPurchasableBankTabData(
                Enum.BankType.Character
            )

            if data and data.tabCost then
                GameTooltip:AddLine(
                    "Cost: " .. UI:FormatMoney(data.tabCost),
                    1,
                    1,
                    1
                )
            end
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

function Module:UpdateBagBar()
    local frame = self.frame

    if not frame then
        return
    end

    local _, character, isCurrent = GetViewedCharacter()
    local tabs = {}

    if isCurrent and bankOpen then
        tabs = GetBankTabs()
    elseif character and character.bank then
        tabs = character.bank.tabs or {}
    end

    for index, tab in ipairs(tabs) do
        local button = frame.bagBarButtons[index]

        if not button then
            button = CreateBankBagButton(frame.bagBar)
            frame.bagBarButtons[index] = button
        end

        button.bagID = tab.bagID
        button.tabIndex = tab.index or index
        button.tabName = tab.name
        button.isCached = not (isCurrent and bankOpen)
        button.emptyBagSlot = tab.emptyBagSlot == true
        button.icon:SetTexture(tab.icon)

        local free

        if isCurrent and bankOpen then
            free = UI:CountContainerFreeSlots(tab.bagID)
        else
            local used = 0

            for slotID = 1, tab.slotCount or 0 do
                if tab.slots and tab.slots[slotID] then
                    used = used + 1
                end
            end

            free = math.max(0, (tab.slotCount or 0) - used)
        end

        button.count:SetText(tab.emptyBagSlot and "" or free)

        local hidden = GetDatabase().bankHiddenTabs[tab.bagID] == true
        button.icon:SetAlpha(hidden and 0.30 or 1.00)
        button.count:SetAlpha(hidden and 0.30 or 1.00)
        button.background:SetAlpha(hidden and 0.35 or 1.00)

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

    for index = #tabs + 1, #frame.bagBarButtons do
        frame.bagBarButtons[index]:Hide()
    end

    frame.purchaseButtons = frame.purchaseButtons or {}

    local purchaseCount = 0

    if isCurrent
        and bankOpen
        and C_Bank
        and C_Bank.FetchMaxNumBankTabs
        and C_Bank.FetchPurchasedBankTabData
        and Enum
        and Enum.BankType
    then
        local maxTabs = C_Bank.FetchMaxNumBankTabs(
            Enum.BankType.Character
        ) or 0
        local purchased = C_Bank.FetchPurchasedBankTabData(
            Enum.BankType.Character
        ) or {}
        local purchasedCount = #purchased

        for index = purchasedCount + 1, maxTabs do
            purchaseCount = purchaseCount + 1

            local button = frame.purchaseButtons[purchaseCount]

            if not button then
                button = CreateBankPurchaseButton(frame.bagBar)
                frame.purchaseButtons[purchaseCount] = button
            end

            button:ClearAllPoints()
            button:SetPoint(
                "LEFT",
                frame.bagBar,
                "LEFT",
                (#tabs + purchaseCount - 1) * 35,
                0
            )
            button:Show()
        end
    end

    for index = purchaseCount + 1, #frame.purchaseButtons do
        frame.purchaseButtons[index]:Hide()
    end
end

function Module:UpdateMoney()
    if not self.frame or not self.frame.money then
        return
    end

    local key, character, isCurrent = GetViewedCharacter()
    local profile = UI:GetCharacterProfile(key, character)
    local money = isCurrent and GetMoney()
        or profile.money
        or 0

    self.frame.money:SetText(UI:FormatMoney(money))
end

function Module:UpdateTitle()
    if not self.frame or not self.frame.title then
        return
    end

    local key, character = GetViewedCharacter()
    local profile = UI:GetCharacterProfile(key, character)
    local name = Components:FormatCharacterLabel(
        profile,
        { showRealm = false }
    )

    self.frame.title:SetText(name .. "'s Bank")
end

function Module:Layout()
    local frame = self.frame

    if not frame then
        return
    end

    local buttons = frame.activeButtons or {}
    local rows = math.max(1, math.ceil(#buttons / COLUMNS))
    local bagBarOffset = GetDatabase().bankBagBarExpanded
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

function Module:UpdateBagBarVisibility()
    local frame = self.frame

    if not frame then
        return
    end

    local expanded = GetDatabase().bankBagBarExpanded

    frame.bagBar:SetShown(expanded)
    frame.bagBarToggle:SetText(expanded and "Bags -" or "Bags +")

    self:Layout()
end

function Module:SetViewedCharacter(key)
    local currentKey = UI:GetCurrentCharacterKey()

    self.viewCharacterKey = key == currentKey and nil or key

    if self.frame and self.frame.characterMenu then
        self.frame.characterMenu:Hide()
    end

    self:Rebuild()
end

function Module:Rebuild()
    local frame = self.frame

    if not frame or not frame:IsShown() then
        return
    end

    for _, button in ipairs(frame.itemButtons) do
        button:Hide()
    end

    for _, button in ipairs(frame.cachedButtons) do
        button:Hide()
    end

    local _, character, isCurrent = GetViewedCharacter()
    local active = {}
    local index = 0

    if not isCurrent or not bankOpen then
        frame.liveBankAccess = false
        local tabs = character
            and character.bank
            and character.bank.tabs
            or {}

        for _, tab in ipairs(tabs) do
            if not GetDatabase().bankHiddenTabs[tab.bagID] then
                for slotID = 1, tab.slotCount or 0 do
                    index = index + 1

                    local button = frame.cachedButtons[index]

                    if not button then
                        button = Components:CreateCachedItemButton(frame.content, {
                size = SLOT_SIZE,
                corners = true,
            })
                        frame.cachedButtons[index] = button
                    end

                    UpdateCachedItemButton(
                        button,
                        tab.slots and tab.slots[slotID],
                        tab
                    )
                    button:Show()
                    active[#active + 1] = button
                end
            end
        end

        frame.activeButtons = active
        frame.liveBankAccess = false

        if self.highlightedBagID then
            self:SetBagSlotHighlight(self.highlightedBagID, true)
        end
        frame.sort:Hide()
        frame.bagBarToggle:Show()
        self:UpdateBagBar()
        self:UpdateMoney()
        self:UpdateTitle()
        self:UpdateBagBarVisibility()
        return
    end

    frame.liveBankAccess = true

    for _, tab in ipairs(GetBankTabs()) do
        if not GetDatabase().bankHiddenTabs[tab.bagID] then
            local carrier = frame.carriers[tab.bagID]

            if not carrier then
                carrier = Components:CreateCarrier(frame.content, tab.bagID)
                frame.carriers[tab.bagID] = carrier
            end

            carrier:SetID(tab.bagID)

            for slotID = 1, tab.slotCount do
                index = index + 1

                local button = frame.itemButtons[index]

                if not button or button:GetParent() ~= carrier then
                    button = Components:CreateContainerItemButton(
                        carrier,
                        {
                            size = SLOT_SIZE,
                            corners = true,
                            onDragStart = function()
                                itemDragFrame:Show()
                            end,
                        }
                    )
                    frame.itemButtons[index] = button
                end

                button:Show()
                UpdateItemButton(button, tab.bagID, slotID, tab.family)
                active[#active + 1] = button
            end
        end
    end

    for i = index + 1, #frame.itemButtons do
        frame.itemButtons[i]:Hide()
    end

    frame.activeButtons = active
    frame.liveBankAccess = true

    if self.highlightedBagID then
        self:SetBagSlotHighlight(self.highlightedBagID, true)
    end
    frame.sort:Show()
    frame.bagBarToggle:Show()
    self:UpdateBagBar()
    self:UpdateMoney()
    self:UpdateTitle()
    self:UpdateBagBarVisibility()
end

local function ScheduleRefresh()
    if pendingRefresh then
        return
    end

    pendingRefresh = true

    C_Timer.After(0.10, function()
        pendingRefresh = false

        if not bankOpen or sortingBank then
            return
        end

        SaveCurrentBank()
        Module:Rebuild()
    end)
end

local function CreateFrameUI()
    local frame = CreateFrame(
        "Frame",
        "KamiUIBankFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    Styles:ApplyBackdrop(
        frame,
        Palette.window.bank,
        Palette.windowBorder.bank
    )

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SaveFramePosition(self, GetDatabase(), "bankPosition")
    end)

    local header = Components:CreateWindowHeader(frame, {
        height = HEADER_HEIGHT,
        title = UI:GetCurrentCharacterName() .. "'s Bank",
        draggable = true,
        onDragStop = function()
            UI:SaveFramePosition(frame, GetDatabase(), "bankPosition")
        end,
    })
    frame.header = header

    local title = header.Title
    frame.title = title

    local titleButton = CreateFrame("Button", nil, header)
    titleButton:SetPoint("TOPLEFT", header, "TOPLEFT", 90, -1)
    titleButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -90, -1)
    titleButton:SetHeight(24)
    titleButton:RegisterForDrag("LeftButton")
    titleButton:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleButton:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        UI:SaveFramePosition(frame, GetDatabase(), "bankPosition")
    end)
    frame.titleButton = titleButton

    local search = CreateFrame("EditBox", nil, header, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", titleButton, "TOPLEFT", 0, -1)
    search:SetPoint("TOPRIGHT", titleButton, "TOPRIGHT", 0, -1)
    search:SetHeight(22)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)
    search:Hide()
    frame.search = search

    local function CloseSearch(clear)
        if clear then
            search:SetText("")
            Module:Rebuild()
        end

        search:ClearFocus()
        search:Hide()
        title:Show()
    end

    titleButton:SetScript("OnDoubleClick", function()
        title:Hide()
        search:Show()
        search:SetFocus()
        search:HighlightText()
    end)

    search:SetScript("OnTextChanged", function()
        Module:Rebuild()
    end)
    search:SetScript("OnEscapePressed", function()
        CloseSearch(true)
    end)
    search:SetScript("OnEnterPressed", function()
        CloseSearch(false)
    end)

    local close = CreateFrame("Button", nil, header)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -3, -2)
    Components:StyleButton(close, { text = "X" })
    close:SetScript("OnClick", function()
        Module:Hide()
    end)
    frame.close = close

    local characterButton = CreateFrame("Button", nil, header)
    characterButton:SetSize(20, 20)
    characterButton:SetPoint("TOPLEFT", header, "TOPLEFT", 5, -3)

    local characterIcon = characterButton:CreateTexture(nil, "ARTWORK")
    characterIcon:SetAllPoints()
    characterIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    frame.characterButton = characterButton

    local characterMenu = Components:CreatePopupMenu(
        frame,
        characterButton,
        {
            backgroundColor = { 0.02, 0.08, 0.02, 0.95 },
            borderColor = Palette.windowBorder.bank,
            fontSize = 9,
            heightPadding = 6,
            minHeight = 26,
        }
    )
    frame.characterMenu = characterMenu

    Components:BindCharacterMenu(
        characterButton,
        characterMenu,
        {
            getEntries = GetSortedCharacters,
            getCharacter = function(entry)
                return entry.profile
            end,
            filter = function(entry)
                return entry.character
                    and entry.character.bank ~= nil
            end,
            selectedKey = function()
                return select(1, GetViewedCharacter())
            end,
            onSelect = function(key)
                Module:SetViewedCharacter(key)
            end,
        }
    )

    characterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Characters")
        GameTooltip:Show()
    end)
    characterButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local bagBarToggle = CreateFrame("Button", nil, header)
    bagBarToggle:SetSize(52, 20)
    bagBarToggle:SetPoint("LEFT", characterButton, "RIGHT", 4, 0)
    bagBarToggle:SetNormalFontObject("GameFontNormalSmall")
    bagBarToggle:SetHighlightFontObject("GameFontHighlightSmall")
    bagBarToggle:SetText("Bags +")
    Components:StyleButton(bagBarToggle)
    bagBarToggle:SetScript("OnClick", function()
        local db = GetDatabase()
        db.bankBagBarExpanded = not db.bankBagBarExpanded
        Module:UpdateBagBarVisibility()
    end)
    frame.bagBarToggle = bagBarToggle

    local bagBar = CreateFrame("Frame", nil, frame)
    bagBar:SetHeight(32)
    bagBar:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        FRAME_PADDING,
        -HEADER_HEIGHT - 4
    )
    bagBar:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        -FRAME_PADDING,
        -HEADER_HEIGHT - 4
    )
    frame.bagBar = bagBar
    frame.bagBarButtons = {}

    local content = CreateFrame("Frame", nil, frame)
    frame.content = content
    frame.itemButtons = {}
    frame.cachedButtons = {}
    frame.activeButtons = {}
    frame.carriers = {}

    local sort = CreateFrame("Button", nil, frame)
    sort:SetSize(34, 18)
    sort:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FRAME_PADDING, 4)
    sort:SetNormalFontObject("GameFontNormalSmall")
    sort:SetHighlightFontObject("GameFontHighlightSmall")
    sort:SetText("Sort")
    Components:StyleButton(sort)
    sort:SetScript("OnClick", function()
        if sortingBank then
            return
        end

        sortingBank = true
        _G.KamiUIBankSortInProgress = true
        sort:Disable()

        if C_Container and C_Container.SortBank
            and Enum and Enum.BankType
        then
            C_Container.SortBank(Enum.BankType.Character)
        elseif C_Container and C_Container.SortBankBags then
            C_Container.SortBankBags()
        elseif SortBankBags then
            SortBankBags()
        end

        C_Timer.After(0.75, function()
            sortingBank = false
            _G.KamiUIBankSortInProgress = false
            sort:Enable()

            if bankOpen then
                SaveCurrentBank()
                Module:Rebuild()
            end
        end)
    end)
    frame.sort = sort

    local money = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_PADDING, 8)
    money:SetTextColor(0.85, 0.85, 0.85)
    frame.money = money

    local moneyButton = CreateFrame("Button", nil, frame)
    moneyButton:SetPoint("TOPLEFT", money, "TOPLEFT", -4, 4)
    moneyButton:SetPoint("BOTTOMRIGHT", money, "BOTTOMRIGHT", 4, -4)

    moneyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Money")

        local total = 0

        for _, entry in ipairs(UI:GetSortedCharacterProfiles(GetDatabase().characters)) do
            local character = entry.character
            local amount = character.money or 0
            local color = Palette:GetClassColor(character.classFile)
            local r = color and color.r or 0.75
            local g = color and color.g or 0.75
            local b = color and color.b or 0.75

            total = total + amount

            GameTooltip:AddDoubleLine(
                character.name or "Unknown",
                UI:FormatMoney(amount),
                r,
                g,
                b,
                1,
                1,
                1
            )
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(
            "Total",
            UI:FormatMoney(total),
            1,
            0.82,
            0,
            1,
            1,
            1
        )
        GameTooltip:Show()
    end)
    moneyButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame:EnableKeyboard(true)

    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
    end

    frame:SetScript("OnKeyDown", function(self, key)
        if key ~= "ESCAPE" then
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(true)
            end
            return
        end

        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end

        if search:IsShown() then
            CloseSearch(true)
        else
            Module:Hide()
        end
    end)

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
    end)

    UI:ApplyFramePosition(frame, GetDatabase(), "bankPosition", -280, 0)

    return frame
end

function Module:Show()
    if not self.frame then
        return
    end

    self.viewCharacterKey = nil
    self.frame:Show()
    SaveCurrentBank()
    self:Rebuild()
end

function Module:Hide()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    if bankOpen then
        SaveCurrentBank()
    end

    self.viewCharacterKey = nil
    self.frame:Hide()

    if bankOpen and C_Bank and C_Bank.CloseBankFrame then
        C_Bank.CloseBankFrame()
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
    GetDatabase().bankPosition = nil

    if self.frame then
        UI:ApplyFramePosition(self.frame, GetDatabase(), "bankPosition", -280, 0)
    end

    UI:Print("Bank position reset")
end

UI:RegisterCommand(
    "bank",
    "reset",
    function()
        Module:ResetPosition()
    end,
    "Reset bank position"
)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")
eventFrame:RegisterEvent("BANK_TAB_SETTINGS_UPDATED")
eventFrame:RegisterEvent("BAG_CONTAINER_UPDATE")
eventFrame:RegisterEvent("PLAYER_MONEY")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then
        bankOpen = true

        if BankFrame then
            BankFrame:SetParent(hiddenBankParent)
        end

        Module:Show()

        local bagsModule = UI.GetModule and UI:GetModule("Bags")

        if bagsModule
            and bagsModule.frame
            and not bagsModule.frame:IsShown()
        then
            bagsModule:Show()
        elseif _G.KamiUIBagFrame and not _G.KamiUIBagFrame:IsShown() then
            if OpenAllBags then
                OpenAllBags()
            end
        end

        return
    end

    if event == "BANKFRAME_CLOSED" then
        bankOpen = false
        Module.viewCharacterKey = nil

        if Module.frame then
            Module.frame:Hide()
        end

        return
    end

    if event == "PLAYER_MONEY" then
        if Module.frame and Module.frame:IsShown() then
            Module:UpdateMoney()
        end
        return
    end

    if bankOpen and not sortingBank then
        ScheduleRefresh()
    end
end)

function Module:Initialize()
    GetDatabase()
    self.frame = CreateFrameUI()

    local hotkeyButton = CreateFrame("Button", "KamiUIBankHotkeyButton", UIParent)
    hotkeyButton:SetScript("OnClick", function()
        Module:Toggle()
    end)
    self.hotkeyButton = hotkeyButton

    if SetOverrideBindingClick then
        SetOverrideBindingClick(
            hotkeyButton,
            true,
            "SHIFT-B",
            "KamiUIBankHotkeyButton",
            "LeftButton"
        )
    end
end

Module:Initialize()
