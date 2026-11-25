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

-- Weapon speed is an intrinsic item property, not a combat stat.
-- Read the original tooltip, never the equipped player's swing timer.
local function ReadMainHandWeaponStats(link, stats, equipLoc)
    if equipLoc ~= "INVTYPE_WEAPON" and equipLoc ~= "INVTYPE_2HWEAPON"
        and equipLoc ~= "INVTYPE_WEAPONMAINHAND" then
        return
    end
    if not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then return end
    local data = UI:SafeCall(C_TooltipInfo.GetHyperlink, link)
    if not UI:CanAccessValue(data) or type(data) ~= "table"
        or not UI:CanAccessValue(data.lines)
        or type(data.lines) ~= "table" then return end

    for _, line in ipairs(data.lines) do
        if UI:CanAccessValue(line) and type(line) == "table" then
            for _, key in ipairs({ "leftText", "rightText" }) do
                local raw = line[key]
                if UI:CanAccessValue(raw) and type(raw) == "string" then
                    local text = raw:gsub("|c%x%x%x%x%x%x%x%x", "")
                        :gsub("|r", ""):lower()
                    local speed = text:match("^speed%s+([%d.,]+)$")
                        or text:match("^tempo%s+([%d.,]+)$")
                    local dps = text:match("([%d.,]+)%s+damage per second")
                        or text:match("([%d.,]+)%s+schaden pro sekunde")
                    if speed then
                        stats.KAMI_MAIN_HAND_SPEED =
                            tonumber((speed:gsub(",", ".")))
                    end
                    if dps and not Number(stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) then
                        stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT =
                            tonumber((dps:gsub(",", ".")))
                    end
                end
            end
        end
    end
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

function Module:RateItem(itemLink, profile, itemCache)
    if not itemLink or not UI:CanAccessValue(itemLink)
        or type(itemLink) ~= "string"
        or not C_Item or not C_Item.GetItemStats then
        return nil
    end

    profile = profile or self:GetActiveProfile()
    if not profile then return nil end

    -- One tooltip displays several profiles. Read and parse the item's
    -- stats only once, including when comparing worn equipment.
    local item = itemCache and itemCache[itemLink]
    if item == false then return nil end
    if not item then
        local equipLoc = GetEquipLoc(itemLink)
        if not equipLoc or not EQUIP_SLOTS[equipLoc] then
            if itemCache then itemCache[itemLink] = false end
            return nil
        end
        local stats = UI:SafeCall(C_Item.GetItemStats, itemLink)
        if not stats or not UI:CanAccessValue(stats)
            or type(stats) ~= "table" then
            return nil
        end

        -- Preserve the flat Weapon Damage fallback when the item API
        -- does not expose the stat directly.
        local flatDamage = GetFlatWeaponDamage(itemLink, stats)
        if flatDamage then
            stats.ITEM_MOD_WEAPON_DAMAGE_SHORT = flatDamage
        end

        -- Shaman profiles need the actual weapon DPS and base speed.
        -- Keep existing druid weapon scoring behavior unchanged.
        if profile.classFile == "SHAMAN" then
            ReadMainHandWeaponStats(itemLink, stats, equipLoc)
        end
        item = { equipLoc = equipLoc, stats = stats }
        if itemCache then itemCache[itemLink] = item end
    end
    local equipLoc, stats = item.equipLoc, item.stats

    local score = 0
    local recognized = false
    local healingScore
    local spellDamageScore
    for key, weight in pairs(profile.weights) do
        local amount = Number(stats[key])
        if amount then
            -- Every profile weight is per raw point from GetItemStats.
            local weighted = amount * weight
            if profile.exclusiveHealingPower
                and (key == "ITEM_MOD_SPELL_POWER_SHORT"
                    or key == "ITEM_MOD_SPELL_HEALING_DONE_SHORT") then
                -- Some items expose both API keys for the same spell
                -- bonus. Only use the stronger healing contribution.
                healingScore = math.max(healingScore or 0, weighted)
            elseif profile.exclusiveSpellDamage
                and (key == "ITEM_MOD_SPELL_POWER_SHORT"
                    or key == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT") then
                spellDamageScore = math.max(spellDamageScore or 0, weighted)
            else
                score = score + weighted
            end
            recognized = true
        end
    end
    if healingScore then score = score + healingScore end
    if spellDamageScore then score = score + spellDamageScore end

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

function Module:GetEquippedComparisons(itemResult, profile, itemCache)
    local comparisons = {}
    local slots = itemResult
        and EQUIP_SLOTS[itemResult.equipLoc]

    if not slots or itemResult.score == nil then
        return comparisons
    end

    for _, slot in ipairs(slots) do
        local equipped = UI:SafeCall(GetInventoryItemLink, "player", slot)
        if equipped and UI:CanAccessValue(equipped) then
            local equippedResult = self:RateItem(equipped, profile, itemCache)
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
                        local offhandResult = self:RateItem(offhand, profile, itemCache)
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
