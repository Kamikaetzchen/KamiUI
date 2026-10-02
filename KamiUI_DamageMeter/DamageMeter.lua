local UI = KamiUI

local Module = UI:NewModule("DamageMeter")

Module.name = "KamiUI_DamageMeter"
Module.version = "0.1.0"

local defaults = {
    x = 0,
    y = 0,
    height = 240,
}

local layoutQueued = false
local damageMeterHooked = false

local function ClearPoints(frame)
    if frame.ClearAllPointsBase then
        frame:ClearAllPointsBase()
    else
        frame:ClearAllPoints()
    end
end

local function SetPoint(frame, ...)
    if frame.SetPointBase then
        frame:SetPointBase(...)
    else
        frame:SetPoint(...)
    end
end

function Module:Apply()
    if not DamageMeter then
        return false
    end

    -- Blizzard's damage-meter rows contain secret values in combat. Calling
    -- Blizzard layout/update methods from addon execution taints that path and
    -- makes later comparisons of those values illegal.
    if InCombatLockdown() or UnitAffectingCombat("player") then
        return false
    end

    DamageMeter:SetHeight(defaults.height)

    ClearPoints(DamageMeter)
    SetPoint(
        DamageMeter,
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        defaults.x,
        defaults.y + UI:GetBottomInset()
    )

    return true
end

local function QueueLayout()
    if layoutQueued then
        return
    end

    layoutQueued = true

    C_Timer.After(0, function()
        layoutQueued = false
        Module:Apply()
    end)
end

local function HookDamageMeter()
    if not DamageMeter or damageMeterHooked then
        return
    end

    damageMeterHooked = true

    -- Keep addon bookkeeping off Blizzard's frame object; writing custom state
    -- onto it is unnecessary taint.
    if DamageMeter.ApplySystemAnchor then
        hooksecurefunc(DamageMeter, "ApplySystemAnchor", QueueLayout)
    end
end

function Module:Initialize()
    HookDamageMeter()
    self:Apply()

    UI:RegisterBottomInsetCallback(function()
        Module:Apply()
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            HookDamageMeter()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        QueueLayout()
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_DamageMeter" then
            C_Timer.After(0, function()
                HookDamageMeter()
                Module:Apply()
            end)
        end
    end)
end

Module:Initialize()
