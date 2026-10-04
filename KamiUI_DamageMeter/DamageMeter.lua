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

function Module:Initialize()
    self:Apply()

    UI:RegisterBottomInsetCallback(function()
        QueueLayout()
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        QueueLayout()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_CHANGED", function()
        QueueLayout()
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        QueueLayout()
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_DamageMeter" then
            QueueLayout()
        end
    end)
end

Module:Initialize()
