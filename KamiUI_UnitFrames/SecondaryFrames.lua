local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local FRAME_WIDTH = 150
local FRAME_HEIGHT = 20
local BORDER_SIZE = 1
local CONTENT_WIDTH = FRAME_WIDTH - BORDER_SIZE * 2
local CONTENT_HEIGHT = FRAME_HEIGHT - BORDER_SIZE * 2
local BAR_HEIGHT = CONTENT_HEIGHT / 2

local frames = {}

local function CreateUnitFrame(name, unit)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

    local health = CreateFrame("StatusBar", nil, content)
    health:SetSize(CONTENT_WIDTH, BAR_HEIGHT)
    health:SetPoint("TOPLEFT")
    health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local healthBackground = health:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints()
    healthBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local power = CreateFrame("StatusBar", nil, content)
    power:SetSize(CONTENT_WIDTH, BAR_HEIGHT)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT")
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local powerBackground = power:CreateTexture(nil, "BACKGROUND")
    powerBackground:SetAllPoints()
    powerBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local nameText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", 2, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    healthText:SetPoint("RIGHT", -2, 0)
    healthText:SetJustifyH("RIGHT")
    healthText:SetTextColor(1, 1, 1)
    healthText:SetShadowColor(0, 0, 0, 1)
    healthText:SetShadowOffset(1, -1)

    local powerText = power:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    powerText:SetPoint("RIGHT", -2, 0)
    powerText:SetJustifyH("RIGHT")
    powerText:SetTextColor(1, 1, 1)
    powerText:SetShadowColor(0, 0, 0, 1)
    powerText:SetShadowOffset(1, -1)

    frame.unit = unit
    frame.health = health
    frame.power = power
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText

    frames[unit] = frame
    frame:Hide()

    return frame
end

local function UpdateFrame(frame)
    local unit = frame.unit

    if not UnitExists(unit) then
        frame:Hide()
        return
    end

    frame:Show()

    local healthCurrent = UnitHealth(unit)
    local healthMaximum = UnitHealthMax(unit)

    frame.health:SetMinMaxValues(0, healthMaximum)
    frame.health:SetValue(healthCurrent)
    frame.healthText:SetFormattedText("%d/%d", healthCurrent, healthMaximum)

    local r, g, b = UF:GetUnitColor(unit)
    frame.health:SetStatusBarColor(r, g, b)

    local powerCurrent = UnitPower(unit)
    local powerMaximum = UnitPowerMax(unit)

    frame.power:SetMinMaxValues(0, powerMaximum)
    frame.power:SetValue(powerCurrent)
    frame.powerText:SetFormattedText("%d/%d", powerCurrent, powerMaximum)

    r, g, b = UF:GetPowerColor(unit)
    frame.power:SetStatusBarColor(r, g, b)

    frame.nameText:SetText(UnitName(unit) or "")
end

local targetTarget = CreateUnitFrame("KamiUITargetTargetFrame", "targettarget")
targetTarget:SetPoint("BOTTOMLEFT", UF.targetFrame, "TOPRIGHT", 0, 0)

local targetTargetTarget =
    CreateUnitFrame("KamiUITargetTargetTargetFrame", "targettargettarget")
targetTargetTarget:SetPoint("LEFT", targetTarget, "RIGHT", 0, 0)

local focus = CreateUnitFrame("KamiUIFocusFrame", "focus")
focus:SetPoint("TOPLEFT", UF.targetFrame, "BOTTOMRIGHT", 0, 0)

local focusTarget = CreateUnitFrame("KamiUIFocusTargetFrame", "focustarget")
focusTarget:SetPoint("LEFT", focus, "RIGHT", 0, 0)

local function UpdateAll()
    UpdateFrame(targetTarget)
    UpdateFrame(targetTargetTarget)
    UpdateFrame(focus)
    UpdateFrame(focusTarget)
end

local function OnUnitEvent(_, unit)
    if not unit then
        UpdateAll()
        return
    end

    local frame = frames[unit]
    if frame then
        UpdateFrame(frame)
    end

    if unit == "target" then
        UpdateFrame(targetTarget)
        UpdateFrame(targetTargetTarget)
    elseif unit == "targettarget" then
        UpdateFrame(targetTargetTarget)
    elseif unit == "focus" then
        UpdateFrame(focus)
        UpdateFrame(focusTarget)
    end
end

UI:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateAll)
UI:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateAll)
UI:RegisterEvent("PLAYER_FOCUS_CHANGED", UpdateAll)
UI:RegisterEvent("UNIT_TARGET", OnUnitEvent)
UI:RegisterEvent("UNIT_HEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnUnitEvent)

UF.targetTargetFrame = targetTarget
UF.targetTargetTargetFrame = targetTargetTarget
UF.focusFrame = focus
UF.focusTargetFrame = focusTarget
