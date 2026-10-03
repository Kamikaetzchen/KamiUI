local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local FRAME_WIDTH = 150
local FRAME_HEIGHT = 25
local BORDER_SIZE = 1
local CONTENT_WIDTH = FRAME_WIDTH - BORDER_SIZE * 2
local HEALTH_HEIGHT = 13
local POWER_HEIGHT = 9
local SEPARATOR_SIZE = 1

local frames = {}

local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

local function CreateUnitFrame(name, unit)
    local frame = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    UF:ConfigureUnitButton(frame, unit)
    RegisterUnitWatch(frame)

    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    content:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)

    local health = CreateFrame("StatusBar", nil, content)
    health:SetSize(CONTENT_WIDTH, HEALTH_HEIGHT)
    health:SetPoint("TOPLEFT")
    health:SetStatusBarTexture(UF.flatTexture)

    local healthBackground = health:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints()
    healthBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local power = CreateFrame("StatusBar", nil, content)
    power:SetSize(CONTENT_WIDTH, POWER_HEIGHT)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -SEPARATOR_SIZE)
    power:SetStatusBarTexture(UF.flatTexture)

    local powerBackground = power:CreateTexture(nil, "BACKGROUND")
    powerBackground:SetAllPoints()
    powerBackground:SetColorTexture(0.08, 0.08, 0.08, 1)

    local nameText = health:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(
        fontPath,
        math.max(1, UF:GetBarFontSize(HEALTH_HEIGHT) - 1),
        fontFlags
    )
    nameText:SetPoint("LEFT", 2, 0)
    nameText:SetWidth(105)
    nameText:SetJustifyH("LEFT")
    UF:ConfigureNameText(nameText)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    local healthText = health:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(
        fontPath,
        math.max(1, UF:GetBarFontSize(HEALTH_HEIGHT) - 1),
        fontFlags
    )
    healthText:SetPoint("RIGHT", -2, 0)
    healthText:SetJustifyH("RIGHT")
    healthText:SetTextColor(1, 1, 1)
    healthText:SetShadowColor(0, 0, 0, 1)
    healthText:SetShadowOffset(1, -1)

    local powerText = power:CreateFontString(nil, "OVERLAY")
    powerText:SetFont(fontPath, UF:GetBarFontSize(POWER_HEIGHT), fontFlags)
    powerText:SetPoint("RIGHT", -2, 0)
    powerText:SetJustifyH("RIGHT")
    powerText:SetTextColor(1, 1, 1)
    powerText:SetShadowColor(0, 0, 0, 1)
    powerText:SetShadowOffset(1, -1)

    frame.health = health
    frame.power = power
    frame.nameText = nameText
    frame.healthText = healthText
    frame.powerText = powerText

    frames[unit] = frame
    return frame
end

local function UpdateFrame(frame)
    local unit = frame.unit

    if not UnitExists(unit) then
        return
    end

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

    UF:SetUnitDisplayName(frame.nameText, unit)
end

local targetTarget = CreateUnitFrame("KamiUITargetTargetFrame", "targettarget")
targetTarget:SetPoint("BOTTOMLEFT", UF.targetFrame, "TOPRIGHT", 2, 2)

local targetTargetTarget =
    CreateUnitFrame("KamiUITargetTargetTargetFrame", "targettargettarget")
targetTargetTarget:SetPoint("LEFT", targetTarget, "RIGHT", 2, 0)

local focus = CreateUnitFrame("KamiUIFocusFrame", "focus")
focus:SetPoint("TOPLEFT", UF.targetFrame, "BOTTOMRIGHT", 2, -2)

local focusTarget = CreateUnitFrame("KamiUIFocusTargetFrame", "focustarget")
focusTarget:SetPoint("LEFT", focus, "RIGHT", 2, 0)

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
