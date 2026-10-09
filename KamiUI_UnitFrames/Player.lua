local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Player

local frame = UF:CreatePrimaryFrame({
    name = "KamiUIPlayerFrame",
    unit = "player",
    portraitSide = "LEFT",
    watch = false,
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
        "RIGHT",
        UIParent,
        "CENTER",
        -1,
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

UF.playerFrame = frame
