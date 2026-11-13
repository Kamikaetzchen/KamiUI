local UI = KamiUI
local Module = UI:GetModule("Characters")

-- Outfitter-style riding gear, without Blizzard equipment sets.
-- Item 11122: Carrot on a Stick (+3%).
-- Permanent enchant 930: Riding Skill on gloves (+2%).
-- Permanent enchant 464: Mithril Spurs on boots (+4%).
-- Only equipped bonuses are relevant; loose spurs/enchant recipes are ignored.
local CARROT_ID = 11122
local RIDING_GLOVE_ENCHANT = 930
local MITHRIL_SPURS_ENCHANT = 464
local QUEUE_KEY = "characters.mountEquipment"
local SWAP_TIMEOUT = 1.5

local EQUIPMENT = {
    { key = "Trinket1Slot", itemID = CARROT_ID },
    { key = "HandsSlot", enchantID = RIDING_GLOVE_ENCHANT },
    { key = "FeetSlot", enchantID = MITHRIL_SPURS_ENCHANT },
}

local pending = {}
local suppressed = {}
local restoreBlocked = {}
local lastMounted
local refreshScheduled = false
local Refresh

local function Locked()
    return InCombatLockdown and InCombatLockdown()
end

local function AccessibleString(value)
    return UI:CanAccessValue(value) and type(value) == "string"
end

local function ItemPayload(link)
    if not AccessibleString(link) then return nil end
    return link:match("|H(item:[^|]+)|h")
        or link:match("^(item:[^|]+)")
end

local function SameItem(a, b)
    if not a or a == false then
        return not b or b == false
    end
    if not b or b == false then return false end
    if not AccessibleString(a) or not AccessibleString(b) then
        return false
    end
    if a == b then return true end
    local payloadA, payloadB = ItemPayload(a), ItemPayload(b)
    return payloadA and payloadB and payloadA == payloadB or false
end

local function ItemID(link)
    return tonumber((ItemPayload(link) or ""):match("^item:(%d+)"))
end

local function EnchantID(link)
    return tonumber((ItemPayload(link) or ""):match("^item:%d+:(%-?%d+)"))
end

local function MatchesRidingItem(link, definition)
    if not link then return false end
    if definition.itemID then
        return ItemID(link) == definition.itemID
    end
    return EnchantID(link) == definition.enchantID
end

local function Equipped(slot)
    if not GetInventoryItemLink then return nil end
    local link = UI:SafeCall(GetInventoryItemLink, "player", slot)
    return AccessibleString(link) and link or nil
end

local function BagLink(bag, slot)
    local getter = C_Container and C_Container.GetContainerItemLink
        or GetContainerItemLink
    if not getter then return nil end
    local link = UI:SafeCall(getter, bag, slot)
    return AccessibleString(link) and link or nil
end

local function FindInBags(definition)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, UI:GetContainerNumSlots(bag) do
            local link = BagLink(bag, slot)
            if link and MatchesRidingItem(link, definition) then
                return link
            end
        end
    end
end

local function GetRecords()
    local _, character = Module:GetCurrentCharacter()
    if not character then return nil end
    if type(character.mountEquipment) ~= "table" then
        character.mountEquipment = {}
    end
    -- Saved per character: /reload or relog while mounted must not
    -- lose the original items needed for the next dismount.
    return character.mountEquipment
end

local function CursorOccupied()
    if not GetCursorInfo then return false end
    local kind = UI:SafeCall(GetCursorInfo)
    return UI:CanAccessValue(kind) and kind ~= nil
end

local function FindEmptyBagSlot()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local family
        if C_Container and C_Container.GetContainerNumFreeSlots then
            local _, value = UI:SafeCall(
                C_Container.GetContainerNumFreeSlots, bag
            )
            family = value
        elseif GetContainerNumFreeSlots then
            local _, value = UI:SafeCall(GetContainerNumFreeSlots, bag)
            family = value
        end
        if bag == 0 or (UI:CanAccessValue(family) and family == 0) then
            for slot = 1, UI:GetContainerNumSlots(bag) do
                local info = UI:GetContainerItemInfo(bag, slot)
                local itemID = info and info.itemID
                if not itemID and C_Container
                    and C_Container.GetContainerItemID then
                    itemID = UI:SafeCall(
                        C_Container.GetContainerItemID, bag, slot
                    )
                end
                if UI:CanAccessValue(itemID) and not itemID then
                    return bag, slot
                end
            end
        end
    end
end

local function UnequipToBag(slot)
    if not PickupInventoryItem or CursorOccupied() then
        return false
    end
    local bag, bagSlot = FindEmptyBagSlot()
    if not bag then return false end
    local place = C_Container and C_Container.PickupContainerItem
        or PickupContainerItem
    if not place then return false end

    local ok = pcall(PickupInventoryItem, slot)
    if not ok then return false end
    local placed = pcall(place, bag, bagSlot)
    if not placed or CursorOccupied() then
        -- Never leave the player's equipment dangling on the cursor.
        pcall(PickupInventoryItem, slot)
        return false
    end
    return true
end

local function RequestDelayedCheck()
    if C_Timer and C_Timer.After then
        C_Timer.After(SWAP_TIMEOUT, function()
            if Refresh then Refresh() end
        end)
    end
end

local function SwapInto(slot, link)
    local equip = C_Item and C_Item.EquipItemByName
        or EquipItemByName
    if not equip or CursorOccupied() then return false end
    local ok, result = pcall(equip, link, slot)
    return ok and result ~= false
end

local function StartSwap(slot, target, action)
    local ok
    if target == false then
        ok = UnequipToBag(slot)
    else
        ok = SwapInto(slot, target)
    end
    if ok then
        pending[slot] = {
            action = action,
            deadline = (GetTime and GetTime() or 0) + SWAP_TIMEOUT,
        }
        RequestDelayedCheck()
    end
    return ok
end

local function Run()
    if Locked() then
        UI:RunOutOfCombat(QUEUE_KEY, Run)
        return
    end
    UI:CancelOutOfCombat(QUEUE_KEY)

    -- Disabling the feature acts like dismounting: restore only equipment
    -- installed by this module, even if the character is still mounted.
    -- Do not require a readable mount state when the feature is disabled.
    local mounted = false
    if Module:IsMountGearEnabled() then
        if not IsMounted then return end
        mounted = UI:SafeCall(IsMounted)
        if not UI:CanAccessValue(mounted)
            or type(mounted) ~= "boolean" then
            return
        end
    end
    local records = GetRecords()
    if not records then return end

    if lastMounted ~= mounted then
        suppressed = {}
        restoreBlocked = {}
        lastMounted = mounted
    end

    local trinket0 = GetInventorySlotInfo
        and UI:SafeCall(GetInventorySlotInfo, "Trinket0Slot")
    local now = GetTime and GetTime() or 0

    for _, definition in ipairs(EQUIPMENT) do
        local slot = GetInventorySlotInfo
            and UI:SafeCall(GetInventorySlotInfo, definition.key)
        if slot and UI:CanAccessValue(slot) then
            local current = Equipped(slot)
            local record = records[slot]
            -- Ignore stale/malformed SavedVariables rather than passing
            -- an invalid link into a protected inventory operation.
            if record and (
                type(record) ~= "table"
                or not AccessibleString(record.riding)
                or (record.previous ~= false
                    and not AccessibleString(record.previous))
            ) then
                records[slot] = nil
                record = nil
            end
            local waiting = pending[slot]
            local skip = false

            if waiting then
                local complete = record and (
                    (waiting.action == "mount"
                        and SameItem(current, record.riding))
                    or (waiting.action == "restore"
                        and SameItem(current, record.previous))
                )
                if complete then
                    pending[slot] = nil
                    if waiting.action == "restore" then
                        records[slot] = nil
                        record = nil
                    end
                elseif now < waiting.deadline then
                    skip = true
                else
                    pending[slot] = nil
                    if waiting.action == "mount" then
                        records[slot] = nil
                        record = nil
                        suppressed[slot] = true
                    else
                        restoreBlocked[slot] = true
                    end
                end
            end

            if not skip then
                if mounted then
                    if record then
                        if not SameItem(current, record.riding) then
                            -- Someone changed equipment manually. Never
                            -- override their choice in this mount session.
                            records[slot] = nil
                            suppressed[slot] = true
                        end
                    elseif not suppressed[slot] then
                        local alreadyEquipped = MatchesRidingItem(
                            current, definition
                        )
                        if definition.itemID and trinket0
                            and UI:CanAccessValue(trinket0) then
                            alreadyEquipped = alreadyEquipped
                                or MatchesRidingItem(
                                    Equipped(trinket0), definition
                                )
                        end
                        if not alreadyEquipped then
                            local candidate = FindInBags(definition)
                            if candidate then
                                records[slot] = {
                                    previous = current or false,
                                    riding = candidate,
                                }
                                if not StartSwap(slot, candidate, "mount") then
                                    records[slot] = nil
                                    suppressed[slot] = true
                                end
                            end
                        end
                    end
                elseif record then
                    if SameItem(current, record.riding) then
                        if not restoreBlocked[slot] then
                            if not StartSwap(
                                slot, record.previous, "restore"
                            ) then
                                restoreBlocked[slot] = true
                            end
                        end
                    else
                        -- Already restored, or changed by the player:
                        -- the automation must not overwrite it.
                        records[slot] = nil
                    end
                end
            end
        end
    end
end

function Module:RefreshMountEquipment()
    Refresh()
end

Refresh = function()
    if Locked() then
        UI:RunOutOfCombat(QUEUE_KEY, Run)
        return
    end
    if refreshScheduled then return end
    refreshScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            refreshScheduled = false
            Run()
        end)
    else
        refreshScheduled = false
        Run()
    end
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", Refresh)
UI:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", Refresh)
UI:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Refresh)
UI:RegisterEvent("PLAYER_REGEN_ENABLED", Refresh)
UI:RegisterEvent("UNIT_AURA", function(_, unit)
    if unit == "player" then Refresh() end
end)
UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
    restoreBlocked = {}
    Refresh()
end)
