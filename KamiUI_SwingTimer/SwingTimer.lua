local UI = KamiUI

local Module = UI:NewModule("SwingTimer")

Module.name = "KamiUI_SwingTimer"
Module.version = "0.1.0"

local defaults = {
    width = 200,
    height = 15,
    offsetY = 2,
    spacing = 0,
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

local function DetachFromFrameManager(frame)
    if frame.BreakFromFrameManager then
        frame:BreakFromFrameManager()
        return
    end

    frame.ignoreFramePositionManager = true

    if GetBottomManagedFrameContainer then
        local container = GetBottomManagedFrameContainer()

        if container and container.RemoveManagedFrame then
            container:RemoveManagedFrame(frame)
        end
    end
end

local function ConfigureFrame(frame)
    if not frame then
        return
    end

    DetachFromFrameManager(frame)
    frame:SetScale(1)
    frame:SetSize(defaults.width, defaults.height)
end

local function HasAppropriateWeapon(frame)
    if not frame then
        return false
    end

    if frame.HasAppropriateWeapon then
        return frame:HasAppropriateWeapon()
    end

    return true
end

function Module:Apply()
    if not KamiUIPlayerFrame then
        return false
    end

    local frames = {
        SwingTimerRangedFrame,
        SwingTimerOffHandFrame,
        SwingTimerMainHandFrame,
    }

    for _, frame in ipairs(frames) do
        ConfigureFrame(frame)
    end

    local previous

    for _, frame in ipairs(frames) do
        if HasAppropriateWeapon(frame) then
            ClearPoints(frame)

            if previous then
                SetPoint(
                    frame,
                    "BOTTOMLEFT",
                    previous,
                    "TOPLEFT",
                    0,
                    defaults.spacing
                )
            else
                SetPoint(
                    frame,
                    "BOTTOMLEFT",
                    KamiUIPlayerFrame,
                    "TOPLEFT",
                    0,
                    defaults.offsetY
                )
            end

            previous = frame
        end
    end

    return SwingTimerMainHandFrame ~= nil
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

local function HookFrame(frame)
    if not frame or frame.KamiLayoutHooked then
        return
    end

    frame.KamiLayoutHooked = true

    frame:HookScript("OnShow", QueueLayout)

    for _, method in ipairs({
        "ApplySystemAnchor",
        "UpdateFramePositions",
        "UpdateSystemSettingScale",
        "UpdateSystemSettingWidth",
        "UpdateSystemSettingHeight",
    }) do
        if frame[method] then
            hooksecurefunc(frame, method, QueueLayout)
        end
    end
end

local function HookFrames()
    HookFrame(SwingTimerMainHandFrame)
    HookFrame(SwingTimerOffHandFrame)
    HookFrame(SwingTimerRangedFrame)
end

function Module:Initialize()
    HookFrames()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            HookFrames()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("WEAPON_SLOT_CHANGED", function()
        QueueLayout()
    end)

    UI:RegisterEvent("UNIT_ATTACK_SPEED", function(_, unit)
        if unit == "player" then
            QueueLayout()
        end
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_SwingTimer" then
            C_Timer.After(0, function()
                HookFrames()
                Module:Apply()
            end)
        end
    end)
end

Module:Initialize()
