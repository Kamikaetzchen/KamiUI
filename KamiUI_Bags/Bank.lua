local UI = KamiUI

local Module = UI:NewModule("Bank")

Module.name = "KamiUI_Bank"
Module.version = "0.1.0"

local SLOT_SIZE = 36
local SLOT_SPACING = 3
local COLUMNS = 10
local FRAME_PADDING = 10
local HEADER_HEIGHT = 28
local FOOTER_HEIGHT = 24
local BAG_BAR_HEIGHT = 42

local defaults = {
    background = { 0.000, 0.314, 0.000, 0.25 },
    slotBackground = { 0.02, 0.02, 0.02, 0.55 },
    slotBorder = { 0.30, 0.24, 0.32, 0.90 },
    border = { 0.12, 0.28, 0.12, 1.00 },
}

local bagFamilyColors = {
    arrows = { 0.565, 0.000, 0.000, 1.00 },
    bullets = { 0.565, 0.000, 0.000, 1.00 },
    soul = { 0.55, 0.20, 0.75, 1.00 },
    leather = { 0.439, 0.188, 0.063, 1.00 },
    skinning = { 0.439, 0.188, 0.063, 1.00 },
    herbs = { 0.122, 0.420, 0.220, 1.00 },
    mining = { 0.38, 0.55, 0.68, 1.00 },
}

local bankOpen = false
local pendingRefresh = false
local sortingBank = false
local hiddenBankParent = CreateFrame("Frame")
hiddenBankParent:Hide()

local function EnsureDatabase()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.bags = KamiUIDB.bags or {}

    local db = KamiUIDB.bags
    db.characters = db.characters or {}
    db.bankHiddenTabs = db.bankHiddenTabs or {}

    if db.bankBagBarExpanded == nil then
        db.bankBagBarExpanded = false
    end

    return db
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
    local _, _, fullName = GetCurrentCharacterNames()
    local realm = GetRealmName() or ""

    return realm .. "::" .. fullName
end

local function GetCurrentCharacterName()
    local _, _, fullName = GetCurrentCharacterNames()

    return fullName
end

local function GetContainerNumSlots(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID) or 0
    end

    return 0
end

local function GetContainerItemInfo(bagID, slotID)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bagID, slotID)
    end
end

local function GetContainerNumFreeSlots(bagID)
    if C_Container and C_Container.GetContainerNumFreeSlots then
        return C_Container.GetContainerNumFreeSlots(bagID)
    end

    return 0, 0
end

local function HasBagFamilyFlag(value, flag)
    if not value or not flag or flag <= 0 then
        return false
    end

    return value % (flag * 2) >= flag
end

local function GetBagFamilyColorFromMask(family)
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
    local tabData

    if C_Bank
        and C_Bank.FetchPurchasedBankTabData
        and Enum
        and Enum.BankType
        and Enum.BankType.Character
    then
        tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
    end

    for _, entry in ipairs(GetCharacterBankBagIDs()) do
        local bagID = entry.bagID
        local slotCount = GetContainerNumSlots(bagID)

        if slotCount > 0 then
            local data = tabData and tabData[entry.index]
            local info
            local bankBagSlots = Enum
                and Enum.BagIndex
                and Enum.BagIndex.Characterbanktab

            if bankBagSlots and entry.index > 1 then
                info = GetContainerItemInfo(bankBagSlots, entry.index)
            end

            local _, family = GetContainerNumFreeSlots(bagID)

            tabs[#tabs + 1] = {
                bagID = bagID,
                index = entry.index,
                name = data and data.name
                    or (entry.index == 1 and "Bank" or "Bank Bag " .. entry.index - 1),
                icon = info and info.iconFileID
                    or (data and data.icon)
                    or "Interface\\Icons\\INV_Misc_Bag_10",
                family = family or 0,
                slotCount = slotCount,
            }
        end
    end

    return tabs
end

local function CountFreeSlots(bagID)
    local free = 0

    for slotID = 1, GetContainerNumSlots(bagID) do
        if not GetContainerItemInfo(bagID, slotID) then
            free = free + 1
        end
    end

    return free
end

local function SavePosition(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not frameX or not frameY or not parentX or not parentY then
        return
    end

    EnsureDatabase().bankPosition = {
        x = frameX - parentX,
        y = frameY - parentY,
    }
end

local function ApplySavedPosition(frame)
    local position = EnsureDatabase().bankPosition

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
        frame:SetPoint("CENTER", UIParent, "CENTER", -280, 0)
    end
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

local function SaveCurrentBank()
    if not bankOpen then
        return
    end

    local db = EnsureDatabase()
    local key = GetCurrentCharacterKey()
    local firstName, surname, fullName = GetCurrentCharacterNames()
    local _, classFile = UnitClass("player")
    local character = db.characters[key] or {}

    character.name = fullName
    character.firstName = firstName
    character.surname = surname
    character.classFile = classFile
    character.realm = GetRealmName() or ""
    character.money = GetMoney() or character.money or 0
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
            local info = GetContainerItemInfo(tab.bagID, slotID)

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

local function StyleItemButton(button)
    if button.KamiStyled then
        return
    end

    button.KamiStyled = true
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    if button.NormalTexture then
        button.NormalTexture:SetAlpha(0)
        button.NormalTexture:Hide()
    end

    if button.IconBorder then
        button.IconBorder:SetAlpha(0)
    end

    if button.NewItemTexture then
        button.NewItemTexture:SetAlpha(0)
    end

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(defaults.slotBackground))
    button.KamiBackground = background

    local top = button:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = button:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = button:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = button:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    button.KamiBorders = { top, bottom, left, right }

    local rarityTop = button:CreateTexture(nil, "BORDER", nil, 1)
    rarityTop:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    rarityTop:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    rarityTop:SetHeight(1)

    local rarityBottom = button:CreateTexture(nil, "BORDER", nil, 1)
    rarityBottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    rarityBottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    rarityBottom:SetHeight(1)

    local rarityLeft = button:CreateTexture(nil, "BORDER", nil, 1)
    rarityLeft:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    rarityLeft:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    rarityLeft:SetWidth(1)

    local rarityRight = button:CreateTexture(nil, "BORDER", nil, 1)
    rarityRight:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    rarityRight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    rarityRight:SetWidth(1)

    button.KamiRarityBorders = {
        rarityTop,
        rarityBottom,
        rarityLeft,
        rarityRight,
    }

    for _, border in ipairs(button.KamiRarityBorders) do
        border:Hide()
    end

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
    local color = quality ~= nil
        and ITEM_QUALITY_COLORS
        and ITEM_QUALITY_COLORS[quality]

    for _, border in ipairs(button.KamiRarityBorders or {}) do
        if color then
            border:SetColorTexture(color.r, color.g, color.b, 1)
            border:Show()
        else
            border:Hide()
        end
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
                local bagID = button:GetParent():GetID()
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
                    local bagID = button:GetParent():GetID()
                    local slotID = button:GetID()

                    C_Container.PickupContainerItem(bagID, slotID)
                    return
                end
            end
        end
    end
end)

local function CreateCarrier(content, bagID)
    local carrier = CreateFrame("Frame", nil, content)
    carrier:SetAllPoints(content)
    carrier:SetID(bagID)

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

local function UpdateItemButton(button, bagID, slotID, family)
    button:SetID(slotID)

    local color = GetBagFamilyColorFromMask(family)

    for _, border in ipairs(button.KamiBorders or {}) do
        border:SetColorTexture(unpack(color))
    end

    if ContainerFrameItemButton_Update then
        ContainerFrameItemButton_Update(button)
    end

    SuppressNewItemFlash(button)

    local info = GetContainerItemInfo(bagID, slotID)
    local icon = button.icon or button.Icon

    if info then
        UpdateRarityBorder(button, info.quality)

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
        UpdateRarityBorder(button, nil)
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

local function UpdateCachedItemButton(button, slot, tab)
    local color = GetBagFamilyColorFromMask(tab.family)

    for _, border in ipairs(button.KamiBorders or {}) do
        border:SetColorTexture(unpack(color))
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
        local haystack = string.lower(slot.name or slot.link or "")
        button:SetAlpha(
            string.find(haystack, string.lower(search), 1, true)
                and 1.00
                or 0.20
        )
    else
        button:SetAlpha(1)
    end
end

local function CreateBankBagButton(parent)
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

        local db = EnsureDatabase()
        db.bankHiddenTabs[self.bagID] = not db.bankHiddenTabs[self.bagID]
        Module:Rebuild()
    end)

    button:SetScript("OnDragStart", PickupBankBag)
    button:SetScript("OnReceiveDrag", PickupBankBag)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tabName or "Bank")
        GameTooltip:AddLine("Click: show/hide bank bag", 0.75, 0.75, 0.75)

        if not self.isCached and self.tabIndex and self.tabIndex > 1 then
            GameTooltip:AddLine("Drag: equip/swap bank bag", 0.75, 0.75, 0.75)
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
        button.icon:SetTexture(tab.icon)

        local free

        if isCurrent and bankOpen then
            free = CountFreeSlots(tab.bagID)
        else
            local used = 0

            for slotID = 1, tab.slotCount or 0 do
                if tab.slots and tab.slots[slotID] then
                    used = used + 1
                end
            end

            free = math.max(0, (tab.slotCount or 0) - used)
        end

        button.count:SetText(free)

        local hidden = EnsureDatabase().bankHiddenTabs[tab.bagID] == true
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
    local classFile = isCurrent and select(2, UnitClass("player"))
        or (character and character.classFile)
    local color = classFile
        and RAID_CLASS_COLORS
        and RAID_CLASS_COLORS[classFile]

    if color then
        name = string.format(
            "|cff%02x%02x%02x%s|r",
            math.floor(color.r * 255 + 0.5),
            math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5),
            name
        )
    end

    self.frame.title:SetText(name .. "'s Bank")
end

function Module:Layout()
    local frame = self.frame

    if not frame then
        return
    end

    local buttons = frame.activeButtons or {}
    local rows = math.max(1, math.ceil(#buttons / COLUMNS))
    local bagBarOffset = EnsureDatabase().bankBagBarExpanded
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

    local expanded = EnsureDatabase().bankBagBarExpanded

    frame.bagBar:SetShown(expanded)
    frame.bagBarToggle:SetText(expanded and "Bags -" or "Bags +")

    self:Layout()
end

function Module:SetViewedCharacter(key)
    local currentKey = GetCurrentCharacterKey()

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
            if not EnsureDatabase().bankHiddenTabs[tab.bagID] then
                for slotID = 1, tab.slotCount or 0 do
                    index = index + 1

                    local button = frame.cachedButtons[index]

                    if not button then
                        button = CreateCachedItemButton(frame.content)
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
        if not EnsureDatabase().bankHiddenTabs[tab.bagID] then
            local carrier = frame.carriers[tab.bagID]

            if not carrier then
                carrier = CreateCarrier(frame.content, tab.bagID)
                frame.carriers[tab.bagID] = carrier
            end

            carrier:SetID(tab.bagID)

            for slotID = 1, tab.slotCount do
                index = index + 1

                local button = frame.itemButtons[index]

                if not button or button:GetParent() ~= carrier then
                    button = CreateItemButton(frame.content, carrier)
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
    title:SetText(GetCurrentCharacterName() .. "'s Bank")
    title:SetTextColor(0.88, 1.00, 0.88)
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
    characterMenu:SetBackdropColor(0.02, 0.08, 0.02, 0.95)
    characterMenu:SetBackdropBorderColor(unpack(defaults.border))
    characterMenu.buttons = {}
    characterMenu:Hide()
    frame.characterMenu = characterMenu

    local function RebuildCharacterMenu()
        local height = 6
        local index = 0

        for _, entry in ipairs(GetSortedCharacters()) do
            local character = entry.character

            if character.bank then
                index = index + 1

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

                local label = character.name or "Unknown"
                local color = character.classFile
                    and RAID_CLASS_COLORS
                    and RAID_CLASS_COLORS[character.classFile]

                if color then
                    label = string.format(
                        "|cff%02x%02x%02x%s|r",
                        math.floor(color.r * 255 + 0.5),
                        math.floor(color.g * 255 + 0.5),
                        math.floor(color.b * 255 + 0.5),
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
        end

        for i = index + 1, #characterMenu.buttons do
            characterMenu.buttons[i]:Hide()
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
    bagBarToggle:SetPoint("LEFT", characterButton, "RIGHT", 4, 0)
    bagBarToggle:SetNormalFontObject("GameFontNormalSmall")
    bagBarToggle:SetHighlightFontObject("GameFontHighlightSmall")
    bagBarToggle:SetScript("OnClick", function()
        local db = EnsureDatabase()
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
    sort:SetScript("OnClick", function()
        if sortingBank then
            return
        end

        sortingBank = true
        sort:Disable()

        if C_Container and C_Container.SortBankBags then
            C_Container.SortBankBags()
        elseif SortBankBags then
            SortBankBags()
        end

        C_Timer.After(0.35, function()
            sortingBank = false
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

        for _, entry in ipairs(GetSortedCharacters()) do
            local character = entry.character
            local amount = character.money or 0
            local color = character.classFile
                and RAID_CLASS_COLORS
                and RAID_CLASS_COLORS[character.classFile]
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

    ApplySavedPosition(frame)

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
    EnsureDatabase().bankPosition = nil

    if self.frame then
        ApplySavedPosition(self.frame)
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
eventFrame:RegisterEvent("BAG_CONTAINER_UPDATE")
eventFrame:RegisterEvent("PLAYER_MONEY")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then
        bankOpen = true

        if BankFrame then
            BankFrame:SetParent(hiddenBankParent)
        end

        Module:Show()
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
    EnsureDatabase()
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
