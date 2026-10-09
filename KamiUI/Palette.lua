local UI = KamiUI

local Palette = {}
UI.Palette = Palette

-- 0xRRGGBB plus optional opacity (0..1); returns WoW's normalized RGBA.
local function HexColor(rgb, alpha)
    return {
        math.floor(rgb / 65536) % 256 / 255,
        math.floor(rgb / 256) % 256 / 255,
        rgb % 256 / 255,
        alpha or 1,
    }
end

Palette.window = {
    neutral = HexColor(0x000000, 0.60),
    inventory = HexColor(0x580072, 0.25),
    bank = HexColor(0x005000, 0.25),
    chat = HexColor(0x000000, 0.85),
}

-- Module-specific colors are kept here alongside the shared palette.
Palette.minimapBorder = HexColor(0x333333)

Palette.auras = {
    helpful = HexColor(0x338CE6),
    harmful = HexColor(0xCC3333),
    background = HexColor(0x080808),
}

Palette.infoPanel = {
    background = HexColor(0x010204, 0.80),
    bottomBorder = HexColor(0x8C6B29),
    text = HexColor(0xD1D1D1),
}

Palette.xpBar = {
    background = HexColor(0x1A1A1F, 0.50),
    rested = HexColor(0x1452B8, 0.50),
    experience = HexColor(0x73299E),
    border = HexColor(0x000000),
    divider = HexColor(0x000000, 0.90),
}

Palette.guild = HexColor(0x80FF80)

Palette.windowBorder = {
    neutral = HexColor(0x29292E, 1.00),
    inventory = HexColor(0x33293D, 1.00),
    bank = HexColor(0x1F471F, 1.00),
    chat = HexColor(0x333333, 1.00),
}

Palette.background = Palette.window.neutral
Palette.panel = HexColor(0x000000, 0.24)
Palette.panelStrong = HexColor(0x000000, 0.40)
Palette.header = HexColor(0x000000, 0.48)
Palette.slot = HexColor(0x050505, 0.55)
Palette.slotBorder = HexColor(0x4D3D52, 0.90)
Palette.emptyBorder = HexColor(0x38383D, 1.00)

Palette.border = Palette.windowBorder.neutral
Palette.black = HexColor(0x000000, 1.00)
Palette.white = HexColor(0xFFFFFF, 1.00)

Palette.text = HexColor(0xEBEBF0, 1.00)
Palette.muted = HexColor(0x9E9EA8, 1.00)
Palette.tabInactive = HexColor(0xB8B8B8, 1.00)
Palette.gold = HexColor(0xE0B829, 1.00)
Palette.highlight = HexColor(0xFFD100, 1.00)
Palette.success = HexColor(0x52DB61, 1.00)
Palette.damage = HexColor(0xFFFF00, 1.00)

Palette.bagFamily = {
    arrows = HexColor(0x900000, 1.00),
    bullets = HexColor(0x900000, 1.00),
    soul = HexColor(0x8C33BF, 1.00),
    leather = HexColor(0x703010, 1.00),
    skinning = HexColor(0x703010, 1.00),
    herbs = HexColor(0x1F6B38, 1.00),
    mining = HexColor(0x618CAD, 1.00),
    keyring = HexColor(0xE6B326, 1.00),
}

Palette.scrollbar = {
    track = HexColor(0xFFFFFF, 0.05),
    thumb = HexColor(0x73737A, 0.65),
}

Palette.difficulty = {
    trivial = HexColor(0xB8B8B8, 1.00),
    easy = HexColor(0x33C73D, 1.00),
    normal = HexColor(0xFFD100, 1.00),
    hard = HexColor(0xFF801A, 1.00),
    veryHard = HexColor(0xFF2626, 1.00),
}

Palette.class = RAID_CLASS_COLORS or {}
Palette.power = PowerBarColor or {}

Palette.classFallback = {
    DEATHKNIGHT = HexColor(0xC41F3B, 1.00),
    DRUID = HexColor(0xFF7D0A, 1.00),
    HUNTER = HexColor(0xABD473, 1.00),
    MAGE = HexColor(0x40C7EB, 1.00),
    PALADIN = HexColor(0xF58CBA, 1.00),
    PRIEST = HexColor(0xFFFFFF, 1.00),
    ROGUE = HexColor(0xFFF569, 1.00),
    SHAMAN = HexColor(0x0070DE, 1.00),
    WARLOCK = HexColor(0x8787ED, 1.00),
    WARRIOR = HexColor(0xC79C6E, 1.00),
}

Palette.powerFallback = {
    MANA = HexColor(0x0073FF, 1.00),
    RAGE = HexColor(0xFF0000, 1.00),
    FOCUS = HexColor(0xFF8040, 1.00),
    ENERGY = HexColor(0xFFFF00, 1.00),
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

function Palette:GetReadablePowerColor(powerToken, multiplier)
    local color = self:GetPowerColor(powerToken)
    local r = color.r or color[1] or 1
    local g = color.g or color[2] or 1
    local b = color.b or color[3] or 1

    if powerToken == "MANA" then
        local whiteMix = 0.20

        r = r * (1 - whiteMix) + whiteMix
        g = g * (1 - whiteMix) + whiteMix
        b = b * (1 - whiteMix) + whiteMix
    end

    multiplier = multiplier or 1

    return r * multiplier,
        g * multiplier,
        b * multiplier
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


function Palette:GetBagFamilyColor(family, isKeyring)
    if isKeyring then
        return self.bagFamily.keyring
    end

    family = family or 0

    local masks = {
        { BAG_FAMILY_MASK_ARROWS or 0x00000001, "arrows" },
        { BAG_FAMILY_MASK_BULLETS or 0x00000002, "bullets" },
        { BAG_FAMILY_MASK_SOUL_SHARDS or 0x00000004, "soul" },
        { BAG_FAMILY_MASK_HERBS or 0x00000020, "herbs" },
        { BAG_FAMILY_MASK_LEATHERWORKING_SUPP or 0x00000008, "leather" },
        { BAG_FAMILY_MASK_SKINNING or 0x02000000, "skinning" },
        { BAG_FAMILY_MASK_MINING_SUPP or 0x00000400, "mining" },
    }

    for _, entry in ipairs(masks) do
        if UI:HasFlag(family, entry[1]) then
            return self.bagFamily[entry[2]]
        end
    end

    return self.slotBorder
end
