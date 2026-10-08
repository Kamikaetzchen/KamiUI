local UI = KamiUI
local Palette = UI.Palette
local Components = UI.Components

local Module = UI:NewModule("Bank", "KamiUI_Bags")

local SLOT_SIZE = 36
local SLOT_SPACING = 3
local COLUMNS = 10
local FRAME_PADDING = 10
local HEADER_HEIGHT = 28
local FOOTER_HEIGHT = 24
local BAG_BAR_HEIGHT = 42

local bankOpen = false
local bankInitialized = true
local pendingRefresh = false
local sortingBank = false

local function HasInitializedBank()
    if not C_Bank
        or not C_Bank.FetchNumPurchasedBankTabs
        or not Enum
        or not Enum.BankType
    then
        return true
    end

    return C_Bank.FetchNumPurchasedBankTabs(
        Enum.BankType.Character
    ) > 0
end

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
    return UI:GetViewedCharacterData(
        Module.viewCharacterKey,
        GetDatabase().characters
    )
end

local function GetSortedCharacters()
    return UI:GetSortedCharacterData(GetDatabase().characters)
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
    local search = Module.frame
        and Module.frame.search
        and Module.frame.search:GetText()
        or ""

    Components:SetContainerItemSlotData(
        button,
        bagID,
        slotID,
        {
            borderColor = Palette:GetBagFamilyColor(family),
            search = search,
        }
    )
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

    if self.frame then
        Components:SetContainerSlotHighlight(
            self.frame.activeButtons,
            bagID,
            shown
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
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
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
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText("Buy Bank Slot")

        if C_Bank and C_Bank.FetchNextPurchasableBankTabData
            and Enum and Enum.BankType
        then
            local data = C_Bank.FetchNextPurchasableBankTabData(
                Enum.BankType.Character
            )

            if data and data.tabCost ~= nil then
                local cost = data.tabCost == 0
                    and (FREE or "Free")
                    or UI:FormatMoney(data.tabCost)

                GameTooltip:AddLine(
                    "Cost: " .. cost,
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
        local canPurchase = maxTabs > purchasedCount
            and (
                not C_Bank.CanPurchaseBankTab
                or C_Bank.CanPurchaseBankTab(Enum.BankType.Character)
            )

        if canPurchase then
            purchaseCount = 1

            local button = frame.purchaseButtons[1]

            if not button then
                button = CreateBankPurchaseButton(frame.bagBar)
                frame.purchaseButtons[1] = button
            end

            button:ClearAllPoints()
            button:SetPoint(
                "LEFT",
                frame.bagBar,
                "LEFT",
                #tabs * 35,
                0
            )
            button:Show()
        end
    end

    for index = purchaseCount + 1, #frame.purchaseButtons do
        frame.purchaseButtons[index]:Hide()
    end
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

    local gridWidth, gridHeight = Components:LayoutItemGrid(
        buttons,
        frame.content,
        {
            columns = COLUMNS,
            slotSize = SLOT_SIZE,
            spacing = SLOT_SPACING,
        }
    )

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
                        button = Components:CreateItemDisplayButton(frame.content, {
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
    local frame, header = Components:CreateWindow("KamiUIBankFrame", {
        backgroundColor = Palette.window.bank,
        borderColor = Palette.windowBorder.bank,
        onDragStop = function(target)
            UI:SaveFramePosition(target, GetDatabase(), "bankPosition")
        end,
        header = {
            height = HEADER_HEIGHT,
            title = UI:GetCurrentCharacterName() .. "'s Bank",
        },
    })

    local title = header.Title
    frame.title = title

    local searchControl = Components:AttachHeaderSearch(frame, header, {
        onTextChanged = function()
            Module:Rebuild()
        end,
    })

    local close = Components:CreateWindowCloseButton(header, {
        onClick = function()
            Module:Hide()
        end,
    })
    frame.close = close

    local characterDropdown =
        Components:CreateCharacterDropdown(
            frame,
            {
                buttonParent = header,
                buttonWidth = 20,
                buttonHeight = 20,
                styleButton = false,
                direction = "down",
                align = "left",
                menuParent = frame,
                backgroundColor = { 0.02, 0.08, 0.02, 0.95 },
                borderColor = Palette.windowBorder.bank,
                fontSize = 9,
                heightPadding = 6,
                minHeight = 26,
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

    local characterButton = characterDropdown.button
    characterButton:SetPoint(
        "TOPLEFT",
        header,
        "TOPLEFT",
        5,
        -3
    )
    frame.characterButton = characterButton
    frame.characterMenu = characterDropdown.menu
    frame.characterDropdown = characterDropdown

    characterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
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


    frame:SetScript("OnHide", function()
        if bankOpen then
            SaveCurrentBank()
        end

        Module.viewCharacterKey = nil
        GameTooltip:Hide()

        if bankOpen
            and C_Bank
            and C_Bank.CloseBankFrame
        then
            C_Bank.CloseBankFrame()
        end
    end)

    Components:RegisterEscapeClose(frame)

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
    if self.frame and self.frame:IsShown() then
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

local function ShowOpenBank()
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
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")
eventFrame:RegisterEvent("BANK_TAB_SETTINGS_UPDATED")
eventFrame:RegisterEvent("BAG_CONTAINER_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        bankInitialized = HasInitializedBank()
        return
    end

    if event == "BANKFRAME_OPENED" then
        bankOpen = true

        if not bankInitialized then
            -- Forever grants CharacterBankTab_1 from Blizzard's normal
            -- BankFrame:SetTab() -> PurchaseFirstSlot() path. Keep that
            -- lifecycle alive, but make the native window invisible.
            UI:SuppressFrame(BankFrame)
            return
        end

        -- Keep Blizzard's bank lifecycle fully intact even after the
        -- initial free tab has been granted. Reparenting BankFrame to a
        -- hidden parent can change effective visibility and trigger its
        -- OnHide path, so the bank always stays visually suppressed only.
        UI:SuppressFrame(BankFrame)
        ShowOpenBank()
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

    if event == "BANK_TABS_CHANGED" and not bankInitialized then
        local bankType = ...

        if bankType == Enum.BankType.Character
            and HasInitializedBank()
        then
            bankInitialized = true

            -- BANK_TABS_CHANGED is synchronous with PurchaseFirstSlot().
            -- Leave BankFrame visually suppressed; never reparent it away
            -- from UIParent because Blizzard's bank lifecycle depends on
            -- its effective visibility.
            if bankOpen then
                ShowOpenBank()
            end

            return
        end
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
