local UI = KamiUI

local Palette = {}
UI.Palette = Palette

Palette.window = {
    neutral = { 0.00, 0.00, 0.00, 0.40 },
    inventory = { 0.345, 0.000, 0.447, 0.25 },
    bank = { 0.000, 0.314, 0.000, 0.25 },
    chat = { 0.00, 0.00, 0.00, 0.85 },
}

Palette.windowBorder = {
    neutral = { 0.16, 0.16, 0.18, 1.00 },
    inventory = { 0.20, 0.16, 0.24, 1.00 },
    bank = { 0.12, 0.28, 0.12, 1.00 },
    chat = { 0.20, 0.20, 0.20, 1.00 },
}

Palette.background = Palette.window.neutral
Palette.panel = { 0.00, 0.00, 0.00, 0.24 }
Palette.panelStrong = { 0.00, 0.00, 0.00, 0.40 }
Palette.header = { 0.00, 0.00, 0.00, 0.48 }
Palette.slot = { 0.02, 0.02, 0.02, 0.55 }
Palette.slotBorder = { 0.30, 0.24, 0.32, 0.90 }
Palette.emptyBorder = { 0.22, 0.22, 0.24, 1.00 }

Palette.border = Palette.windowBorder.neutral
Palette.black = { 0.00, 0.00, 0.00, 1.00 }
Palette.white = { 1.00, 1.00, 1.00, 1.00 }

Palette.text = { 0.92, 0.92, 0.94, 1.00 }
Palette.muted = { 0.62, 0.62, 0.66, 1.00 }
Palette.tabInactive = { 0.72, 0.72, 0.72, 1.00 }
Palette.gold = { 0.88, 0.72, 0.16, 1.00 }
Palette.highlight = { 1.00, 0.82, 0.00, 1.00 }
Palette.success = { 0.32, 0.86, 0.38, 1.00 }

Palette.difficulty = {
    trivial = { 0.72, 0.72, 0.72, 1.00 },
    easy = { 0.20, 0.78, 0.24, 1.00 },
    normal = { 1.00, 0.82, 0.00, 1.00 },
    hard = { 1.00, 0.50, 0.10, 1.00 },
    veryHard = { 1.00, 0.15, 0.15, 1.00 },
}

Palette.class = RAID_CLASS_COLORS or {}
Palette.power = PowerBarColor or {}

Palette.classFallback = {
    DEATHKNIGHT = { 0.77, 0.12, 0.23, 1.00 },
    DRUID = { 1.00, 0.49, 0.04, 1.00 },
    HUNTER = { 0.67, 0.83, 0.45, 1.00 },
    MAGE = { 0.25, 0.78, 0.92, 1.00 },
    PALADIN = { 0.96, 0.55, 0.73, 1.00 },
    PRIEST = { 1.00, 1.00, 1.00, 1.00 },
    ROGUE = { 1.00, 0.96, 0.41, 1.00 },
    SHAMAN = { 0.00, 0.44, 0.87, 1.00 },
    WARLOCK = { 0.53, 0.53, 0.93, 1.00 },
    WARRIOR = { 0.78, 0.61, 0.43, 1.00 },
}

Palette.powerFallback = {
    MANA = { 0.00, 0.45, 1.00, 1.00 },
    RAGE = { 1.00, 0.00, 0.00, 1.00 },
    FOCUS = { 1.00, 0.50, 0.25, 1.00 },
    ENERGY = { 1.00, 1.00, 0.00, 1.00 },
}

function Palette:GetClassColor(classFile)
    if not classFile then
        return nil
    end

    return self.class[classFile] or self.classFallback[classFile]
end

function Palette:GetPowerColor(powerToken)
    if not powerToken then
        return self.powerFallback.MANA
    end

    return self.power[powerToken]
        or self.powerFallback[powerToken]
        or self.powerFallback.MANA
end

function Palette:GetDifficultyColor(role)
    return self.difficulty[role] or self.difficulty.normal
end

function Palette:GetLevelDifficultyColor(level)
    if level and GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(level)

        if color then
            local r = color.r or color[1] or 1
            local g = color.g or color[2] or 0.1
            local b = color.b or color[3] or 0.1
            local isGray =
                math.abs(r - g) < 0.04
                and math.abs(g - b) < 0.04

            if isGray and r < 0.72 then
                return self.difficulty.trivial
            end

            return color
        end
    end

    return self.difficulty.veryHard
end
