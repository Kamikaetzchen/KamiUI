local UI = KamiUI
local Module = UI:GetModule("Characters")

-- Outfitter-style auto equipment, without Blizzard equipment sets.
-- Mounted: Carrot on a Stick (11122) takes precedence in slot 14.
-- Plaguelands: Seal/Rune of the Dawn or Argent Dawn Commission.
-- Enchanted riding gloves and spurred boots are mounted-only.
local CARROT_ID = 11122
-- Stronger Argent Dawn trinkets from The Active Agent and Naxxramas
-- retain the Commission effect. Prefer physical damage for Feral.
local DAWN_TRINKETS = {
    23206, -- Mark of the Champion (attack power)
    13209, -- Seal of the Dawn (attack power)
    23207, -- Mark of the Champion (spell power)
    19812, -- Rune of the Dawn (spell power)
    12846, -- Argent Dawn Commission
}
local PLAGUELAND_MAPS = {
    [22] = true, [23] = true, -- Western/Eastern Plaguelands
    [306] = true, [307] = true, -- Scholomance floors
    [308] = true, [309] = true,
    [317] = true, [318] = true, -- Stratholme wings
    [476] = true, [477] = true, -- Alternate Scholomance UI maps
    [478] = true, [479] = true,
}
local PLAGUELAND_INSTANCES = {
    [289] = true, -- Scholomance
    [329] = true, -- Stratholme
}
local RIDING_GLOVE_ENCHANT = 930
local MITHRIL_SPURS_ENCHANT = 464
local QUEUE_KEY = "characters.autoEquipment"
local SWAP_TIMEOUT = 1.5

-- Slot 14 is handled separately so mounted and zone rules cannot
-- compete. This list only contains mounted-only riding enchants.
local EQUIPMENT = {
    { key = "HandsSlot", enchantID = RIDING_GLOVE_ENCHANT },
    { key = "FeetSlot", enchantID = MITHRIL_SPURS_ENCHANT },
}

local pending = {}
local suppressed = {}
local restoreBlocked = {}
local lastMounted
local lastPlaguelands
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

-- Prefer zone map IDs over localized zone strings. The parent
-- traversal handles submaps such as Light's Hope Chapel (map 24).
local function IsInPlaguelands()
    -- Zone map IDs may differ inside an instance. The physical
    -- instance IDs provide another check on Forever.
    if GetInstanceInfo then
        local _, instanceType, _, _, _, _, _, instanceID =
            UI:SafeCall(GetInstanceInfo)
        if instanceType == "party" or instanceType == "raid" then
            -- Do not equip the badge in unrelated instances whose
            -- map ancestry also happens to point to the Plaguelands.
            return UI:CanAccessValue(instanceID)
                and PLAGUELAND_INSTANCES[instanceID] == true
        end
    end

    if C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetMapInfo then
        local mapID = UI:SafeCall(
            C_Map.GetBestMapForUnit, "player"
        )
        local visited = {}
        for _ = 1, 8 do
            if not UI:CanAccessValue(mapID)
                or type(mapID) ~= "number"
                or visited[mapID] then
                break
            end
            if PLAGUELAND_MAPS[mapID] then return true end
            visited[mapID] = true
            local info = UI:SafeCall(C_Map.GetMapInfo, mapID)
            if not info or not UI:CanAccessValue(info) then
                break
            end
            mapID = info.parentMapID
        end
    end

    -- Forever may report other map IDs for Classic zones.
    local zone = GetRealZoneText and UI:SafeCall(GetRealZoneText)
        or GetZoneText and UI:SafeCall(GetZoneText)
    return UI:CanAccessValue(zone) and (
        zone == "Western Plaguelands"
        or zone == "Eastern Plaguelands"
        or zone == "Westliche Pestländer"
        or zone == "Östliche Pestländer"
        or zone == "Scholomance"
        or zone == "Stratholme"
    ) or false
end

local function FindBestDawnTrinket(current)
    for _, itemID in ipairs(DAWN_TRINKETS) do
        if ItemID(current) == itemID then
            return current
        end
        local candidate = FindInBags({ itemID = itemID })
        if candidate then return candidate end
    end
end

local function GetRecords()
    local _, character = Module:GetCurrentCharacter()
    if not character then return nil end

    -- Migrate the previous saved mountEquipment slot records without
    -- losing the original gear link on reload while mounted.
    local legacy = character.mountEquipment
    if type(character.autoEquipment) ~= "table" then
        character.autoEquipment =
            type(legacy) == "table" and legacy or {}
    elseif type(legacy) == "table" then
        for slot, record in pairs(legacy) do
            if character.autoEquipment[slot] == nil then
                character.autoEquipment[slot] = record
            end
        end
    end
    character.mountEquipment = nil

    -- Saved per character: /reload or relog while mounted must not
    -- lose the original items needed for the next dismount.
    return character.autoEquipment
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

-- A single state machine owns Trinket1Slot (slot 14).
-- This keeps the saved original item across transitions such as
-- normal -> Plaguelands -> mounted -> dismounted -> normal.
-- The legacy record fields remain compatible with pre-upgrade saves.
local function RunTrinket(records, mounted, inPlaguelands, enabled, now)
    local slot = GetInventorySlotInfo
        and UI:SafeCall(GetInventorySlotInfo, "Trinket1Slot")
    if not UI:CanAccessValue(slot)
        or type(slot) ~= "number" then
        return
    end

    local current = Equipped(slot)
    local record = records[slot]
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
            return
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

    -- Respect manual trinket changes for this mount/zone session.
    if record and not SameItem(current, record.riding) then
        records[slot] = nil
        record = nil
        suppressed[slot] = true
    end

    local desired
    if enabled then
        local slot13 = GetInventorySlotInfo
            and UI:SafeCall(GetInventorySlotInfo, "Trinket0Slot")
        local other = UI:CanAccessValue(slot13)
            and type(slot13) == "number" and Equipped(slot13)

        -- Already wearing the Carrot in slot 13 counts as mounted gear.
        if mounted and ItemID(other) ~= CARROT_ID then
            if ItemID(current) == CARROT_ID then
                desired = current
            else
                desired = FindInBags({ itemID = CARROT_ID })
            end
        end

        if not desired and inPlaguelands then
            -- The Argent badge only needs to be equipped in one slot.
            local otherHasDawn = false
            for _, id in ipairs(DAWN_TRINKETS) do
                if ItemID(other) == id then
                    otherHasDawn = true
                    break
                end
            end
            if not otherHasDawn then
                desired = FindBestDawnTrinket(current)
            end
        end
    end

    if desired then
        if SameItem(current, desired) or suppressed[slot] then
            return
        end

        if record then
            local old = record.riding
            record.riding = desired
            if not StartSwap(slot, desired, "mount") then
                record.riding = old
                suppressed[slot] = true
            end
        else
            records[slot] = {
                previous = current or false,
                riding = desired,
            }
            if not StartSwap(slot, desired, "mount") then
                records[slot] = nil
                suppressed[slot] = true
            end
        end
    elseif record and not restoreBlocked[slot] then
        if SameItem(current, record.previous) then
            -- No action needed when the original is already equipped.
            records[slot] = nil
        elseif not StartSwap(slot, record.previous, "restore") then
            restoreBlocked[slot] = true
        end
    end
end

local function Run()
    if Locked() then
        UI:RunOutOfCombat(QUEUE_KEY, Run)
        return
    end
    UI:CancelOutOfCombat(QUEUE_KEY)

    -- When disabled, restore only items installed by this module.
    -- Unreadable mount state must not trigger an incorrect swap.
    local enabled = Module:IsAutoEquipEnabled()
    local mounted = false
    if enabled then
        if not IsMounted then return end
        mounted = UI:SafeCall(IsMounted)
        if not UI:CanAccessValue(mounted)
            or type(mounted) ~= "boolean" then
            return
        end
    end
    local records = GetRecords()
    if not records then return end

    local inPlaguelands = enabled and IsInPlaguelands() or false
    if lastMounted ~= mounted
        or lastPlaguelands ~= inPlaguelands then
        suppressed = {}
        restoreBlocked = {}
        lastMounted = mounted
        lastPlaguelands = inPlaguelands
    end

    local now = GetTime and GetTime() or 0
    RunTrinket(records, mounted, inPlaguelands, enabled, now)

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

function Module:RefreshAutoEquipment()
    Refresh()
end

-- Compatibility with the previous Mount Gear implementation.
Module.RefreshMountEquipment = Module.RefreshAutoEquipment

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
UI:RegisterEvent("ZONE_CHANGED_NEW_AREA", Refresh)
UI:RegisterEvent("ZONE_CHANGED", Refresh)
UI:RegisterEvent("ZONE_CHANGED_INDOORS", Refresh)
UI:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Refresh)
UI:RegisterEvent("PLAYER_REGEN_ENABLED", Refresh)
UI:RegisterEvent("UNIT_AURA", function(_, unit)
    if unit == "player" then Refresh() end
end)
UI:RegisterEvent("BAG_UPDATE_DELAYED", function()
    restoreBlocked = {}
    Refresh()
end)
