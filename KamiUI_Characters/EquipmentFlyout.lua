local UI = KamiUI
local Module = UI:GetModule("Characters")
local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

-- Slot flyouts use the same palette, popup rows and item rarity colors as
-- the rest of KamiUI. Only carried equipment is offered (not cached alts).
local WIDTH = 218
local ROW_HEIGHT = 30
local MAX_ITEMS = 7
local OPTIONS = {
    width = WIDTH,
    rowHeight = ROW_HEIGHT,
    inset = 4,
    fontSize = 10,
    textColor = Palette.text,
    backgroundColor = { 0.005, 0.008, 0.015, 0.94 },
    borderColor = Palette.border,
    frameStrata = "DIALOG",
}
local EQUIP_LOCS = {
    HeadSlot = { INVTYPE_HEAD = true },
    NeckSlot = { INVTYPE_NECK = true },
    ShoulderSlot = { INVTYPE_SHOULDER = true },
    BackSlot = { INVTYPE_CLOAK = true },
    ChestSlot = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
    ShirtSlot = { INVTYPE_BODY = true },
    TabardSlot = { INVTYPE_TABARD = true },
    WristSlot = { INVTYPE_WRIST = true },
    HandsSlot = { INVTYPE_HAND = true },
    WaistSlot = { INVTYPE_WAIST = true },
    LegsSlot = { INVTYPE_LEGS = true },
    FeetSlot = { INVTYPE_FEET = true },
    Finger0Slot = { INVTYPE_FINGER = true },
    Finger1Slot = { INVTYPE_FINGER = true },
    Trinket0Slot = { INVTYPE_TRINKET = true },
    Trinket1Slot = { INVTYPE_TRINKET = true },
    MainHandSlot = {
        INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,
        INVTYPE_2HWEAPON = true,
    },
    SecondaryHandSlot = {
        INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true,
        INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
    },
    RangedSlot = {
        INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
        INVTYPE_THROWN = true, INVTYPE_RELIC = true,
    },
    AmmoSlot = { INVTYPE_AMMO = true },
}

local menu
local activeSlot
local offset = 0
local sourcePickedUp = false
local entries = {}

local function Locked()
    return InCombatLockdown and InCombatLockdown()
end

local function CursorHasItem()
    if not GetCursorInfo then return false end
    local kind = UI:SafeCall(GetCursorInfo)
    return UI:CanAccessValue(kind) and kind == "item"
end

local function ItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return UI:SafeCall(C_Container.GetContainerItemLink, bag, slot)
    end
    if GetContainerItemLink then
        return UI:SafeCall(GetContainerItemLink, bag, slot)
    end
end

local function ItemInfo(link, id)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local getInstant = (C_Item and C_Item.GetItemInfoInstant)
        or GetItemInfoInstant

    local name, quality, level, loc, icon
    if getInfo then
        local n, _, q, ilvl, _, _, _, _, equipLoc, texture =
            UI:SafeCall(getInfo, link or id)
        name, quality, level, loc, icon =
            n, q, ilvl, equipLoc, texture
    end

    if getInstant then
        local _, _, _, instantLoc, instantIcon =
            UI:SafeCall(getInstant, link or id)
        loc = loc or instantLoc
        icon = icon or instantIcon
    end

    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        UI:SafeCall(C_Item.RequestLoadItemDataByID, id)
    end

    return name, quality, level, loc, icon
end

local function ScanSlot(slotKey)
    local accepted = EQUIP_LOCS[slotKey]
    local found = {}
    if not accepted then return found end

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, UI:GetContainerNumSlots(bag) do
            local info = UI:GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if not id and C_Container and C_Container.GetContainerItemID then
                id = UI:SafeCall(C_Container.GetContainerItemID, bag, slot)
            end
            if id and UI:CanAccessValue(id) then
                local link = ItemLink(bag, slot)
                if link and UI:CanAccessValue(link) then
                    local name, quality, level, loc, icon =
                        ItemInfo(link, id)
                    if accepted[loc] and name then
                        found[#found + 1] = {
                            bag = bag,
                            slot = slot,
                            id = id,
                            link = link,
                            name = name,
                            icon = icon,
                            quality = quality or 1,
                            level = level or 0,
                        }
                    end
                end
            end
        end
    end

    table.sort(found, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return found
end

local function GetEmptyBagSlot()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local free, bagFamily
        if C_Container and C_Container.GetContainerNumFreeSlots then
            free, bagFamily = UI:SafeCall(
                C_Container.GetContainerNumFreeSlots, bag)
        elseif GetContainerNumFreeSlots then
            free, bagFamily = UI:SafeCall(GetContainerNumFreeSlots, bag)
        end
        -- Specialty bags may refuse gear. Use backpack or normal bags.
        if (bag == 0 or bagFamily == 0)
            and (free == nil or (UI:CanAccessValue(free) and free > 0))
        then
            for slot = 1, UI:GetContainerNumSlots(bag) do
                local info = UI:GetContainerItemInfo(bag, slot)
                if not info then return bag, slot end
            end
        end
    end
end

local function PlaceCursorInBag(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        PickupContainerItem(bag, slot)
    end
end

local function Close()
    if menu then menu:Hide() end
    activeSlot = nil
    sourcePickedUp = false
end

local function FinishSelection()
    Close()
    if Module.Refresh then
        C_Timer.After(0, function()
            if Module.frame and Module.frame:IsShown() then
                Module:Refresh()
            end
        end)
    end
end

local function SelectItem(entry)
    if Locked() or not activeSlot then return end
    local slot = activeSlot
    -- Left-clicking an equipped item picks it up as before. Put that
    -- specific item back first, then use Blizzard's equipment swap API;
    -- it returns the replaced item to a free bag location itself.
    if sourcePickedUp and CursorHasItem() and PickupInventoryItem then
        PickupInventoryItem(slot.slotID)
    elseif CursorHasItem() then
        UI:Print("Place the item on your cursor first.")
        return
    end

    local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if not equip then
        UI:Print("Equipment swapping is unavailable.")
        return
    end
    equip(entry.link, slot.slotID)
    FinishSelection()
end

local function Unequip()
    if Locked() or not activeSlot then return end
    local slot = activeSlot
    local bag, bagSlot = GetEmptyBagSlot()
    if not bag then
        UI:Print("No empty bag slot to unequip this item.")
        return
    end

    if not sourcePickedUp then
        if CursorHasItem() then
            UI:Print("Place the item on your cursor first.")
            return
        end
        if not GetInventoryItemLink("player", slot.slotID) then
            FinishSelection()
            return
        end
        PickupInventoryItem(slot.slotID)
    end

    if not CursorHasItem() then
        FinishSelection()
        return
    end
    PlaceCursorInBag(bag, bagSlot)
    if CursorHasItem() then
        UI:Print("Could not move the item into that bag slot.")
        return
    end
    FinishSelection()
end

local function EnsureRow(index)
    local row = Components:AcquirePopupMenuButton(menu, index, OPTIONS)
    if row.KamiEquipmentFlyoutStyled then return row end
    row.KamiEquipmentFlyoutStyled = true

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(25, 25)
    row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 34, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -38, 0)

    row.itemLevel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.itemLevel:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.itemLevel:SetWidth(32)
    row.itemLevel:SetJustifyH("RIGHT")
    Styles:ApplyText(row.itemLevel, 9, Palette.muted)

    row:SetScript("OnEnter", function(self)
        if self.itemEntry and self.itemEntry.link then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemEntry.link)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return row
end

local function RowItem(row, entry)
    row.icon:SetTexture(entry.icon)
    row.text:SetText(entry.name)
    local color = ITEM_QUALITY_COLORS
        and ITEM_QUALITY_COLORS[entry.quality]
    if color then
        row.text:SetTextColor(color.r, color.g, color.b)
    else
        Styles:SetTextColor(row.text, Palette.text)
    end
    row.itemLevel:SetText(tostring(entry.level))
    row.itemEntry = entry
    row:SetScript("OnClick", function()
        SelectItem(entry)
    end)
    row:Show()
end

local function Render()
    if not menu or not activeSlot then return end
    local paged = #entries > MAX_ITEMS
    local first = paged and 2 or 1
    local rowIndex = 0

    if paged then
        local nav = EnsureRow(1)
        nav.icon:SetTexture(nil)
        nav.itemEntry = nil
        nav.text:SetText(string.format("   \226\150\178  %d-%d / %d   \226\150\188",
            offset + 1, math.min(offset + MAX_ITEMS, #entries), #entries))
        Styles:SetTextColor(nav.text, Palette.gold)
        nav.itemLevel:SetText("")
        nav:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then
                offset = math.max(0, offset - MAX_ITEMS)
            else
                offset = math.min(
                    math.max(0, #entries - MAX_ITEMS), offset + MAX_ITEMS)
            end
            Render()
        end)
        nav:Show()
        rowIndex = 1
    end

    for i = 1, math.min(MAX_ITEMS, #entries - offset) do
        rowIndex = rowIndex + 1
        RowItem(EnsureRow(first + i - 1), entries[offset + i])
    end

    -- Always the last button, even when the list is scrolled.
    rowIndex = rowIndex + 1
    local empty = EnsureRow(rowIndex)
    empty.itemEntry = nil
    empty.icon:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
    empty.text:SetText("Unequip / Empty slot")
    Styles:SetTextColor(empty.text, Palette.muted)
    empty.itemLevel:SetText("")
    empty:SetScript("OnClick", Unequip)
    empty:Show()

    Components:FinishPopupMenu(menu, rowIndex, OPTIONS)
end

local function EnsureMenu(anchor)
    if menu then return menu end
    menu = Components:CreatePopupMenu(UIParent, anchor, OPTIONS)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(200)
    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(_, delta)
        if #entries <= MAX_ITEMS then return end
        offset = math.max(0, math.min(#entries - MAX_ITEMS, offset - delta))
        Render()
    end)
    return menu
end

function Module:CloseEquipmentFlyout()
    Close()
end

function Module:ToggleEquipmentFlyout(button, pickedUp)
    if not button or not button.slotID or Locked() then return end
    local _, _, isCurrent = self:GetViewedCharacter()
    if not isCurrent or not self.frame or not self.frame:IsShown()
        or self.frame.page ~= "character" then
        return
    end
    if menu and menu:IsShown() and activeSlot == button then
        Close()
        return
    end
    Close()

    activeSlot = button
    sourcePickedUp = pickedUp == true
    offset = 0
    entries = ScanSlot(button.slotKey)
    local popup = EnsureMenu(button)

    popup:ClearAllPoints()
    local side = button.KamiEquipmentSide
    if side == "LEFT" then
        popup:SetPoint("TOPLEFT", button, "TOPRIGHT", 3, 0)
    elseif side == "RIGHT" then
        popup:SetPoint("TOPRIGHT", button, "TOPLEFT", -3, 0)
    else
        popup:SetPoint("BOTTOM", button, "TOP", 0, 4)
    end
    Render()
    popup:Show()
end

function Module:RefreshEquipmentFlyout()
    if not activeSlot or not menu or not menu:IsShown() then return end
    if Locked() then Close() return end
    entries = ScanSlot(activeSlot.slotKey)
    offset = math.min(offset, math.max(0, #entries - MAX_ITEMS))
    Render()
end

-- Gear flyouts must not outlive the character sheet or an instance combat
-- lockdown. Refresh only while visible, so bag changes stay inexpensive.
UI:RegisterEvent("PLAYER_REGEN_DISABLED", Close)
UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
    Module:RefreshEquipmentFlyout()
end)
UI:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
    Module:RefreshEquipmentFlyout()
end)
if Module.frame then
    Module.frame:HookScript("OnHide", Close)
end
