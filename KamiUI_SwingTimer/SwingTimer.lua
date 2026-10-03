local UI = KamiUI

local Module = UI:NewModule("SwingTimer")

Module.name = "KamiUI_SwingTimer"
Module.version = "0.1.0"

local defaults = {
    width = 200,
    height = 15,
    offsetY = 4,
    spacing = 0,
}

local layoutQueued = false
local styledFrames = setmetatable({}, { __mode = "k" })

local _, playerClass = UnitClass("player")

local function ShouldShowRangedTimer()
    return playerClass == "HUNTER"
end

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

local function StyleFrame(frame)
    if not frame or styledFrames[frame] then
        return
    end

    styledFrames[frame] = true

    -- Replace Blizzard's decorative swing-timer frame with the same simple
    -- 1 px black border used by the rest of KamiUI.
    if frame.Border then
        frame.Border:Hide()
    end

    if frame.StatusBar then
        frame.StatusBar:ClearAllPoints()
        frame.StatusBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetColorTexture(0, 0, 0, 1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    bottom:SetColorTexture(0, 0, 0, 1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    left:SetColorTexture(0, 0, 0, 1)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    right:SetColorTexture(0, 0, 0, 1)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
end

local function ConfigureFrame(frame)
    if not frame then
        return
    end

    DetachFromFrameManager(frame)
    frame:SetScale(1)
    frame:SetSize(defaults.width, defaults.height)
    StyleFrame(frame)
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
        SwingTimerOffHandFrame,
        SwingTimerMainHandFrame,
    }

    if ShouldShowRangedTimer() then
        table.insert(frames, 1, SwingTimerRangedFrame)
    elseif SwingTimerRangedFrame then
        SwingTimerRangedFrame:Hide()
    end

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

    frame:HookScript("OnShow", function(self)
        if self == SwingTimerRangedFrame and not ShouldShowRangedTimer() then
            self:Hide()
            return
        end

        QueueLayout()
    end)

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
