local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Target
local HUDFrame = UI.Layout.UnitFrames.HUD

local frame = UF:CreatePrimaryFrame({
    name = "KamiUITargetFrame",
    unit = "target",
    portraitSide = "RIGHT",
    width = HUDFrame.WIDTH,
    height = HUDFrame.HEIGHT,
    healthHeight = HUDFrame.HEALTH_HEIGHT,
    powerHeight = HUDFrame.POWER_HEIGHT,
    healthCastHeight = HUDFrame.HEALTH_CAST_HEIGHT,
    powerCastHeight = HUDFrame.POWER_CAST_HEIGHT,
    castHeight = HUDFrame.CAST_HEIGHT,
    nameWidth = HUDFrame.NAME_WIDTH,
    features = {
        indicators = true,
        healPrediction = true,
        range = true,
    },
})

UF:CreatePrimaryHUDArt(frame, true)

local layoutPending = false

local function PositionFrame()
    if InCombatLockdown and InCombatLockdown() then
        layoutPending = true
        return
    end

    layoutPending = false
    frame:ClearAllPoints()
    frame:SetPoint(
        "LEFT",
        Minimap,
        "CENTER",
        Layout.FRAME_X,
        Layout.FRAME_Y
    )
end

PositionFrame()

UI:RegisterBottomInsetCallback(PositionFrame)

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if layoutPending then
        PositionFrame()
    end
end)

UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    UF:UpdateUnitFrame(frame)
end)

UF.targetFrame = frame
