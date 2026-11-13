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

-- WoW Forever rings can have "Equip: +2 Weapon Damage", separate
-- from a weapon's intrinsic DPS. First honor native stat keys; only
-- fall back to the ORIGINAL item tooltip (never our augmented tooltip).
local function GetFlatWeaponDamage(link, stats)
    local native = Number(stats.ITEM_MOD_WEAPON_DAMAGE_SHORT)
    if native then
        return native
    end


    if not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return nil
    end

    local data = UI:SafeCall(C_TooltipInfo.GetHyperlink, link)
    if not data or not UI:CanAccessValue(data)
        or not data.lines or not UI:CanAccessValue(data.lines) then
        return nil
    end

    for _, line in ipairs(data.lines) do
        if line and UI:CanAccessValue(line) then
            local raw = line.leftText
            if raw and UI:CanAccessValue(raw)
                and type(raw) == "string" then
                local text = raw:gsub("|c%x%x%x%x%x%x%x%x", "")
                    :gsub("|r", ""):lower()
                local amount = text:match(
                    "^equip:%s*%+(%d+%.?%d*)%s+weapon%s+damage"
                ) or text:match(
                    "^equip:%s*increases%s+weapon%s+damage%s+by%s+(%d+%.?%d*)"
                ) or text:match(
                    "^anlegen:%s*%+(%d+%.?%d*)%s+waffenschaden"
                ) or text:match(
                    "^anlegen:%s*erh[oö]ht%s+den%s+waffenschaden%s+um%s+(%d+%.?%d*)"
                )
                if amount then
                    return tonumber(amount)
                end
            end
        end
    end

    return nil
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

    -- The client may not report flat Weapon Damage as a numeric stat.
    -- This is a custom Item Rating key so the editor can score it.
    local flatDamage = GetFlatWeaponDamage(itemLink, stats)
    if flatDamage then
        stats.ITEM_MOD_WEAPON_DAMAGE_SHORT = flatDamage
    end

    local weights = self:GetEffectiveWeights(profile) or profile.weights
    local score = 0
    local recognized = false
    for key, weight in pairs(weights) do
        local amount = Number(stats[key])
        if amount then
            -- GetItemStats reports raw rating, while our editor values
            -- rating-derived stats per visible +1% on the item tooltip.
            local displayAmount = self:GetDisplayStatAmount(key, amount)
            score = score + displayAmount * weight
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
