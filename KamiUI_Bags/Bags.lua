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
    background = { 0.345, 0.000, 0.447, 0.25 },
    slotBackground = { 0.02, 0.02, 0.02, 0.55 },
    slotBorder = { 0.30, 0.24, 0.32, 0.90 },
    border = { 0.20, 0.16, 0.24, 1.00 },
}

local bagFamilyColors = {
    arrows = { 0.85, 0.55, 0.12, 1.00 },
    bullets = { 0.55, 0.58, 0.62, 1.00 },
    soul = { 0.55, 0.20, 0.75, 1.00 },
    leather = { 0.58, 0.36, 0.18, 1.00 },
    skinning = { 0.72, 0.48, 0.22, 1.00 },
    herbs = { 0.18, 0.68, 0.24, 1.00 },
    mining = { 0.38, 0.55, 0.68, 1.00 },
    keyring = { 0.90, 0.70, 0.15, 1.00 },
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

    db.hiddenBags = db.hiddenBags or {}
    db.characters = db.characters or {}

    return db
end

local function GetCurrentCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""

    return realm .. "::" .. name
end

local function GetCurrentCharacterName()
    return UnitName("player") or "Player"
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

local function GetContainerNumFreeSlots(bagID)
    if C_Container and C_Container.GetContainerNumFreeSlots then
        return C_Container.GetContainerNumFreeSlots(bagID)
    end

    if _G.GetContainerNumFreeSlots then
        return _G.GetContainerNumFreeSlots(bagID)
    end

    return 0, 0
end

local function HasBagFamilyFlag(value, flag)
    if not value or not flag or flag <= 0 then
        return false
    end

    return value % (flag * 2) >= flag
end

local function GetBagInventoryID(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(bagID)
    end

    if ContainerIDToInventoryID then
        return ContainerIDToInventoryID(bagID)
    end
end


local function GetBagFamilyColorFromMask(family, isKeyring)
    if isKeyring then
        return bagFamilyColors.keyring
    end

    family = family or 0

    local arrows = BAG_FAMILY_MASK_ARROWS or 0x00000001
    local bullets = BAG_FAMILY_MASK_BULLETS or 0x00000002
    local soul = BAG_FAMILY_MASK_SOUL_SHARDS or 0x00000004
    local leather = BAG_FAMILY_MASK_LEATHERWORKING_SUPP or 0x00000008
    local herbs = BAG_FAMILY_MASK_HERBS or 0x00000020
    local mining = BAG_FAMILY_MASK_MINING_SUPP or 0x00000400
    local skinning = BAG_FAMILY_MASK_SKINNING or 0x02000000

    if HasBagFamilyFlag(family, arrows) then
        return bagFamilyColors.arrows
    elseif HasBagFamilyFlag(family, bullets) then
        return bagFamilyColors.bullets
    elseif HasBagFamilyFlag(family, soul) then
        return bagFamilyColors.soul
    elseif HasBagFamilyFlag(family, herbs) then
        return bagFamilyColors.herbs
    elseif HasBagFamilyFlag(family, leather) then
        return bagFamilyColors.leather
    elseif HasBagFamilyFlag(family, skinning) then
        return bagFamilyColors.skinning
    elseif HasBagFamilyFlag(family, mining) then
        return bagFamilyColors.mining
    end

    return defaults.slotBorder
end

local function GetBagFamilyColor(bagID)
    local keyring = KEYRING_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

    if bagID == keyring then
        return bagFamilyColors.keyring
    end

    local inventoryID = GetBagInventoryID(bagID)

    if inventoryID then
        local link = GetInventoryItemLink("player", inventoryID)

        if link and GetItemInfoInstant then
            local _, _, _, _, _, classID, subClassID =
                GetItemInfoInstant(link)

            if classID == 11 then
                if subClassID == 2 then
                    return bagFamilyColors.arrows
                elseif subClassID == 3 then
                    return bagFamilyColors.bullets
                end
            elseif classID == 1 then
                if subClassID == 1 then
                    return bagFamilyColors.soul
                elseif subClassID == 2 then
                    return bagFamilyColors.herbs
                elseif subClassID == 6 then
                    return bagFamilyColors.mining
                elseif subClassID == 7 then
                    return bagFamilyColors.leather
                end
            end
        end
    end

    local _, family = GetContainerNumFreeSlots(bagID)

    return GetBagFamilyColorFromMask(family, false)
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

    if button.NormalTexture then
        button.NormalTexture:Hide()
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

    local top = button:CreateTexture(nil, "BORDER")
    top:SetColorTexture(unpack(defaults.slotBorder))
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = button:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(unpack(defaults.slotBorder))
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = button:CreateTexture(nil, "BORDER")
    left:SetColorTexture(unpack(defaults.slotBorder))
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = button:CreateTexture(nil, "BORDER")
    right:SetColorTexture(unpack(defaults.slotBorder))
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    button.KamiBorders = { top, bottom, left, right }

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

    local borderColor = GetBagFamilyColor(bagID)

    if button.KamiBorders then
        for _, border in ipairs(button.KamiBorders) do
            border:SetColorTexture(unpack(borderColor))
        end
    end

    if ContainerFrameItemButton_Update then
        ContainerFrameItemButton_Update(button)
    end

    local info = GetContainerItemInfo(bagID, slotID)
    local icon = button.icon or button.Icon

    if info then
        local filtered = info.isFiltered == true
        local search = Module.frame
            and Module.frame.search
            and Module.frame.search:GetText()
            or ""

        if search ~= "" then
            local itemName = info.itemName

            if not itemName and info.hyperlink and GetItemInfo then
                itemName = GetItemInfo(info.hyperlink)
            end

            local haystack = string.lower(
                itemName or info.hyperlink or ""
            )

            filtered = not string.find(
                haystack,
                string.lower(search),
                1,
                true
            )
        end

        button:SetAlpha(filtered and 0.20 or 1.00)

        if icon then
            icon:SetTexture(info.iconFileID)
            icon:SetAlpha(1)
        end

        if button.Count then
            local count = info.stackCount or 1
            button.Count:SetText(count > 1 and count or "")
            button.Count:Show()
        end

        if button.Cooldown and C_Container.GetContainerItemCooldown then
            local start, duration, enable = C_Container.GetContainerItemCooldown(
                bagID,
                slotID
            )

            CooldownFrame_Set(
                button.Cooldown,
                start or 0,
                duration or 0,
                enable or 0
            )
        end
    else
        button:SetAlpha(1)

        if icon then
            icon:SetTexture(nil)
        end

        if button.Count then
            button.Count:SetText("")
        end

        if button.Cooldown then
            button.Cooldown:Clear()
        end
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

local function CreateCachedItemButton(content)
    local button = CreateFrame("Button", nil, content)
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.Count = count

    StyleItemButton(button)

    button:SetScript("OnEnter", function(self)
        if not self.itemLink then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function UpdateCachedItemButton(button, slot, bag)
    local borderColor = GetBagFamilyColorFromMask(
        bag.family,
        bag.isKeyring
    )

    if button.KamiBorders then
        for _, border in ipairs(button.KamiBorders) do
            border:SetColorTexture(unpack(borderColor))
        end
    end

    button.itemLink = slot and slot.link or nil
    button.icon:SetTexture(slot and slot.icon or nil)
    button.Count:SetText(
        slot and slot.count and slot.count > 1 and slot.count or ""
    )

    local search = Module.frame
        and Module.frame.search
        and Module.frame.search:GetText()
        or ""

    if slot and search ~= "" then
        local haystack = string.lower(
            slot.name or slot.link or ""
        )

        button:SetAlpha(
            string.find(haystack, string.lower(search), 1, true)
                and 1.00
                or 0.20
        )
    else
        button:SetAlpha(1)
    end
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

    local inventoryID = GetBagInventoryID(bagID)

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
    local db = EnsureDatabase()
    local key = GetCurrentCharacterKey()
    local name = GetCurrentCharacterName()
    local realm = GetRealmName() or ""
    local character = {
        name = name,
        realm = realm,
        money = GetMoney() or 0,
        items = {},
        bags = {},
        updated = time and time() or 0,
    }

    local keyring = KEYRING_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

    for _, bagID in ipairs(GetInventoryBags()) do
        local _, family = GetContainerNumFreeSlots(bagID)
        local bag = {
            bagID = bagID,
            name = GetBagName(bagID),
            icon = GetBagButtonTexture(bagID),
            family = family or 0,
            isKeyring = bagID == keyring,
            slots = {},
        }

        local slotCount = GetContainerNumSlots(bagID)

        for slotID = 1, slotCount do
            local info = GetContainerItemInfo(bagID, slotID)

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
    local db = EnsureDatabase()
    local currentKey = GetCurrentCharacterKey()
    local key = Module.viewCharacterKey or currentKey

    return key, db.characters[key], key == currentKey
end

local function GetSortedCharacters()
    local characters = {}

    for key, character in pairs(EnsureDatabase().characters) do
        characters[#characters + 1] = {
            key = key,
            character = character,
        }
    end

    table.sort(characters, function(a, b)
        if a.character.realm == b.character.realm then
            return (a.character.name or "") < (b.character.name or "")
        end

        return (a.character.realm or "") < (b.character.realm or "")
    end)

    return characters
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
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(defaults.slotBackground))
    button.background = background

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

    button:SetScript("OnClick", function(self)
        local inventoryID = GetBagInventoryID(self.bagID)

        if CursorHasItem and CursorHasItem() and inventoryID then
            if not InCombatLockdown or not InCombatLockdown() then
                PickupInventoryItem(inventoryID)
            end

            return
        end

        local db = EnsureDatabase()
        db.hiddenBags[self.bagID] = not db.hiddenBags[self.bagID]

        Module:Rebuild()
    end)

    button:SetScript("OnReceiveDrag", function(self)
        local inventoryID = GetBagInventoryID(self.bagID)

        if inventoryID
            and (not InCombatLockdown or not InCombatLockdown())
        then
            PickupInventoryItem(inventoryID)
        end
    end)

    button:SetScript("OnDragStart", function(self)
        local inventoryID = GetBagInventoryID(self.bagID)

        if inventoryID
            and (not InCombatLockdown or not InCombatLockdown())
        then
            PickupInventoryItem(inventoryID)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")

        local inventoryID = GetBagInventoryID(self.bagID)

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
    local parts = {}

    if gold > 0 then
        parts[#parts + 1] = string.format(
            "%d |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t",
            gold
        )
    end

    if silver > 0 or gold > 0 then
        parts[#parts + 1] = string.format(
            "%d |TInterface\\MoneyFrame\\UI-SilverIcon:14:14:0:0|t",
            silver
        )
    end

    parts[#parts + 1] = string.format(
        "%d |TInterface\\MoneyFrame\\UI-CopperIcon:14:14:0:0|t",
        bronze
    )

    return table.concat(parts, " ")
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

        local keyring = KEYRING_CONTAINER
            or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

        if bagID == keyring then
            button.icon:SetTexCoord(0, 0.9, 0.1, 1)
        else
            button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        button.count:SetText(CountFreeSlots(bagID))

        local hidden = EnsureDatabase().hiddenBags[bagID] == true
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

    local _, character, isCurrent = GetViewedCharacter()
    local money = isCurrent and GetMoney()
        or (character and character.money)
        or 0

    self.frame.money:SetText(FormatMoney(money))
end

function Module:UpdateTitle()
    if not self.frame or not self.frame.title then
        return
    end

    local _, character, isCurrent = GetViewedCharacter()
    local name = isCurrent
        and GetCurrentCharacterName()
        or (character and character.name)
        or "Unknown"

    self.frame.title:SetText(name .. "'s Inventory")
end

function Module:SetViewedCharacter(key)
    local currentKey = GetCurrentCharacterKey()

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

    local buttons = frame.activeButtons or frame.itemButtons
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

    SaveCurrentCharacter()

    for _, button in ipairs(frame.itemButtons) do
        button:Hide()
    end

    for _, button in ipairs(frame.cachedButtons or {}) do
        button:Hide()
    end

    local _, character, isCurrent = GetViewedCharacter()

    if not isCurrent and character then
        local activeButtons = {}
        local index = 0

        for _, bag in ipairs(character.bags or {}) do
            if not EnsureDatabase().hiddenBags[bag.bagID] then
                for slotID = 1, #(bag.slots or {}) do
                    local slot = bag.slots[slotID]
                    local showSlot = not bag.isKeyring or slot ~= nil

                    if showSlot then
                        index = index + 1

                        local button = frame.cachedButtons[index]

                        if not button then
                            button = CreateCachedItemButton(frame.content)
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
        frame.bagBar:Hide()
        frame.bagBarToggle:Hide()
        frame.sort:Hide()
        self:UpdateMoney()
        self:UpdateTitle()
        self:Layout()

        return
    end

    frame.bagBarToggle:Show()
    frame.sort:Show()

    local activeIndex = 0
    local bags = GetInventoryBags()

    for _, bagID in ipairs(bags) do
        if not EnsureDatabase().hiddenBags[bagID] then
            local carrier = frame.bagCarriers[bagID]

        if not carrier then
            carrier = CreateBagCarrier(frame.content, bagID)
            frame.bagCarriers[bagID] = carrier
        end

        carrier:SetID(bagID)

        local slotCount = GetContainerNumSlots(bagID)
        local keyring = KEYRING_CONTAINER
            or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)

            for slotID = 1, slotCount do
                local showSlot = bagID ~= keyring
                    or GetContainerItemInfo(bagID, slotID) ~= nil

                if showSlot then
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
    title:SetText(GetCurrentCharacterName() .. "'s Inventory")
    title:SetTextColor(0.92, 0.88, 1)
    frame.title = title

    local titleButton = CreateFrame("Button", nil, frame)
    titleButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 90, -2)
    titleButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -90, -2)
    titleButton:SetHeight(24)
    titleButton:RegisterForDrag("LeftButton")
    titleButton:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleButton:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    frame.titleButton = titleButton

    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
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

            if C_Container and C_Container.SetItemSearch then
                C_Container.SetItemSearch("")
            elseif SetItemSearch then
                SetItemSearch("")
            end

            Module:Refresh()
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

    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        local _, _, isCurrent = GetViewedCharacter()

        if isCurrent then
            if C_Container and C_Container.SetItemSearch then
                C_Container.SetItemSearch(text)
            elseif SetItemSearch then
                SetItemSearch(text)
            end
        end

        Module:Refresh()
    end)

    search:SetScript("OnEscapePressed", function()
        CloseSearch(true)
    end)

    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        CloseSearch(false)
    end)

    search:SetScript("OnEditFocusLost", function()
        if search:IsShown() then
            CloseSearch(false)
        end
    end)

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

    local characterButton = CreateFrame("Button", nil, frame)
    characterButton:SetSize(20, 20)
    characterButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)

    local characterIcon = characterButton:CreateTexture(nil, "ARTWORK")
    characterIcon:SetAllPoints()
    characterIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    characterButton.icon = characterIcon
    frame.characterButton = characterButton

    local characterMenu = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )
    characterMenu:SetPoint(
        "TOPLEFT",
        characterButton,
        "BOTTOMLEFT",
        0,
        -2
    )
    characterMenu:SetWidth(170)
    characterMenu:SetFrameLevel(frame:GetFrameLevel() + 20)
    characterMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    characterMenu:SetBackdropColor(0.04, 0.02, 0.06, 0.95)
    characterMenu:SetBackdropBorderColor(unpack(defaults.border))
    characterMenu.buttons = {}
    characterMenu:Hide()
    frame.characterMenu = characterMenu

    local function RebuildCharacterMenu()
        local characters = GetSortedCharacters()
        local height = 6

        for index, entry in ipairs(characters) do
            local button = characterMenu.buttons[index]

            if not button then
                button = CreateFrame("Button", nil, characterMenu)
                button:SetHeight(20)
                button:SetPoint(
                    "TOPLEFT",
                    characterMenu,
                    "TOPLEFT",
                    4,
                    -(4 + (index - 1) * 20)
                )
                button:SetPoint(
                    "TOPRIGHT",
                    characterMenu,
                    "TOPRIGHT",
                    -4,
                    -(4 + (index - 1) * 20)
                )

                local text = button:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormalSmall"
                )
                text:SetPoint("LEFT", 3, 0)
                button.text = text

                local highlight = button:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(1, 1, 1, 0.08)

                characterMenu.buttons[index] = button
            end

            local character = entry.character
            local label = character.name or "Unknown"

            if character.realm
                and character.realm ~= ""
                and character.realm ~= GetRealmName()
            then
                label = label .. " - " .. character.realm
            end

            button.text:SetText(label)
            button.characterKey = entry.key
            button:SetScript("OnClick", function(self)
                Module:SetViewedCharacter(self.characterKey)
            end)
            button:Show()

            height = height + 20
        end

        for index = #characters + 1, #characterMenu.buttons do
            characterMenu.buttons[index]:Hide()
        end

        characterMenu:SetHeight(math.max(26, height))
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

    local bagBarToggle = CreateFrame("Button", nil, frame)
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
    frame.cachedButtons = {}
    frame.activeButtons = frame.itemButtons
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

local function AddCharacterCountsToTooltip(tooltip)
    if not tooltip or type(tooltip.GetItem) ~= "function" then
        return
    end

    local _, link = tooltip:GetItem()

    if not link then
        return
    end

    local itemID = tonumber(string.match(link, "item:(%d+)"))

    if not itemID or tooltip.KamiCountItemID == itemID then
        return
    end

    tooltip.KamiCountItemID = itemID

    local lines = {}

    for _, entry in ipairs(GetSortedCharacters()) do
        local count = entry.character.items
            and entry.character.items[itemID]
            or 0

        if count > 0 then
            lines[#lines + 1] = {
                name = entry.character.name or "Unknown",
                count = count,
            }
        end
    end

    if #lines == 0 then
        return
    end

    tooltip:AddLine(" ")

    for _, line in ipairs(lines) do
        tooltip:AddDoubleLine(
            line.name,
            tostring(line.count),
            0.75,
            0.65,
            0.90,
            1,
            1,
            1
        )
    end

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
    EnsureDatabase()
    SaveCurrentCharacter()

    self.frame = CreateFrameUI()

    self:UpdateBagBarVisibility()
    self:Rebuild()

    InstallBagHooks()
    InstallTooltipHook()

    UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
        SaveCurrentCharacter()
        Module:Refresh()
    end)

    UI:RegisterEvent("BAG_UPDATE_COOLDOWN", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("ITEM_LOCK_CHANGED", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MONEY", function()
        SaveCurrentCharacter()
        Module:UpdateMoney()
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingRebuild then
            Module:Rebuild()
        end
    end)
end

Module:Initialize()
