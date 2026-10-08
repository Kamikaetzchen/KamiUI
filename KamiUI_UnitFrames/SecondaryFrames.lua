local UI = KamiUI
local UF = UI:GetModule("UnitFrames")
local Layout = UI.Layout.UnitFrames.Secondary

local function CreateUnitFrame(name, unit)
    return UF:CreateCompactFrame({
        name = name,
        unit = unit,
        width = Layout.WIDTH,
        height = Layout.HEIGHT,
        healthHeight = Layout.HEALTH_HEIGHT,
        powerHeight = Layout.POWER_HEIGHT,
        nameWidth = Layout.NAME_WIDTH,
        nameFontOffset = Layout.FONT_OFFSET,
        healthFontOffset = Layout.FONT_OFFSET,
        features = {
            indicators = true,
            healPrediction = unit == "focus",
            range = true,
        },
    })
end

local targetTarget = CreateUnitFrame(
    "KamiUITargetTargetFrame",
    "targettarget"
)
targetTarget:SetPoint("BOTTOMLEFT", UF.targetFrame, "TOPRIGHT", 2, 2)

local targetTargetTarget = CreateUnitFrame(
    "KamiUITargetTargetTargetFrame",
    "targettargettarget"
)
targetTargetTarget:SetPoint("LEFT", targetTarget, "RIGHT", 2, 0)

local focus = CreateUnitFrame("KamiUIFocusFrame", "focus")
focus:SetPoint("TOPLEFT", UF.targetFrame, "BOTTOMRIGHT", 2, -2)

local focusTarget = CreateUnitFrame(
    "KamiUIFocusTargetFrame",
    "focustarget"
)
focusTarget:SetPoint("LEFT", focus, "RIGHT", 2, 0)

local function UpdateTargetChain()
    UF:UpdateUnitFrame(targetTarget)
    UF:UpdateUnitFrame(targetTargetTarget)
end

local function UpdateFocusChain()
    UF:UpdateUnitFrame(focus)
    UF:UpdateUnitFrame(focusTarget)
end

UI:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateTargetChain)
UI:RegisterEvent("PLAYER_FOCUS_CHANGED", UpdateFocusChain)

UI:RegisterEvent("UNIT_TARGET", function(_, unit)
    if unit == "target" then
        UpdateTargetChain()
    elseif unit == "targettarget" then
        UF:UpdateUnitFrame(targetTargetTarget)
    elseif unit == "focus" then
        UF:UpdateUnitFrame(focusTarget)
    end
end)

UF.targetTargetFrame = targetTarget
UF.targetTargetTargetFrame = targetTargetTarget
UF.focusFrame = focus
UF.focusTargetFrame = focusTarget
