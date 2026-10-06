local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local FRAME_Y = -250

local frame = UF:CreatePrimaryFrame({
    name = "KamiUITargetFrame",
    unit = "target",
    portraitSide = "RIGHT",
    nameWidth = 110,
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
        FRAME_Y + UI:GetBottomInset()
    )
end

local function UpdateAll()
    UF:UpdateUnitFrame(frame)
end

local function OnTargetEvent(event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateAll()
    elseif unit == "target" then
        if event == "UNIT_HEALTH"
            or event == "UNIT_MAXHEALTH"
            or event == "UNIT_FACTION"
        then
            UF:UpdateHealth(frame)
        elseif event == "UNIT_POWER_UPDATE"
            or event == "UNIT_POWER_FREQUENT"
            or event == "UNIT_MAXPOWER"
            or event == "UNIT_DISPLAYPOWER"
        then
            UF:UpdatePower(frame)
        elseif event == "UNIT_NAME_UPDATE"
            or event == "UNIT_PORTRAIT_UPDATE"
            or event == "UNIT_MODEL_CHANGED"
        then
            UF:UpdateIdentity(frame)
        end
    end
end

local function OnCastEvent(_, unit)
    if unit == "target" then
        UF:UpdateCast(frame)
    end
end

PositionFrame()

UI:RegisterBottomInsetCallback(PositionFrame)

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if layoutPending then
        PositionFrame()
    end
end)

UI:RegisterEvent("PLAYER_TARGET_CHANGED", OnTargetEvent)
UI:RegisterEvent("UNIT_HEALTH", OnTargetEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnTargetEvent)
UI:RegisterEvent("UNIT_FACTION", OnTargetEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnTargetEvent)
UI:RegisterEvent("UNIT_POWER_FREQUENT", OnTargetEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnTargetEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnTargetEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnTargetEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnTargetEvent)
UI:RegisterEvent("UNIT_MODEL_CHANGED", OnTargetEvent)

UI:RegisterEvent("UNIT_SPELLCAST_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_STOP", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_FAILED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_DELAYED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", OnCastEvent)

UF.targetFrame = frame
