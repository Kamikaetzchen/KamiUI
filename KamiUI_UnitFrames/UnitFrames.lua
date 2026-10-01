local UI = KamiUI

local UF = UI:NewModule("UnitFrames")

UF.name = "KamiUI_UnitFrames"
UF.version = "0.1.0"

local FALLBACK_CLASS_COLORS = {
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    DRUID = { 1.00, 0.49, 0.04 },
    HUNTER = { 0.67, 0.83, 0.45 },
    MAGE = { 0.25, 0.78, 0.92 },
    PALADIN = { 0.96, 0.55, 0.73 },
    PRIEST = { 1.00, 1.00, 1.00 },
    ROGUE = { 1.00, 0.96, 0.41 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    WARLOCK = { 0.53, 0.53, 0.93 },
    WARRIOR = { 0.78, 0.61, 0.43 },
}

local FALLBACK_POWER_COLORS = {
    MANA = { 0.00, 0.45, 1.00 },
    RAGE = { 1.00, 0.00, 0.00 },
    FOCUS = { 1.00, 0.50, 0.25 },
    ENERGY = { 1.00, 1.00, 0.00 },
}

function UF:GetUnitColor(unit)
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

        if color then
            return color.r, color.g, color.b
        end

        color = FALLBACK_CLASS_COLORS[class]
        if color then
            return color[1], color[2], color[3]
        end
    end

    local reaction = UnitReaction(unit, "player")
    local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]

    if color then
        return color.r, color.g, color.b
    end

    return 0.2, 0.8, 0.2
end

function UF:GetPowerColor(unit)
    local _, powerToken = UnitPowerType(unit)
    local color = PowerBarColor and PowerBarColor[powerToken]

    if color then
        return color.r, color.g, color.b
    end

    color = FALLBACK_POWER_COLORS[powerToken] or { 0.00, 0.45, 1.00 }
    return color[1], color[2], color[3]
end
