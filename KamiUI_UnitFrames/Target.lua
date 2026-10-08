local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Target

local frame = UF:CreatePrimaryFrame({
    name = "KamiUITargetFrame",
    unit = "target",
    portraitSide = "RIGHT",
    nameWidth = 110,
    features = {
        indicators = true,
        healPrediction = true,
        range = true,
    },
})

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
        UIParent,
        "CENTER",
        1,
        Layout.FRAME_Y + UI:GetBottomInset()
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
