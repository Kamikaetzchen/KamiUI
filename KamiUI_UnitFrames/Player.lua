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

local frame = CreateFrame("Frame", "KamiUIPlayerFrame", UIParent)
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("RIGHT", UIParent, "CENTER", -2, -180)

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

    local r, g, b = UF:GetUnitColor("player")
    health:SetStatusBarColor(r, g, b)
end

local function UpdatePower()
    local current = UnitPower("player")
    local maximum = UnitPowerMax("player")

    power:SetMinMaxValues(0, maximum)
    power:SetValue(current)
    powerText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetPowerColor("player")
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
