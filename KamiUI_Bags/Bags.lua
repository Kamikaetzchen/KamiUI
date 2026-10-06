local UI = KamiUI
local Palette = UI.Palette
local Components = UI.Components

local Module = UI:NewModule("Bags", "KamiUI_Bags")

local SLOT_SIZE = 36
local SLOT_SPACING = 3
local COLUMNS = 10
local FRAME_PADDING = 10
local HEADER_HEIGHT = 28
local FOOTER_HEIGHT = 24
local BAG_BAR_HEIGHT = 42

local defaults = {
}

local pendingRebuild = false
local sortingBags = false
local pendingSortRefresh = false

local function TryReceiveDragOnMouseFocus()
    local frames = {}

    if GetMouseFoci then
        frames = { GetMouseFoci() }
    elseif GetMouseFocus then
        local focus = GetMouseFocus()

        if focus then
            frames[1] = focus
        end
    end

    for _, frame in ipairs(frames) do
        local current = frame

        while current do
            if current.GetScript then
                local onReceiveDrag = current:GetScript("OnReceiveDrag")

                if onReceiveDrag then
                    onReceiveDrag(current)

                    if not CursorHasItem or not CursorHasItem() then
                        return true
                    end
                end
            end

            current = current.GetParent and current:GetParent() or nil
        end
    end

    return false
end

local function IsPointInsideFrame(frame, cursorX, cursorY)
    if not frame or not frame:IsShown() then
        return false
    end

    local scale = frame:GetEffectiveScale()
    local x = cursorX / scale
    local y = cursorY / scale
    local left, bottom, width, height = frame:GetRect()

    return left
        and bottom
        and x >= left
        and x <= left + width
        and y >= bottom
        and y <= bottom + height
end

local function TryDropOnSendMail(cursorX, cursorY)
    if not ClickSendMailItemButton
        or not SendMailFrame
        or not SendMailFrame:IsShown()
    then
        return false
    end

    local attachments = SendMailFrame.SendMailAttachments

    if attachments then
        for index, button in ipairs(attachments) do
            if IsPointInsideFrame(button, cursorX, cursorY) then
                ClickSendMailItemButton(index)
                return not CursorHasItem or not CursorHasItem()
            end
        end
    else
        local maxAttachments = ATTACHMENTS_MAX_SEND or 12

        for index = 1, maxAttachments do
            local button = _G["SendMailAttachment" .. index]

            if IsPointInsideFrame(button, cursorX, cursorY) then
                ClickSendMailItemButton(index)
                return not CursorHasItem or not CursorHasItem()
            end
        end
    end

    if IsPointInsideFrame(_G.SendMailPackageButton, cursorX, cursorY) then
        ClickSendMailItemButton()
        return not CursorHasItem or not CursorHasItem()
    end

    return false
end

local function TryDropOnCharacterSlot(cursorX, cursorY)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if not PickupInventoryItem or not UI.GetModule then
        return false
    end

    local characters = UI:GetModule("Characters")

    if not characters or not characters.frame then
        return false
    end

    local characterFrame = characters.frame

    if not characterFrame:IsShown()
        or characterFrame.page ~= "character"
    then
        return false
    end

    for _, button in ipairs(characterFrame.equipmentSlots or {}) do
        if button.slotID
            and IsPointInsideFrame(button, cursorX, cursorY)
        then
            PickupInventoryItem(button.slotID)
            return not CursorHasItem or not CursorHasItem()
        end
    end

    return false
end

local function TryDropOnActionBar(cursorX, cursorY)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if not PlaceAction or not UI.GetModule then
        return false
    end

    local actionBars = UI:GetModule("ActionBars")

    if not actionBars or not actionBars.bars then
        return false
    end

    for _, bar in pairs(actionBars.bars) do
        for _, button in ipairs(bar.buttons or {}) do
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
                    local action = button:GetAttribute("action")

                    if type(action) == "number" then
                        PlaceAction(action)
                        return true
                    end
                end
            end
        end
    end

    return false
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

    local cursorX, cursorY = GetCursorPosition()

    if TryDropOnSendMail(cursorX, cursorY) then
        return
    end

    if TryDropOnCharacterSlot(cursorX, cursorY) then
        return
    end

    if TryDropOnActionBar(cursorX, cursorY) then
        return
    end

    if TryReceiveDragOnMouseFocus() then
        return
    end

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

                if C_Container and C_Container.PickupContainerItem then
                    C_Container.PickupContainerItem(bagID, slotID)
                elseif PickupContainerItem then
                    PickupContainerItem(bagID, slotID)
                end

                return
            end
        end
    end

    local bankFrame = _G.KamiUIBankFrame

    if bankFrame
        and bankFrame:IsShown()
        and bankFrame.liveBankAccess
    then
        for _, button in ipairs(bankFrame.activeButtons or {}) do
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

local BAG_DATABASE_DEFAULTS = {
    bagBarExpanded = false,
    hiddenBags = {},
    characters = {},
}

local function GetDatabase()
    return UI:GetDatabase("bags", BAG_DATABASE_DEFAULTS)
end

local function CleanupLegacyCharacterMetadata()
    if not UI:GetCharactersModule() then
        return
    end

    for _, character in pairs(GetDatabase().characters) do
        character.name = nil
        character.firstName = nil
        character.surname = nil
        character.classFile = nil
        character.realm = nil
        character.money = nil
    end
end

local function GetBagFamilyColor(bagID)
    local keyring = KEYRING_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

    if bagID == keyring then
        return Palette.bagFamily.keyring
    end

    local inventoryID = UI:GetBagInventoryID(bagID)

    if inventoryID then
        local link = GetInventoryItemLink("player", inventoryID)

        if link and GetItemInfoInstant then
            local _, _, _, _, _, classID, subClassID =
                GetItemInfoInstant(link)

            if classID == 11 then
                if subClassID == 2 then
                    return Palette.bagFamily.arrows
                elseif subClassID == 3 then
                    return Palette.bagFamily.bullets
                end
            elseif classID == 1 then
                if subClassID == 1 then
                    return Palette.bagFamily.soul
                elseif subClassID == 2 then
                    return Palette.bagFamily.herbs
                elseif subClassID == 6 then
                    return Palette.bagFamily.mining
                elseif subClassID == 7 then
                    return Palette.bagFamily.leather
                end
            end
        end
    end

    local _, family = UI:GetContainerNumFreeSlots(bagID)

    return Palette:GetBagFamilyColor(family, false)
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

    local reagentBag = Enum
        and Enum.BagIndex
        and Enum.BagIndex.ReagentBag

    if reagentBag == nil
        and NUM_TOTAL_EQUIPPED_BAG_SLOTS
        and NUM_TOTAL_EQUIPPED_BAG_SLOTS > normalBagCount
    then
        reagentBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS
    end

    if reagentBag == nil
        and NUM_REAGENTBAG_SLOTS
        and NUM_REAGENTBAG_SLOTS > 0
    then
        reagentBag = normalBagCount + 1
    end

    if reagentBag ~= nil then
        AddUniqueBag(bags, seen, reagentBag)
    end

    local keyring = KEYRING_CONTAINER

    if keyring == nil and Enum and Enum.BagIndex then
        keyring = Enum.BagIndex.Keyring
    end

    if keyring ~= nil then
        AddUniqueBag(bags, seen, keyring)
    end

    return bags
end

local function UpdateItemButton(button, bagID, slotID)
    local search = Module.frame
        and Module.frame.search
        and Module.frame.search:GetText()
        or ""

    Components:SetContainerItemSlotData(
        button,
        bagID,
        slotID,
        {
            borderColor = GetBagFamilyColor(bagID),
            search = search,
        }
    )
end

local function UpdateCachedItemButton(button, slot, bag)
    button.bagID = bag.bagID

    local borderColor = Palette:GetBagFamilyColor(
        bag.family,
        bag.isKeyring
    )
    local search = Module.frame
        and Module.frame.search
        and Module.frame.search:GetText()
        or ""
    local alpha = 1

    if slot and search ~= "" then
        local haystack = string.lower(
            slot.name or slot.link or ""
        )

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

local function GetBagButtonTexture(bagID)
    if bagID == (BACKPACK_CONTAINER or 0) then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end

    local keyring = KEYRING_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

    if bagID == keyring then
        return "Interface\\ContainerFrame\\KeyRing-Bag-Icon"
    end

    local inventoryID = UI:GetBagInventoryID(bagID)

    if inventoryID then
        return GetInventoryItemTexture("player", inventoryID)
    end
end

local function GetBagName(bagID)
    if bagID == (BACKPACK_CONTAINER or 0) then
        return BACKPACK_TOOLTIP or "Backpack"
    end

    local reagentBag = Enum
        and Enum.BagIndex
        and Enum.BagIndex.ReagentBag

    if reagentBag and bagID == reagentBag then
        return REAGENT_BAG or "Reagent Bag"
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

local function SaveCurrentCharacter()
    local db = GetDatabase()
    local key = UI:GetCurrentCharacterKey()
    local characters = UI:GetCharactersModule()

    if characters and characters.UpdateCurrentCharacter then
        characters:UpdateCurrentCharacter()
    end

    local existing = db.characters[key] or {}
    local character = {
        items = {},
        bags = {},
        updated = time and time() or 0,
        bank = existing.bank,
        bankItems = existing.bankItems,
    }

    local keyring = KEYRING_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

    for _, bagID in ipairs(GetInventoryBags()) do
        local _, family = UI:GetContainerNumFreeSlots(bagID)
        local slotCount = UI:GetContainerNumSlots(bagID)
        local bag = {
            bagID = bagID,
            name = GetBagName(bagID),
            icon = GetBagButtonTexture(bagID),
            family = family or 0,
            isKeyring = bagID == keyring,
            slotCount = slotCount,
            slots = {},
        }

        for slotID = 1, slotCount do
            local info = UI:GetContainerItemInfo(bagID, slotID)

            if info then
                local itemID = info.itemID
                local itemName

                if info.hyperlink and GetItemInfo then
                    itemName = GetItemInfo(info.hyperlink)
                end

                bag.slots[slotID] = {
                    itemID = itemID,
                    link = info.hyperlink,
                    icon = info.iconFileID,
                    count = info.stackCount or 1,
                    quality = info.quality,
                    name = itemName,
                }

                if itemID then
                    character.items[itemID] =
                        (character.items[itemID] or 0) + (info.stackCount or 1)
                end
            end
        end

        character.bags[#character.bags + 1] = bag
    end

    db.characters[key] = character

    return key, character
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

local function CreateBagBarButton(parent)
    local button = Components:CreateItemSlot(parent, {
        size = 32,
        count = true,
        countFontSize = 9,
        rarityGlow = false,
        border = false,
    })

    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(self)
        if self.isCached then
            local db = GetDatabase()
            db.hiddenBags[self.bagID] = not db.hiddenBags[self.bagID]
            Module:Rebuild()
            return
        end

        local inventoryID = UI:GetBagInventoryID(self.bagID)

        if CursorHasItem and CursorHasItem() and inventoryID then
            if not InCombatLockdown or not InCombatLockdown() then
                PickupInventoryItem(inventoryID)
            end

            return
        end

        local db = GetDatabase()
        db.hiddenBags[self.bagID] = not db.hiddenBags[self.bagID]

        Module:Rebuild()
    end)

    button:SetScript("OnReceiveDrag", function(self)
        if self.isCached then
            return
        end

        local inventoryID = UI:GetBagInventoryID(self.bagID)

        if inventoryID
            and (not InCombatLockdown or not InCombatLockdown())
        then
            PickupInventoryItem(inventoryID)
        end
    end)

    button:SetScript("OnDragStart", function(self)
        if self.isCached then
            return
        end

        local inventoryID = UI:GetBagInventoryID(self.bagID)

        if inventoryID
            and (not InCombatLockdown or not InCombatLockdown())
        then
            PickupInventoryItem(inventoryID)
        end
    end)

    button:SetScript("OnEnter", function(self)
        Module:SetBagSlotHighlight(self.bagID, true)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")

        if self.isCached then
            GameTooltip:SetText(self.cachedName or ("Bag " .. tostring(self.bagID)))
            GameTooltip:AddLine("Click: show/hide bag", 0.75, 0.75, 0.75)
            GameTooltip:Show()
            return
        end

        local inventoryID = UI:GetBagInventoryID(self.bagID)

        if inventoryID and GameTooltip:SetInventoryItem("player", inventoryID) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click: show/hide bag", 0.75, 0.75, 0.75)
            GameTooltip:AddLine("Drag: equip/swap bag", 0.75, 0.75, 0.75)
            GameTooltip:Show()
            return
        end

        GameTooltip:SetText(GetBagName(self.bagID))
        GameTooltip:AddLine("Click: show/hide bag", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        Module:SetBagSlotHighlight(self.bagID, false)
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
    local bags = {}

    if isCurrent then
        for _, bagID in ipairs(GetInventoryBags()) do
            bags[#bags + 1] = {
                bagID = bagID,
                icon = GetBagButtonTexture(bagID),
                name = GetBagName(bagID),
                free = UI:CountContainerFreeSlots(bagID),
                isKeyring = bagID == (
                    KEYRING_CONTAINER
                    or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)
                ),
                isCached = false,
            }
        end
    elseif character then
        for _, bag in ipairs(character.bags or {}) do
            local used = 0

            for slotID = 1, bag.slotCount or 0 do
                local slot = bag.slots and bag.slots[slotID]

                if slot then
                    used = used + 1
                end
            end

            bags[#bags + 1] = {
                bagID = bag.bagID,
                icon = bag.icon,
                name = bag.name,
                free = math.max(0, (bag.slotCount or 0) - used),
                isKeyring = bag.isKeyring,
                isCached = true,
            }
        end
    end

    for index, bag in ipairs(bags) do
        local button = frame.bagBarButtons[index]

        if not button then
            button = CreateBagBarButton(frame.bagBar)
            frame.bagBarButtons[index] = button
        end

        button.bagID = bag.bagID
        button.isCached = bag.isCached
        button.cachedName = bag.name
        button.icon:SetTexture(bag.icon)

        if bag.isKeyring then
            button.icon:SetTexCoord(0, 0.9, 0.1, 1)
        else
            button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        button.count:SetText(bag.free)

        local hidden = GetDatabase().hiddenBags[bag.bagID] == true
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

    for index = #bags + 1, #frame.bagBarButtons do
        frame.bagBarButtons[index]:Hide()
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

    self.frame.title:SetText(name .. "'s Inventory")
end

function Module:SetViewedCharacter(key)
    local currentKey = UI:GetCurrentCharacterKey()

    self.viewCharacterKey = key == currentKey and nil or key

    if self.frame and self.frame.characterMenu then
        self.frame.characterMenu:Hide()
    end

    self:Rebuild()
end

function Module:UpdateBagBarVisibility()
    local frame = self.frame

    if not frame then
        return
    end

    local expanded = GetDatabase().bagBarExpanded

    frame.bagBar:SetShown(expanded)
    frame.bagBarToggle:SetText(expanded and "Bags -" or "Bags +")

    self:Layout()
end

function Module:Layout()
    local frame = self.frame

    if not frame then
        return
    end

    local buttons = frame.activeButtons or frame.itemButtons
    local bagBarOffset = GetDatabase().bagBarExpanded
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

    SaveCurrentCharacter()

    for _, button in ipairs(frame.itemButtons) do
        button:Hide()
    end

    for _, button in ipairs(frame.cachedButtons or {}) do
        button:Hide()
    end

    local _, character, isCurrent = GetViewedCharacter()

    if not isCurrent and character then
        frame.liveInventory = false
        local activeButtons = {}
        local index = 0

        for _, bag in ipairs(character.bags or {}) do
            if not GetDatabase().hiddenBags[bag.bagID] then
                local slotCount = bag.slotCount or 0

                if slotCount == 0 then
                    for slotID in pairs(bag.slots or {}) do
                        slotCount = math.max(slotCount, slotID)
                    end
                end

                for slotID = 1, slotCount do
                    local slot = bag.slots and bag.slots[slotID]
                    local showSlot = not bag.isKeyring or slot ~= nil

                    if showSlot then
                        index = index + 1

                        local button = frame.cachedButtons[index]

                        if not button then
                            button = Components:CreateItemDisplayButton(frame.content, {
                size = SLOT_SIZE,
                corners = true,
            })
                            frame.cachedButtons[index] = button
                        end

                        UpdateCachedItemButton(button, slot, bag)
                        button:Show()
                        activeButtons[#activeButtons + 1] = button
                    end
                end
            end
        end

        for i = index + 1, #frame.cachedButtons do
            frame.cachedButtons[i]:Hide()
        end

        frame.activeButtons = activeButtons

        if self.highlightedBagID then
            self:SetBagSlotHighlight(self.highlightedBagID, true)
        end

        frame.bagBarToggle:Show()
        frame.sort:Hide()
        self:UpdateBagBar()
        self:UpdateMoney()
        self:UpdateTitle()
        self:UpdateBagBarVisibility()

        return
    end

    frame.liveInventory = true
    frame.bagBarToggle:Show()
    frame.sort:Show()

    local activeIndex = 0
    local bags = GetInventoryBags()

    for _, bagID in ipairs(bags) do
        if not GetDatabase().hiddenBags[bagID] then
            local carrier = frame.bagCarriers[bagID]

        if not carrier then
            carrier = Components:CreateCarrier(frame.content, bagID)
            frame.bagCarriers[bagID] = carrier
        end

        carrier:SetID(bagID)

        local slotCount = UI:GetContainerNumSlots(bagID)
        local keyring = KEYRING_CONTAINER
            or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

            for slotID = 1, slotCount do
                local showSlot = bagID ~= keyring
                    or UI:GetContainerItemInfo(bagID, slotID) ~= nil

                if showSlot then
                    activeIndex = activeIndex + 1

                    local button = frame.itemButtons[activeIndex]

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
                        frame.itemButtons[activeIndex] = button
                    end

                    button:Show()
                    UpdateItemButton(button, bagID, slotID)
                end
            end
        end
    end

    for index = activeIndex + 1, #frame.itemButtons do
        frame.itemButtons[index]:Hide()
    end

    while #frame.itemButtons > activeIndex do
        frame.itemButtons[#frame.itemButtons] = nil
    end

    local activeButtons = {}

    for index = 1, activeIndex do
        activeButtons[index] = frame.itemButtons[index]
    end

    frame.activeButtons = activeButtons

    if self.highlightedBagID then
        self:SetBagSlotHighlight(self.highlightedBagID, true)
    end

    self:UpdateBagBar()
    self:UpdateMoney()
    self:UpdateTitle()
    self:UpdateBagBarVisibility()
end

function Module:Refresh()
    local frame = self.frame

    if not frame or not frame:IsShown() then
        return
    end

    self:Rebuild()
end

function Module:Show()
    if not self.frame or self.frame:IsShown() then
        return
    end

    self:Rebuild()
    self.frame:Show()

    if PlaySound then
        PlaySound(
            SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 862
        )
    end
end

function Module:Hide()
    if self.frame and self.frame:IsShown() then
        self.viewCharacterKey = nil
        self.frame:Hide()

        if PlaySound then
            PlaySound(
                SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE or 863
            )
        end
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
    local db = GetDatabase()
    db.position = nil

    if self.frame then
        UI:ApplyFramePosition(self.frame, GetDatabase(), "position", 280, 0)
    end

    UI:Print("Bag position reset")
end

local function CreateFrameUI()
    local frame, header = Components:CreateWindow("KamiUIBagFrame", {
        backgroundColor = Palette.window.inventory,
        borderColor = Palette.windowBorder.inventory,
        onDragStop = function(target)
            UI:SaveFramePosition(target, GetDatabase())
        end,
        header = {
            height = HEADER_HEIGHT,
            title = UI:GetCurrentCharacterName() .. "'s Inventory",
        },
    })

    local title = header.Title
    frame.title = title

    Components:AttachHeaderSearch(frame, header, {
        closeOnFocusLost = true,
        onTextChanged = function(text)
            local _, _, isCurrent = GetViewedCharacter()

            if isCurrent then
                if C_Container and C_Container.SetItemSearch then
                    C_Container.SetItemSearch(text)
                elseif SetItemSearch then
                    SetItemSearch(text)
                end
            end

            Module:Refresh()
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
                backgroundColor = { 0.04, 0.02, 0.06, 0.95 },
                borderColor = Palette.windowBorder.inventory,
                fontSize = 9,
                heightPadding = 6,
                minHeight = 26,
                getEntries = GetSortedCharacters,
                getCharacter = function(entry)
                    return entry.profile
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Characters")
        GameTooltip:Show()
    end)

    characterButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local bagBarToggle = CreateFrame("Button", nil, header)
    bagBarToggle:SetSize(52, 20)
    bagBarToggle:SetPoint(
        "LEFT",
        characterButton,
        "RIGHT",
        4,
        0
    )
    bagBarToggle:SetNormalFontObject("GameFontNormalSmall")
    bagBarToggle:SetHighlightFontObject("GameFontHighlightSmall")
    bagBarToggle:SetText("Bags +")
    Components:StyleButton(bagBarToggle)
    bagBarToggle:SetScript("OnClick", function()
        local db = GetDatabase()
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
    frame.cachedButtons = {}
    frame.activeButtons = frame.itemButtons
    frame.bagCarriers = {}

    local sort = CreateFrame("Button", nil, frame)
    sort:SetSize(34, 18)
    sort:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", FRAME_PADDING, 4)
    sort:SetNormalFontObject("GameFontNormalSmall")
    sort:SetHighlightFontObject("GameFontHighlightSmall")
    sort:SetText("Sort")
    Components:StyleButton(sort)
    sort:SetScript("OnClick", function()
        if sortingBags then
            return
        end

        sortingBags = true
        pendingSortRefresh = false
        sort:Disable()

        if C_Container and C_Container.SortBags then
            C_Container.SortBags()
        elseif SortBags then
            SortBags()
        end

        C_Timer.After(0.25, function()
            sortingBags = false
            sort:Enable()

            if pendingSortRefresh then
                pendingSortRefresh = false
            end

            SaveCurrentCharacter()
            Module:Refresh()
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
    frame.moneyButton = moneyButton

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

    frame:SetScript("OnShow", function()
        Module:Rebuild()
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

    UI:ApplyFramePosition(frame, GetDatabase(), "position", 280, 0)

    return frame
end

local function InstallBagHooks()
    if Module.hooksInstalled then
        return
    end

    Module.hooksInstalled = true

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

UI:RegisterCommand(
    "bags",
    "dbreset",
    function()
        local db = GetDatabase()

        db.characters = {}
        Module.viewCharacterKey = nil

        SaveCurrentCharacter()

        if Module.frame then
            Module:Rebuild()
        end

        UI:Print("Bag database reset")
    end,
    "Reset cached character inventories"
)

local function AddCharacterCountsToTooltip(tooltip, data)
    if not tooltip then
        return
    end

    local itemID = data and data.id

    if not itemID and type(tooltip.GetItem) == "function" then
        local _, link = tooltip:GetItem()

        if link then
            itemID = tonumber(string.match(link, "item:(%d+)"))
        end
    end

    itemID = tonumber(itemID)

    if not itemID or tooltip.KamiCountItemID == itemID then
        return
    end

    tooltip.KamiCountItemID = itemID

    local lines = {}

    for _, entry in ipairs(GetSortedCharacters()) do
        local bagCount = entry.character.items
            and entry.character.items[itemID]
            or 0
        local bankCount = entry.character.bankItems
            and entry.character.bankItems[itemID]
            or 0
        local count = bagCount + bankCount

        if count > 0 then
            local profile = entry.profile

            lines[#lines + 1] = {
                name = profile.name or "Unknown",
                classFile = profile.classFile,
                count = count,
                bagCount = bagCount,
                bankCount = bankCount,
            }
        end
    end

    if #lines == 0 then
        return
    end

    tooltip:AddLine(" ")

    local totalCount = 0

    for _, line in ipairs(lines) do
        totalCount = totalCount + line.count
        local color = Palette:GetClassColor(line.classFile)
        local r = color and color.r or 0.75
        local g = color and color.g or 0.65
        local b = color and color.b or 0.90

        local countText

        if line.bankCount > 0 then
            countText = string.format(
                "%d (Bags: %d, Bank: %d)",
                line.count,
                line.bagCount,
                line.bankCount
            )
        else
            countText = tostring(line.bagCount)
        end

        tooltip:AddDoubleLine(
            line.name,
            countText,
            r,
            g,
            b,
            r,
            g,
            b
        )
    end

    tooltip:AddDoubleLine(
        "Total",
        tostring(totalCount),
        0.75,
        0.75,
        0.75,
        1,
        1,
        1
    )

    tooltip:Show()
end

local function InstallTooltipHook()
    if Module.tooltipHookInstalled then
        return
    end

    Module.tooltipHookInstalled = true

    if TooltipDataProcessor
        and TooltipDataProcessor.AddTooltipPostCall
        and Enum
        and Enum.TooltipDataType
        and Enum.TooltipDataType.Item
    then
        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Item,
            AddCharacterCountsToTooltip
        )

        for _, tooltip in ipairs({
            GameTooltip,
            ShoppingTooltip1,
            ShoppingTooltip2,
        }) do
            if tooltip and tooltip.HookScript then
                tooltip:HookScript("OnTooltipCleared", function(self)
                    self.KamiCountItemID = nil
                end)
            end
        end
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(self)
            AddCharacterCountsToTooltip(self)
        end)
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            self.KamiCountItemID = nil
        end)
    end
end

function Module:Initialize()
    GetDatabase()
    CleanupLegacyCharacterMetadata()
    SaveCurrentCharacter()

    self.frame = CreateFrameUI()
    InstallBagHooks()

    local hotkeyButton = CreateFrame("Button", "KamiUIBagsHotkeyButton", UIParent)
    hotkeyButton:SetScript("OnClick", function()
        Module:Toggle()
    end)
    self.hotkeyButton = hotkeyButton

    if SetOverrideBindingClick then
        if ClearOverrideBindings then
            ClearOverrideBindings(hotkeyButton)
        end

        local boundKeys = {}

        local function BindKey(key)
            if not key or boundKeys[key] then
                return
            end

            boundKeys[key] = true

            SetOverrideBindingClick(
                hotkeyButton,
                true,
                key,
                "KamiUIBagsHotkeyButton",
                "LeftButton"
            )
        end

        local function BindCommand(command)
            if not GetBindingKey then
                return
            end

            local key1, key2 = GetBindingKey(command)
            BindKey(key1)
            BindKey(key2)
        end

        for _, command in ipairs({
            "TOGGLEBACKPACK",
            "OPENALLBAGS",
            "TOGGLEBAG1",
            "TOGGLEBAG2",
            "TOGGLEBAG3",
            "TOGGLEBAG4",
            "TOGGLEBAG5",
        }) do
            BindCommand(command)
        end

        BindKey("B")
    end

    self:UpdateBagBarVisibility()
    self:Rebuild()

    InstallTooltipHook()

    UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if sortingBags or _G.KamiUIBankSortInProgress then
            pendingSortRefresh = true
            return
        end

        SaveCurrentCharacter()
        Module:Refresh()
    end)

    UI:RegisterEvent("BAG_UPDATE_COOLDOWN", function()
        if sortingBags or _G.KamiUIBankSortInProgress then
            return
        end

        Module:Refresh()
    end)

    UI:RegisterEvent("ITEM_LOCK_CHANGED", function()
        if sortingBags or _G.KamiUIBankSortInProgress then
            return
        end

        Module:Refresh()
    end)

    UI:RegisterEvent("MAIL_SEND_INFO_UPDATE", function()
        if sortingBags or _G.KamiUIBankSortInProgress then
            return
        end

        Module:Refresh()
    end)

    UI:RegisterEvent("MAIL_CLOSED", function()
        if sortingBags or _G.KamiUIBankSortInProgress then
            return
        end

        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MONEY", function()
        local characters = UI:GetCharactersModule()

        if characters and characters.UpdateCurrentCharacter then
            characters:UpdateCurrentCharacter()
        end

        Module:UpdateMoney()
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingRebuild then
            Module:Rebuild()
        end
    end)
end

Module:Initialize()
