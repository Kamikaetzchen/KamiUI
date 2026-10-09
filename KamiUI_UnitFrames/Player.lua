local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Player
local HUDFrame = UI.Layout.UnitFrames.HUD

local frame = UF:CreatePrimaryFrame({
    name = "KamiUIPlayerFrame",
    unit = "player",
    portraitSide = "LEFT",
    watch = false,
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

UF:CreatePrimaryHUDArt(frame, false)

local layoutPending = false

local function PositionFrame()
    if InCombatLockdown and InCombatLockdown() then
        layoutPending = true
        return
    end

    layoutPending = false
    frame:ClearAllPoints()
    frame:SetPoint(
        "RIGHT",
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

UF.playerFrame = frame
