local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local FRAME_WIDTH = 200
local FRAME_HEIGHT = 30
local BORDER_SIZE = 1
local CONTENT_WIDTH = FRAME_WIDTH - BORDER_SIZE * 2
local CONTENT_HEIGHT = FRAME_HEIGHT - BORDER_SIZE * 2
local PORTRAIT_SIZE = CONTENT_HEIGHT
local BAR_WIDTH = CONTENT_WIDTH - PORTRAIT_SIZE
local POWER_HEIGHT = CONTENT_HEIGHT / 3
local HEALTH_HEIGHT = CONTENT_HEIGHT - POWER_HEIGHT

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

local function GetClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

    if color then
        return color.r, color.g, color.b
    end

    color = FALLBACK_CLASS_COLORS[class] or { 0.2, 0.8, 0.2 }
    return color[1], color[2], color[3]
end

local function GetPowerColor()
    local _, powerToken = UnitPowerType("player")
    local color = PowerBarColor and PowerBarColor[powerToken]

    if color then
        return color.r, color.g, color.b
    end

    color = FALLBACK_POWER_COLORS[powerToken] or { 0.00, 0.45, 1.00 }
    return color[1], color[2], color[3]
end

local frame = CreateFrame("Frame", "KamiUIPlayerFrame", UIParent)
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", -250, -180)

local border = frame:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetColorTexture(0, 0, 0, 1)

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

local portrait = content:CreateTexture(nil, "ARTWORK")
portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
portrait:SetPoint("TOPLEFT")

local health = CreateFrame("StatusBar", nil, content)
health:SetSize(BAR_WIDTH, HEALTH_HEIGHT)
health:SetPoint("TOPLEFT", portrait, "TOPRIGHT")
health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

local healthBackground = health:CreateTexture(nil, "BACKGROUND")
healthBackground:SetAllPoints()
healthBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

local power = CreateFrame("StatusBar", nil, content)
power:SetSize(BAR_WIDTH, POWER_HEIGHT)
power:SetPoint("TOPLEFT", health, "BOTTOMLEFT")
power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

local powerBackground = power:CreateTexture(nil, "BACKGROUND")
powerBackground:SetAllPoints()
powerBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

local nameText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetPoint("LEFT", 3, 0)
nameText:SetJustifyH("LEFT")
nameText:SetTextColor(1, 1, 1)
nameText:SetShadowColor(0, 0, 0, 1)
nameText:SetShadowOffset(1, -1)

local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
healthText:SetPoint("RIGHT", -3, 0)
healthText:SetJustifyH("RIGHT")
healthText:SetTextColor(1, 1, 1)
healthText:SetShadowColor(0, 0, 0, 1)
healthText:SetShadowOffset(1, -1)

local powerText = power:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
powerText:SetPoint("RIGHT", -3, 0)
powerText:SetJustifyH("RIGHT")
powerText:SetTextColor(1, 1, 1)
powerText:SetShadowColor(0, 0, 0, 1)
powerText:SetShadowOffset(1, -1)

local function UpdateHealth()
    local current = UnitHealth("player")
    local maximum = UnitHealthMax("player")

    health:SetMinMaxValues(0, maximum)
    health:SetValue(current)
    healthText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = GetClassColor()
    health:SetStatusBarColor(r, g, b)
end

local function UpdatePower()
    local current = UnitPower("player")
    local maximum = UnitPowerMax("player")

    power:SetMinMaxValues(0, maximum)
    power:SetValue(current)
    powerText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = GetPowerColor()
    power:SetStatusBarColor(r, g, b)
end

local function UpdateIdentity()
    nameText:SetText(UnitName("player") or "")
    SetPortraitTexture(portrait, "player")
end

local function UpdateAll()
    UpdateIdentity()
    UpdateHealth()
    UpdatePower()
end

local function OnPlayerEvent(event, unit)
    if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
        UpdateAll()
    end
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEvent)
UI:RegisterEvent("UNIT_HEALTH", OnPlayerEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnPlayerEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnPlayerEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnPlayerEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnPlayerEvent)

UF.playerFrame = frame
