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

local frame = CreateFrame("Frame", "KamiUITargetFrame", UIParent)
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("LEFT", UIParent, "CENTER", 2, -180)

local border = frame:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetColorTexture(0, 0, 0, 1)

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

local portrait = content:CreateTexture(nil, "ARTWORK")
portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
portrait:SetPoint("TOPRIGHT")

local health = CreateFrame("StatusBar", nil, content)
health:SetSize(BAR_WIDTH, HEALTH_HEIGHT)
health:SetPoint("TOPLEFT")
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
    local current = UnitHealth("target")
    local maximum = UnitHealthMax("target")

    health:SetMinMaxValues(0, maximum)
    health:SetValue(current)
    healthText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetUnitColor("target")
    health:SetStatusBarColor(r, g, b)
end

local function UpdatePower()
    local current = UnitPower("target")
    local maximum = UnitPowerMax("target")

    power:SetMinMaxValues(0, maximum)
    power:SetValue(current)
    powerText:SetFormattedText("%d/%d", current, maximum)

    local r, g, b = UF:GetPowerColor("target")
    power:SetStatusBarColor(r, g, b)
end

local function UpdateIdentity()
    nameText:SetText(UnitName("target") or "")
    SetPortraitTexture(portrait, "target")
end

local function UpdateAll()
    if not UnitExists("target") then
        frame:Hide()
        return
    end

    frame:Show()
    UpdateIdentity()
    UpdateHealth()
    UpdatePower()
end

local function OnTargetEvent(event, unit)
    if event == "PLAYER_TARGET_CHANGED" or unit == "target" then
        UpdateAll()
    end
end

UI:RegisterEvent("PLAYER_TARGET_CHANGED", OnTargetEvent)
UI:RegisterEvent("UNIT_HEALTH", OnTargetEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnTargetEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnTargetEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnTargetEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnTargetEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnTargetEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnTargetEvent)

frame:Hide()

UF.targetFrame = frame
