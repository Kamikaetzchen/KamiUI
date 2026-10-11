local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local Layout = UI.Layout.UnitFrames.Player

local _, playerClass = UnitClass("player")
local isDruid = UI:CanAccessValue(playerClass)
    and playerClass == "DRUID"

local frame = UF:CreatePrimaryFrame({
    name = "KamiUIPlayerFrame",
    unit = "player",
    portraitSide = "LEFT",
    watch = false,
    nameWidth = 110,
    druidMana = isDruid,
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

-- Read both the active resource and the secondary mana when shifting,
-- including shifts performed during combat. These are ordinary display
-- updates on the existing secure Player unit frame, not protected casts.
if isDruid then
    local function RefreshDruidForm()
        UF:UpdatePower(frame)
        UF:UpdateCast(frame)
    end

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORM", RefreshDruidForm)
    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", RefreshDruidForm)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", RefreshDruidForm)
end

UF.playerFrame = frame
