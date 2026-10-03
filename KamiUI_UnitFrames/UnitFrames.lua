local UI = KamiUI

local UF = UI:NewModule("UnitFrames")

UF.name = "KamiUI_UnitFrames"
UF.version = "0.1.0"

UF.flatTexture = "Interface\\Buttons\\WHITE8X8"
UF.colorMultiplier = 0.60

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

local HAPPINESS_COLORS = {
    [1] = { 0.85, 0.10, 0.10 },
    [2] = { 0.85, 0.65, 0.05 },
    [3] = { 0.10, 0.75, 0.20 },
}

function UF:CanAccessValue(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end

    if issecretvalue then
        return not issecretvalue(value)
    end

    return true
end

function UF:GetUnitColor(unit)
    if unit == "pet" and C_PetInfo and C_PetInfo.GetPetHappiness then
        local happiness = C_PetInfo.GetPetHappiness()

        if happiness and self:CanAccessValue(happiness) then
            local color = HAPPINESS_COLORS[happiness]

            if color then
                return self:DarkenColor(color[1], color[2], color[3])
            end
        end
    end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)

        if class and self:CanAccessValue(class) then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

            if color then
                return self:DarkenColor(color.r, color.g, color.b)
            end

            color = FALLBACK_CLASS_COLORS[class]
            if color then
                return self:DarkenColor(color[1], color[2], color[3])
            end
        end
    end

    local reaction = UnitReaction(unit, "player")

    if reaction and self:CanAccessValue(reaction) and FACTION_BAR_COLORS then
        local color = FACTION_BAR_COLORS[reaction]

        if color then
            return self:DarkenColor(color.r, color.g, color.b)
        end
    end

    return self:DarkenColor(0.2, 0.8, 0.2)
end

function UF:GetPowerColor(unit)
    local _, powerToken = UnitPowerType(unit)
    local color = PowerBarColor and PowerBarColor[powerToken]

    if color then
        return self:DarkenColor(color.r, color.g, color.b)
    end

    color = FALLBACK_POWER_COLORS[powerToken] or { 0.00, 0.45, 1.00 }
    return self:DarkenColor(color[1], color[2], color[3])
end

function UF:DarkenColor(r, g, b)
    return r * self.colorMultiplier,
        g * self.colorMultiplier,
        b * self.colorMultiplier
end

function UF:GetBarFontSize(height)
    return math.min(height, 10)
end

local CLASSIFICATION_SUFFIX = {
    elite = "E",
    rare = "R",
    rareelite = "RE",
    worldboss = "B",
}

local function ToHexChannel(value)
    return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

function UF:GetUnitDisplayName(unit)
    local name

    if GetUnitName then
        name = GetUnitName(unit)
    end

    name = name or UnitName(unit) or ""

    local status = ""

    local isAFK = UnitIsAFK and UnitIsAFK(unit)
    local isDND = UnitIsDND and UnitIsDND(unit)

    if self:CanAccessValue(isAFK) and isAFK then
        status = "<AFK> "
    elseif self:CanAccessValue(isDND) and isDND then
        status = "<DND> "
    end

    local level = UnitLevel(unit)
    local levelText = level and level > 0 and tostring(level) or "??"
    local classification = UnitClassification(unit)
    local suffix = CLASSIFICATION_SUFFIX[classification] or ""

    local color
    if level and level > 0 and GetQuestDifficultyColor then
        color = GetQuestDifficultyColor(level)
    else
        color = { r = 1.0, g = 0.1, b = 0.1 }
    end

    local levelColor = string.format(
        "|cff%02x%02x%02x",
        ToHexChannel(color.r),
        ToHexChannel(color.g),
        ToHexChannel(color.b)
    )

    return status .. levelColor .. levelText .. suffix .. "|r " .. name
end

function UF:ConfigureUnitButton(frame, unit)
    frame.unit = unit
    frame:RegisterForClicks("AnyUp")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
end
