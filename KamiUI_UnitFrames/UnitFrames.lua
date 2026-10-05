local UI = KamiUI
local Palette = UI.Palette

local UF = UI:NewModule("UnitFrames", "KamiUI_UnitFrames")

UF.version = "0.1.0"

UF.flatTexture = "Interface\\Buttons\\WHITE8X8"
UF.colorMultiplier = 0.60
UF.powerColorMultiplier = 0.70

local HAPPINESS_COLORS = {
    [1] = { 0.85, 0.10, 0.10 },
    [2] = { 0.85, 0.65, 0.05 },
    [3] = { 0.10, 0.75, 0.20 },
}

function UF:GetUnitColor(unit)
    local tapDenied = UnitIsTapDenied and UnitIsTapDenied(unit)

    if UI:CanAccessValue(tapDenied) and tapDenied then
        return 0.35, 0.35, 0.35
    end

    if unit == "pet" and C_PetInfo and C_PetInfo.GetPetHappiness then
        local happiness = C_PetInfo.GetPetHappiness()

        if happiness and UI:CanAccessValue(happiness) then
            local color = HAPPINESS_COLORS[happiness]

            if color then
                return self:DarkenColor(color[1], color[2], color[3])
            end
        end
    end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)

        if class and UI:CanAccessValue(class) then
            local color = Palette:GetClassColor(class)

            if color then
                return self:DarkenColor(
                    color.r or color[1],
                    color.g or color[2],
                    color.b or color[3]
                )
            end
        end
    end

    local reaction = UnitReaction(unit, "player")

    if reaction and UI:CanAccessValue(reaction) and FACTION_BAR_COLORS then
        local color = FACTION_BAR_COLORS[reaction]

        if color then
            return self:DarkenColor(color.r, color.g, color.b)
        end
    end

    return self:DarkenColor(0.2, 0.8, 0.2)
end

function UF:GetPowerColor(unit)
    local _, powerToken = UnitPowerType(unit)
    local color = Palette:GetPowerColor(powerToken)

    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]

    if powerToken == "MANA" then
        local whiteMix = 0.15

        r = r * (1 - whiteMix) + whiteMix
        g = g * (1 - whiteMix) + whiteMix
        b = b * (1 - whiteMix) + whiteMix
    end

    return r * self.powerColorMultiplier,
        g * self.powerColorMultiplier,
        b * self.powerColorMultiplier
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

    if UI:CanAccessValue(isAFK) and isAFK then
        status = "<AFK> "
    elseif UI:CanAccessValue(isDND) and isDND then
        status = "<DND> "
    end

    local level = UnitLevel(unit)
    local levelText = level and level > 0 and tostring(level) or "??"
    local classification = UnitClassification(unit)
    local suffix = CLASSIFICATION_SUFFIX[classification] or ""

    local color = Palette:GetLevelDifficultyColor(level)

    local levelColor = string.format(
        "|cff%02x%02x%02x",
        ToHexChannel(color.r or color[1]),
        ToHexChannel(color.g or color[2]),
        ToHexChannel(color.b or color[3])
    )

    return status .. levelColor .. levelText .. suffix .. "|r " .. name
end

function UF:ConfigureNameText(fontString)
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end

    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

function UF:SetUnitDisplayName(fontString, unit)
    if not fontString then
        return
    end

    local display = self:GetUnitDisplayName(unit)
    fontString:SetText(display)

    if not UI:CanAccessValue(display) then
        return
    end

    local width = fontString:GetWidth()

    if not UI:CanAccessValue(width) or not width or width <= 0 then
        return
    end

    local stringWidth = fontString:GetStringWidth()

    if not UI:CanAccessValue(stringWidth) or stringWidth <= width then
        return
    end

    local prefix, name = string.match(display, "^(.-|r%s)(.*)$")

    if not prefix then
        prefix = ""
        name = display
    end

    local length = #name

    while length > 0 do
        length = length - 1
        fontString:SetText(
            prefix .. string.sub(name, 1, length) .. "..."
        )

        stringWidth = fontString:GetStringWidth()

        if not UI:CanAccessValue(stringWidth) then
            fontString:SetText(display)
            return
        end

        if stringWidth <= width then
            return
        end
    end

    fontString:SetText(prefix .. "...")
end

function UF:ConfigureUnitButton(frame, unit)
    frame.unit = unit
    frame:RegisterForClicks("AnyUp")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
end
