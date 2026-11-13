local UI = KamiUI
local Module = UI:GetModule("ItemRating")

local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 },
    INVTYPE_TABARD = { 19 },
}

local SLOT_LABELS = {
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
}

local function Number(value)
    if value == nil or not UI:CanAccessValue(value)
        or type(value) ~= "number" then
        return nil
    end
    return value
end

local function GetEquipLoc(itemLink)
    if not C_Item or not C_Item.GetItemInfoInstant then
        return nil
    end

    local _, _, _, equipLoc =
        UI:SafeCall(C_Item.GetItemInfoInstant, itemLink)

    if not equipLoc or not UI:CanAccessValue(equipLoc)
        or type(equipLoc) ~= "string" then
        return nil
    end

    return equipLoc
end

function Module:RateItem(itemLink, profile)
    if not itemLink or not UI:CanAccessValue(itemLink)
        or type(itemLink) ~= "string"
        or not C_Item or not C_Item.GetItemStats then
        return nil
    end

    profile = profile or self:GetActiveProfile()
    if not profile then
        return nil
    end

    local equipLoc = GetEquipLoc(itemLink)
    if not equipLoc or not EQUIP_SLOTS[equipLoc] then
        return nil
    end

    local stats = UI:SafeCall(C_Item.GetItemStats, itemLink)
    if not stats or not UI:CanAccessValue(stats)
        or type(stats) ~= "table" then
        return nil
    end

    local weights = self:GetEffectiveWeights(profile) or profile.weights
    local score = 0
    local recognized = false
    for key, weight in pairs(weights) do
        local amount = Number(stats[key])
        if amount then
            score = score + amount * weight
            recognized = true
        end
    end

    -- Unmodelled stats (including proc-only trinkets) are unknown, not
    -- zero DPS. Items with explicit DPS stats can have a score of zero.
    if not recognized then
        return {
            score = nil,
            equipLoc = equipLoc,
            unscored = true,
        }
    end

    return {
        score = score,
        equipLoc = equipLoc,
        unscored = false,
    }
end

function Module:GetEquippedComparisons(itemResult, profile)
    local comparisons = {}
    local slots = itemResult
        and EQUIP_SLOTS[itemResult.equipLoc]

    if not slots or itemResult.score == nil then
        return comparisons
    end

    for _, slot in ipairs(slots) do
        local equipped = UI:SafeCall(GetInventoryItemLink, "player", slot)
        if equipped and UI:CanAccessValue(equipped) then
            local equippedResult = self:RateItem(equipped, profile)
            if equippedResult and equippedResult.score ~= nil then
                local oldScore = equippedResult.score

                -- A two-handed upgrade replaces both mainhand and offhand.
                -- (One-handed swaps intentionally compare mainhand only.)
                if itemResult.equipLoc == "INVTYPE_2HWEAPON"
                    and slot == 16 then
                    local offhand = UI:SafeCall(
                        GetInventoryItemLink, "player", 17
                    )
                    if offhand and UI:CanAccessValue(offhand) then
                        local offhandResult = self:RateItem(offhand, profile)
                        if offhandResult and offhandResult.score then
                            oldScore = oldScore + offhandResult.score
                        end
                    end
                end

                comparisons[#comparisons + 1] = {
                    label = SLOT_LABELS[slot] or "Equipped",
                    difference = itemResult.score - oldScore,
                }
            end
        end
    end

    return comparisons
end
