local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

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
}

local bagFamilyColors = {
    arrows = { 0.565, 0.000, 0.000, 1.00 },
    bullets = { 0.565, 0.000, 0.000, 1.00 },
    soul = { 0.55, 0.20, 0.75, 1.00 },
    leather = { 0.439, 0.188, 0.063, 1.00 },
    skinning = { 0.439, 0.188, 0.063, 1.00 },
    herbs = { 0.122, 0.420, 0.220, 1.00 },
    mining = { 0.38, 0.55, 0.68, 1.00 },
    keyring = { 0.90, 0.70, 0.15, 1.00 },
}

local originalFunctions = {}
local pendingRebuild = false
local sortingBags = false
local pendingSortRefresh = false

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
                local bagID = button:GetParent():GetID()
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
                    local bagID = button:GetParent():GetID()
                    local slotID = button:GetID()

                    C_Container.PickupContainerItem(bagID, slotID)
                    return
                end
            end
        end
    end
end)

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

local function GetCharactersModule()
    if not UI.GetModule then
        return nil
    end

    local characters = UI:GetModule("Characters")

    if characters and characters.GetCharacters then
        return characters
    end

    return nil
end

local function GetCurrentCharacterNames()
    local first, surname = UnitName("player")

    first = first or "Player"

    if surname and surname ~= "" then
        return first, surname, first .. " " .. surname
    end

    return first, nil, first
end

local function GetCurrentCharacterKey()
    local characters = GetCharactersModule()

    if characters and characters.GetCurrentCharacterKey then
        return characters:GetCurrentCharacterKey()
    end

    local _, _, fullName = GetCurrentCharacterNames()
    local realm = GetRealmName() or ""

    return realm .. "::" .. fullName
end

local function GetCurrentCharacterName()
    local characters = GetCharactersModule()

    if characters and characters.GetCurrentCharacter then
        local _, character = characters:GetCurrentCharacter()

        if character and character.name then
            return character.name
        end
    end

    local _, _, fullName = GetCurrentCharacterNames()

    return fullName
end

local function ParseCharacterKey(key)
    local realm, name = string.match(key or "", "^(.-)::(.*)$")

    return realm or "", name or "Unknown"
end

local function GetCharacterProfile(key, legacy)
    local characters = GetCharactersModule()

    if characters and characters.GetCharacter then
        local character = characters:GetCharacter(key)

        if character then
            return character
        end
    end

    local realm, name = ParseCharacterKey(key)
    local profile = {
        name = legacy and legacy.name or name,
        firstName = legacy and legacy.firstName,
        surname = legacy and legacy.surname,
        classFile = legacy and legacy.classFile,
        realm = legacy and legacy.realm or realm,
        money = legacy and legacy.money or 0,
    }

    if key == GetCurrentCharacterKey() then
        local firstName, surname, fullName = GetCurrentCharacterNames()

        profile.name = fullName
        profile.firstName = firstName
        profile.surname = surname
        profile.realm = GetRealmName() or ""
        profile.classFile = select(2, UnitClass("player"))
        profile.money = GetMoney() or 0
    end

    return profile
end

local function GetSortedMoneyCharacters()
    local characters = GetCharactersModule()

    if characters and characters.GetSortedCharacters then
        return characters:GetSortedCharacters()
    end

    local entries = {}

    for key, legacy in pairs(EnsureDatabase().characters) do
        entries[#entries + 1] = {
            key = key,
            character = GetCharacterProfile(key, legacy),
        }
    end

    table.sort(entries, function(left, right)
        local leftRealm = left.character.realm or ""
        local rightRealm = right.character.realm or ""

        if leftRealm == rightRealm then
            return (left.character.name or "")
                < (right.character.name or "")
        end

        return leftRealm < rightRealm
    end)

    return entries
end

local function CleanupLegacyCharacterMetadata()
    if not GetCharactersModule() then
        return
    end

    for _, character in pairs(EnsureDatabase().characters) do
        character.name = nil
        character.firstName = nil
        character.surname = nil
        character.classFile = nil
        character.realm = nil
        character.money = nil
    end
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

    return Palette.slotBorder
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
    backdrop:SetBackdropColor(unpack(color or Palette.window.inventory))
    backdrop:SetBackdropBorderColor(unpack(Palette.windowBorder.inventory))
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
    background:SetColorTexture(unpack(Palette.slot))
    button.KamiBackground = background

    local top = button:CreateTexture(nil, "OVERLAY", nil, 2)
    top:SetColorTexture(unpack(Palette.slotBorder))
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = button:CreateTexture(nil, "OVERLAY", nil, 2)
    bottom:SetColorTexture(unpack(Palette.slotBorder))
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = button:CreateTexture(nil, "OVERLAY", nil, 2)
    left:SetColorTexture(unpack(Palette.slotBorder))
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = button:CreateTexture(nil, "OVERLAY", nil, 2)
    right:SetColorTexture(unpack(Palette.slotBorder))
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    button.KamiBorders = { top, bottom, left, right }

    local topLeft = button:CreateTexture(nil, "OVERLAY", nil, 2)
    topLeft:SetSize(1, 1)
    topLeft:SetPoint("TOPLEFT")

    local topRight = button:CreateTexture(nil, "OVERLAY", nil, 2)
    topRight:SetSize(1, 1)
    topRight:SetPoint("TOPRIGHT")

    local bottomLeft = button:CreateTexture(nil, "OVERLAY", nil, 2)
    bottomLeft:SetSize(1, 1)
    bottomLeft:SetPoint("BOTTOMLEFT")

    local bottomRight = button:CreateTexture(nil, "OVERLAY", nil, 2)
    bottomRight:SetSize(1, 1)
    bottomRight:SetPoint("BOTTOMRIGHT")

    button.KamiBorderCorners = {
        topLeft,
        topRight,
        bottomLeft,
        bottomRight,
    }

    local rarityGlow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    rarityGlow:SetPoint("CENTER", button, "CENTER", 1, 0)
    rarityGlow:SetSize(62, 62)
    rarityGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    rarityGlow:SetBlendMode("ADD")
    rarityGlow:SetAlpha(0.45)
    rarityGlow:Hide()
    button.KamiRarityGlow = rarityGlow

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

local function UpdateRarityBorder(button, quality)
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

local function SuppressNewItemFlash(button)
    if button.NewItemTexture then
        button.NewItemTexture:Hide()
    end

    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:Hide()
    end

    if button.flashAnim and button.flashAnim:IsPlaying() then
        button.flashAnim:Stop()
    end

    if button.newitemglowAnim and button.newitemglowAnim:IsPlaying() then
        button.newitemglowAnim:Stop()
    end
end

local function UpdateItemButton(button, bagID, slotID)
    button:SetID(slotID)
    button.bagID = bagID

    local borderColor = GetBagFamilyColor(bagID)

    if button.KamiBorders then
        for _, border in ipairs(button.KamiBorders) do
            border:SetColorTexture(unpack(borderColor))
        end
    end

    if button.KamiBorderCorners then
        for _, corner in ipairs(button.KamiBorderCorners) do
            corner:SetColorTexture(unpack(borderColor))
        end
    end

    if ContainerFrameItemButton_Update then
        ContainerFrameItemButton_Update(button)
    end

    SuppressNewItemFlash(button)

    local info = GetContainerItemInfo(bagID, slotID)
    local icon = button.icon or button.Icon

    if info then
        UpdateRarityBorder(button, info.quality)

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

        local alpha = filtered and 0.20 or 1.00

        button:SetAlpha(alpha)

        if icon then
            icon:SetTexture(info.iconFileID)
            icon:SetAlpha(alpha)
        end

        if button.Count then
            button.Count:SetAlpha(alpha)
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
        UpdateRarityBorder(button, nil)
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
    button:RegisterForDrag("LeftButton")

    button:HookScript("OnDragStart", function()
        itemDragFrame:Show()
    end)

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
    button.bagID = bag.bagID
    local borderColor = GetBagFamilyColorFromMask(
        bag.family,
        bag.isKeyring
    )

    if button.KamiBorders then
        for _, border in ipairs(button.KamiBorders) do
            border:SetColorTexture(unpack(borderColor))
        end
    end

    UpdateRarityBorder(button, slot and slot.quality or nil)

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
    local characters = GetCharactersModule()

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
        local _, family = GetContainerNumFreeSlots(bagID)
        local slotCount = GetContainerNumSlots(bagID)
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
            profile = GetCharacterProfile(key, character),
        }
    end

    table.sort(characters, function(left, right)
        local leftRealm = left.profile.realm or ""
        local rightRealm = right.profile.realm or ""

        if leftRealm == rightRealm then
            return (left.profile.name or "") < (right.profile.name or "")
        end

        return leftRealm < rightRealm
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

        button.KamiBagHighlight:SetShown(
            shown and button.bagID == bagID
        )
    end
end

local function CreateBagBarButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(Palette.slot))
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
        if self.isCached then
            local db = EnsureDatabase()
            db.hiddenBags[self.bagID] = not db.hiddenBags[self.bagID]
            Module:Rebuild()
            return
        end

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
        if self.isCached then
            return
        end

        local inventoryID = GetBagInventoryID(self.bagID)

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

        local inventoryID = GetBagInventoryID(self.bagID)

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

    button:SetScript("OnLeave", function(self)
        Module:SetBagSlotHighlight(self.bagID, false)
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

    local _, character, isCurrent = GetViewedCharacter()
    local bags = {}

    if isCurrent then
        for _, bagID in ipairs(GetInventoryBags()) do
            bags[#bags + 1] = {
                bagID = bagID,
                icon = GetBagButtonTexture(bagID),
                name = GetBagName(bagID),
                free = CountFreeSlots(bagID),
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

        local hidden = EnsureDatabase().hiddenBags[bag.bagID] == true
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
    local profile = GetCharacterProfile(key, character)
    local money = isCurrent and GetMoney()
        or profile.money
        or 0

    self.frame.money:SetText(FormatMoney(money))
end

function Module:UpdateTitle()
    if not self.frame or not self.frame.title then
        return
    end

    local key, character = GetViewedCharacter()
    local profile = GetCharacterProfile(key, character)
    local name = profile.name or "Unknown"
    local classFile = profile.classFile
    local classColor = Palette:GetClassColor(classFile)

    if classColor then
        name = string.format(
            "|cff%02x%02x%02x%s|r",
            math.floor(classColor.r * 255 + 0.5),
            math.floor(classColor.g * 255 + 0.5),
            math.floor(classColor.b * 255 + 0.5),
            name
        )
    end

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
        frame.liveInventory = false
        local activeButtons = {}
        local index = 0

        for _, bag in ipairs(character.bags or {}) do
            if not EnsureDatabase().hiddenBags[bag.bagID] then
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

    Styles:ApplyBackdrop(
        frame,
        Palette.window.inventory,
        Palette.windowBorder.inventory
    )

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    local header = Components:CreateWindowHeader(frame, {
        height = HEADER_HEIGHT,
        title = GetCurrentCharacterName() .. "'s Inventory",
        draggable = true,
        onDragStop = function()
            SavePosition(frame)
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
        SavePosition(frame)
    end)
    frame.titleButton = titleButton

    local search = CreateFrame("EditBox", nil, header, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", titleButton, "TOPLEFT", 0, -1)
    search:SetPoint("TOPRIGHT", titleButton, "TOPRIGHT", 0, -1)
    search:SetHeight(22)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)

    if search.SetPropagateKeyboardInput then
        search:SetPropagateKeyboardInput(false)
    end

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

    local close = CreateFrame("Button", nil, header)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -3, -2)
    close:SetNormalFontObject("GameFontNormal")
    close:SetHighlightFontObject("GameFontHighlight")
    close:SetText("x")
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
    characterMenu:SetBackdropBorderColor(unpack(Palette.windowBorder.inventory))
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

            local character = entry.profile
            local label = character.name or "Unknown"
            local classColor = Palette:GetClassColor(character.classFile)

            if classColor then
                label = string.format(
                    "|cff%02x%02x%02x%s|r",
                    math.floor(classColor.r * 255 + 0.5),
                    math.floor(classColor.g * 255 + 0.5),
                    math.floor(classColor.b * 255 + 0.5),
                    label
                )
            end

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

        for _, entry in ipairs(GetSortedMoneyCharacters()) do
            local character = entry.character
            local amount = character.money or 0
            local color = Palette:GetClassColor(character.classFile)
            local r = color and color.r or 0.75
            local g = color and color.g or 0.75
            local b = color and color.b or 0.75

            total = total + amount

            GameTooltip:AddDoubleLine(
                character.name or "Unknown",
                FormatMoney(amount),
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
            FormatMoney(total),
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

UI:RegisterCommand(
    "bags",
    "dbreset",
    function()
        local db = EnsureDatabase()

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
    EnsureDatabase()
    CleanupLegacyCharacterMetadata()
    SaveCurrentCharacter()

    self.frame = CreateFrameUI()

    local hotkeyButton = CreateFrame("Button", "KamiUIBagsHotkeyButton", UIParent)
    hotkeyButton:SetScript("OnClick", function()
        Module:Toggle()
    end)
    self.hotkeyButton = hotkeyButton

    if SetOverrideBindingClick then
        SetOverrideBindingClick(
            hotkeyButton,
            true,
            "B",
            "KamiUIBagsHotkeyButton",
            "LeftButton"
        )
    end

    self:UpdateBagBarVisibility()
    self:Rebuild()

    InstallBagHooks()
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

    UI:RegisterEvent("PLAYER_MONEY", function()
        local characters = GetCharactersModule()

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
