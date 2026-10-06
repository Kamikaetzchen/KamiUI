local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local FRAME_Y = -250

local frame = UF:CreatePrimaryFrame({
    name = "KamiUIPlayerFrame",
    unit = "player",
    portraitSide = "LEFT",
    watch = false,
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
        "RIGHT",
        UIParent,
        "CENTER",
        -1,
        FRAME_Y + UI:GetBottomInset()
    )
end

local function UpdateAll()
    UF:UpdateUnitFrame(frame)
end

local function OnPlayerEvent(event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateAll()
    elseif unit == "player" then
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
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
    if unit == "player" then
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

UI:RegisterEvent("PLAYER_ENTERING_WORLD", OnPlayerEvent)
UI:RegisterEvent("UNIT_HEALTH", OnPlayerEvent)
UI:RegisterEvent("UNIT_MAXHEALTH", OnPlayerEvent)
UI:RegisterEvent("UNIT_POWER_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_POWER_FREQUENT", OnPlayerEvent)
UI:RegisterEvent("UNIT_MAXPOWER", OnPlayerEvent)
UI:RegisterEvent("UNIT_DISPLAYPOWER", OnPlayerEvent)
UI:RegisterEvent("UNIT_NAME_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_PORTRAIT_UPDATE", OnPlayerEvent)
UI:RegisterEvent("UNIT_MODEL_CHANGED", OnPlayerEvent)

UI:RegisterEvent("UNIT_SPELLCAST_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_STOP", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_FAILED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_DELAYED", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", OnCastEvent)
UI:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", OnCastEvent)

UF.playerFrame = frame
