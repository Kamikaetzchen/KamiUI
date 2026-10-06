local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local frames = {}

local function CreateUnitFrame(name, unit)
    local frame = UF:CreateCompactFrame({
        name = name,
        unit = unit,
        width = 150,
        height = 25,
        healthHeight = 13,
        powerHeight = 9,
        nameWidth = 105,
        nameFontOffset = -1,
        healthFontOffset = -1,
    })

    frames[unit] = frame
    return frame
end

local function UpdateFrame(frame)
    UF:UpdateUnitFrame(frame)
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
UI:RegisterEvent("UNIT_FACTION", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnUnitEvent)
UI:RegisterEvent("UNIT_POWER_FREQUENT", OnUnitEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnUnitEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnUnitEvent)

UF.targetTargetFrame = targetTarget
UF.targetTargetTargetFrame = targetTargetTarget
UF.focusFrame = focus
UF.focusTargetFrame = focusTarget
