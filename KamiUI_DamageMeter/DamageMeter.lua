local UI = KamiUI

local Module = UI:NewModule("DamageMeter")

Module.name = "KamiUI_DamageMeter"
Module.version = "0.1.0"

local defaults = {
    x = 0,
    y = 10,
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

    ClearPoints(DamageMeter)
    SetPoint(
        DamageMeter,
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        defaults.x,
        defaults.y
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
    if not DamageMeter or DamageMeter.KamiLayoutHooked then
        return
    end

    DamageMeter.KamiLayoutHooked = true
    DamageMeter:HookScript("OnShow", QueueLayout)

    if DamageMeter.ApplySystemAnchor then
        hooksecurefunc(DamageMeter, "ApplySystemAnchor", QueueLayout)
    end
end

function Module:Initialize()
    HookDamageMeter()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            HookDamageMeter()
            Module:Apply()
        end)
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
