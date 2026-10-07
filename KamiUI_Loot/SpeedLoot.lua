local UI = KamiUI
local Module = UI:GetModule("Loot")

if not Module then
    return
end

local RETRY_DELAY = 0.05
local MAX_PASSES = 12
local MAX_STALLED_PASSES = 6

local state = {
    active = false,
    token = 0,
    pass = 0,
    stalledPasses = 0,
    lastRemaining = nil,
    retryQueued = false,
}

local function IsShiftDown()
    if not IsShiftKeyDown then
        return false
    end

    local down = IsShiftKeyDown()

    return UI:CanAccessValue(down) and down == true
end

local function GetAutoLootDefault()
    if GetCVarBool then
        local value = GetCVarBool("autoLootDefault")

        if UI:CanAccessValue(value) then
            return value == true or value == 1
        end
    end

    if GetCVar then
        local value = GetCVar("autoLootDefault")

        if UI:CanAccessValue(value) then
            return value == "1"
        end
    end

    return false
end

function Module:ShouldAutoLoot(autoLoot)
    -- KamiUI always treats Shift as "manual loot", independent of the
    -- game's normal auto-loot modifier behavior.
    if IsShiftDown() then
        return false
    end

    if autoLoot ~= nil and UI:CanAccessValue(autoLoot) then
        return autoLoot == true or autoLoot == 1
    end

    return GetAutoLootDefault()
end

local function GetItemID(link)
    if not link then
        return nil
    end

    if GetItemInfoInstant then
        local itemID = GetItemInfoInstant(link)

        if itemID then
            return itemID
        end
    end

    return tonumber(string.match(link, "item:(%d+)"))
end

local function HasCompatibleFreeSlot(link)
    local itemFamily = GetItemFamily
        and link
        and GetItemFamily(link)
        or 0

    if not UI:CanAccessValue(itemFamily) then
        itemFamily = 0
    end

    local firstBag = BACKPACK_CONTAINER or 0
    local lastBag = NUM_BAG_SLOTS or 4
    local bitLib = bit or bit32

    for bagID = firstBag, lastBag do
        local free, bagFamily = UI:GetContainerNumFreeSlots(bagID)

        if free and free > 0 then
            bagFamily = bagFamily or 0

            if bagFamily == 0 then
                return true
            end

            if itemFamily and itemFamily ~= 0 then
                if bitLib and bitLib.band then
                    if bitLib.band(itemFamily, bagFamily) ~= 0 then
                        return true
                    end
                else
                    -- If this client cannot compare bag-family masks,
                    -- fail open rather than incorrectly blocking loot.
                    return true
                end
            end
        end
    end

    return false
end

local function HasStackCapacity(link, quantity)
    if not link or not GetItemInfo then
        return false
    end

    local maxStack = select(8, GetItemInfo(link))

    if not maxStack
        or not UI:CanAccessValue(maxStack)
        or maxStack <= 1
    then
        return false
    end

    local itemID = GetItemID(link)

    if not itemID then
        return false
    end

    local capacity = 0
    local firstBag = BACKPACK_CONTAINER or 0
    local lastBag = NUM_BAG_SLOTS or 4

    for bagID = firstBag, lastBag do
        for slotID = 1, UI:GetContainerNumSlots(bagID) do
            local info = UI:GetContainerItemInfo(bagID, slotID)

            if info then
                local slotItemID = info.itemID
                    or GetItemID(info.hyperlink)

                if slotItemID == itemID then
                    local count = info.stackCount or 0

                    if count < maxStack then
                        capacity = capacity + (maxStack - count)

                        if capacity >= (quantity or 1) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

local function CanFitItem(link, quantity)
    if not link then
        return true
    end

    if HasStackCapacity(link, quantity) then
        return true
    end

    if HasCompatibleFreeSlot(link) then
        return true
    end

    return false
end

local function GetSlotState(slot)
    local texture,
        itemName,
        quantity,
        _,
        _,
        locked,
        isQuestItem = GetLootSlotInfo(slot)

    local slotType = GetLootSlotType and GetLootSlotType(slot)
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local exists = (slotType and slotType ~= 0)
        or texture ~= nil
        or itemName ~= nil
        or link ~= nil

    return {
        exists = exists,
        quantity = quantity or 1,
        locked = locked == true,
        isQuestItem = isQuestItem == true,
        slotType = slotType,
        link = link,
    }
end

local function CountRemainingLoot()
    local remaining = 0

    for slot = 1, GetNumLootItems() do
        if GetSlotState(slot).exists then
            remaining = remaining + 1
        end
    end

    return remaining
end

local function CanLootSlotNow(slotState)
    if slotState.locked then
        return false, true
    end

    if slotState.isQuestItem then
        return true, false
    end

    if LOOT_SLOT_ITEM
        and slotState.slotType == LOOT_SLOT_ITEM
        and not CanFitItem(
            slotState.link,
            slotState.quantity
        )
    then
        return false, false
    end

    return true, false
end

local function StopSpeedLoot(showRemaining)
    state.active = false
    state.token = state.token + 1
    state.retryQueued = false
    state.pass = 0
    state.stalledPasses = 0
    state.lastRemaining = nil

    if showRemaining and CountRemainingLoot() > 0 then
        Module:Show()
    end
end

local function ScheduleSweep(token)
    if state.retryQueued then
        return
    end

    state.retryQueued = true

    C_Timer.After(RETRY_DELAY, function()
        state.retryQueued = false

        if state.active and token == state.token then
            Module:RunSpeedLootPass(token)
        end
    end)
end

function Module:RunSpeedLootPass(token)
    if not state.active or token ~= state.token then
        return
    end

    if IsShiftDown() then
        StopSpeedLoot(true)
        return
    end

    local remaining = CountRemainingLoot()

    if remaining == 0 then
        StopSpeedLoot(false)
        return
    end

    if state.lastRemaining ~= nil then
        if remaining < state.lastRemaining then
            state.stalledPasses = 0
        else
            state.stalledPasses = state.stalledPasses + 1
        end
    end

    state.lastRemaining = remaining
    state.pass = state.pass + 1

    if state.pass > MAX_PASSES
        or state.stalledPasses >= MAX_STALLED_PASSES
    then
        StopSpeedLoot(true)
        return
    end

    local attempted = 0
    local locked = 0
    local blocked = 0

    for slot = GetNumLootItems(), 1, -1 do
        local slotState = GetSlotState(slot)

        if slotState.exists then
            local canLoot, isLocked = CanLootSlotNow(slotState)

            if canLoot then
                local ok = pcall(LootSlot, slot)

                if ok then
                    attempted = attempted + 1
                end
            elseif isLocked then
                locked = locked + 1
            else
                blocked = blocked + 1
            end
        end
    end

    if attempted == 0 and locked == 0 and blocked > 0 then
        StopSpeedLoot(true)
        return
    end

    ScheduleSweep(token)
end

function Module:StartSpeedLoot(autoLoot)
    if not self:ShouldAutoLoot(autoLoot) then
        if state.active then
            StopSpeedLoot(true)
        end

        return false
    end

    if state.active then
        return true
    end

    state.active = true
    state.token = state.token + 1
    state.pass = 0
    state.stalledPasses = 0
    state.lastRemaining = nil
    state.retryQueued = false

    self:Hide()
    self:RunSpeedLootPass(state.token)

    return true
end

local function DisableNativeAutoLoot()
    local frame = _G.LootFrame

    if frame
        and frame.UnregisterEvent
        and frame:IsEventRegistered("LOOT_OPENED")
    then
        frame:UnregisterEvent("LOOT_OPENED")
    end
end

DisableNativeAutoLoot()

UI:RegisterEvent("PLAYER_ENTERING_WORLD", DisableNativeAutoLoot)

UI:RegisterEvent("ADDON_LOADED", function()
    DisableNativeAutoLoot()
end)

UI:RegisterEvent("LOOT_READY", function(_, autoLoot)
    Module:StartSpeedLoot(autoLoot)
end)

UI:RegisterEvent("LOOT_OPENED", function(_, autoLoot)
    Module:StartSpeedLoot(autoLoot)
end)

UI:RegisterEvent("LOOT_CLOSED", function()
    StopSpeedLoot(false)
end)

UI:RegisterEvent("UI_ERROR_MESSAGE", function(_, _, message)
    if not state.active then
        return
    end

    if message == ERR_INV_FULL
        or message == ERR_ITEM_MAX_COUNT
    then
        StopSpeedLoot(true)
    end
end)
