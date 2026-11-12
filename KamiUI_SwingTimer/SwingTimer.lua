local UI = KamiUI

local Module = UI:NewModule("SwingTimer", "KamiUI_SwingTimer")
local Layout = UI.Layout.SwingTimer
local Styles = UI.Styles

local _, playerClass = UnitClass("player")

-- Forever provides one authoritative, readable event per player swing.
-- Fresh weapon speeds from UnitAttackSpeed/UnitRangedDamage may be secret in
-- combat, so only use PLAYER_SWING's duration for timing calculations.
local HANDS = {
    [0] = "mainhand",
    [1] = "offhand",
    [2] = "ranged",
}
local ORDER = { "ranged", "offhand", "mainhand" }
local RANGED_WINDUP = 0.5 -- Conservative stop-moving window at base haste.
local nativeSuppressed = setmetatable({}, { __mode = "k" })

Module.bars = {}
Module.autoShooting = false

local function SuppressNativeTimers()
    if InCombatLockdown and InCombatLockdown() then
        Module.nativePending = true
        return
    end

    Module.nativePending = false
    for _, frame in ipairs({
        SwingTimerMainHandFrame,
        SwingTimerOffHandFrame,
        SwingTimerRangedFrame,
    }) do
        if frame and not nativeSuppressed[frame] then
            nativeSuppressed[frame] = true
            frame:Hide()
            -- Parent to KamiUI's permanently hidden sink, so Blizzard's
            -- own visibility updates cannot resurrect its textured bars.
            UI:KeepFrameHidden(frame)
        end
    end
end

local function CreateBar(hand)
    local frame = CreateFrame("Frame", "KamiUISwingTimer" .. hand, UIParent)
    frame:SetSize(Layout.WIDTH, Layout.HEIGHT)
    frame:SetAlpha(0.80)
    frame:EnableMouse(false)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0.025, 0.025, 0.025, 0.82)

    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(Layout.HEIGHT - 2)
    fill:SetWidth(0.01)
    if hand == "ranged" then
        -- YaHT's centered fill: white shrinks inward after a shot, then
        -- red grows outward while the stationary wind-up completes.
        fill:SetPoint("CENTER", frame, "CENTER", 0, 0)
        fill:SetColorTexture(0.93, 0.93, 0.89, 1)
    else
        fill:SetPoint("LEFT", frame, "LEFT", 1, 0)
        if hand == "mainhand" then
            fill:SetColorTexture(0.90, 0.68, 0.24, 1)
        else
            fill:SetColorTexture(0.40, 0.75, 0.97, 1)
        end
    end

    Styles:CreateBorder(frame, {
        color = { 0, 0, 0, 1 },
    })

    -- Countdown stays centered above the animated fill on both melee and
    -- ranged bars, including YaHT's red Auto Shot wind-up.
    local timeText = frame:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    timeText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    timeText:SetTextColor(1, 1, 1)
    timeText:SetShadowColor(0, 0, 0, 1)
    timeText:SetShadowOffset(1, -1)
    timeText:SetText("")

    frame.timeText = timeText
    frame.shownTenth = nil
    frame.fill = fill
    frame.hand = hand
    frame.lastSwing = nil
    frame.speed = nil
    frame.windupStart = nil
    frame.phase = nil
    frame:Hide()
    return frame
end

local function LayoutBars()
    if not KamiUIPlayerFrame then return end

    local previous
    for _, hand in ipairs(ORDER) do
        local bar = Module.bars[hand]
        if bar and bar:IsShown() then
            bar:ClearAllPoints()
            if previous then
                bar:SetPoint("BOTTOMLEFT", previous, "TOPLEFT",
                    0, Layout.SPACING)
            else
                bar:SetPoint("BOTTOMLEFT", KamiUIPlayerFrame, "TOPLEFT",
                    0, Layout.OFFSET_Y)
            end
            previous = bar
        end
    end
end

local function SetPhase(bar, phase)
    if bar.phase == phase then return end
    bar.phase = phase
    if phase == "windup" then
        bar.fill:SetColorTexture(1, 0.18, 0.18, 1)
    else
        bar.fill:SetColorTexture(0.93, 0.93, 0.89, 1)
    end
end

local function SetFill(bar, fraction)
    local width = math.max(0.01,
        (Layout.WIDTH - 2) * math.max(0, math.min(fraction, 1)))
    bar.fill:SetWidth(width)
end

local function IsMoving()
    if not IsPlayerMoving then return false end
    local moving = IsPlayerMoving()
    -- Never use restricted/secret values for branching.
    if not UI:CanAccessValue(moving) then return false end
    return moving == true
end

local function SetRemaining(bar, seconds)
    if not seconds then
        if bar.shownTenth ~= nil then
            bar.timeText:SetText("")
            bar.shownTenth = nil
        end
        return
    end

    -- Round upward to avoid showing 0.0 while the swing is still pending.
    local tenth = math.max(0, math.ceil(math.max(0, seconds) * 10))
    if bar.shownTenth ~= tenth then
        bar.timeText:SetText(string.format("%.1f", tenth / 10))
        bar.shownTenth = tenth
    end
end

local function UpdateRanged(bar, now)
    local speed = bar.speed
    if not speed or not bar.lastSwing then
        if Module.autoShooting then
            -- First shot has no preceding PLAYER_SWING anchor yet.
            SetPhase(bar, "windup")
            if IsMoving() then
                bar.windupStart = nil
                SetFill(bar, 0)
                return RANGED_WINDUP
            else
                bar.windupStart = bar.windupStart or now
                local elapsed = now - bar.windupStart
                SetFill(bar, elapsed / RANGED_WINDUP)
                return math.max(0, RANGED_WINDUP - elapsed)
            end
        end
        return nil
    end

    local windup = math.min(RANGED_WINDUP, speed)
    local recovery = math.max(0, speed - windup)
    local elapsed = math.max(0, now - bar.lastSwing)

    if elapsed < recovery then
        bar.windupStart = nil
        SetPhase(bar, "cooldown")
        if recovery > 0 then
            SetFill(bar, 1 - elapsed / recovery)
        else
            SetFill(bar, 0)
        end
        return math.max(0, speed - elapsed)
    end

    SetPhase(bar, "windup")
    if IsMoving() then
        -- Running during the red window interrupts the preparation.
        -- A new shot event re-anchors the entire timeline precisely.
        bar.windupStart = nil
        SetFill(bar, 0)
        return windup
    else
        if not bar.windupStart then
            bar.windupStart = math.max(bar.lastSwing + recovery, now - 0.02)
        end
        local elapsedWindup = now - bar.windupStart
        SetFill(bar, elapsedWindup / math.max(0.01, windup))
        return math.max(0, windup - elapsedWindup)
    end
end

local function UpdateMelee(bar, now)
    if not bar.speed or not bar.lastSwing then return nil end
    local elapsed = math.max(0, now - bar.lastSwing)
    SetFill(bar, elapsed / bar.speed)
    return math.max(0, bar.speed - elapsed)
end

local function UpdateBars()
    local now = GetTime()
    for hand, bar in pairs(Module.bars) do
        if bar:IsShown() then
            local remaining
            if hand == "ranged" then
                remaining = UpdateRanged(bar, now)
            else
                remaining = UpdateMelee(bar, now)
            end
            SetRemaining(bar, remaining)
            -- Do not leave a stale timer on screen after the attack stops.
            if bar.lastSwing and bar.speed
                and now - bar.lastSwing > math.max(6, bar.speed * 3)
                and not (hand == "ranged" and Module.autoShooting)
            then
                bar:Hide()
                LayoutBars()
            end
        end
    end
end

local function StartSwing(duration, swingType)
    -- Both values are plain on the Forever PLAYER_SWING event, including
    -- while weapon-stat APIs are restricted. Keep guards for future builds.
    if not UI:CanAccessValue(duration)
        or not UI:CanAccessValue(swingType)
        or type(duration) ~= "number"
        or type(swingType) ~= "number"
        or duration <= 0
    then
        return
    end

    local hand = HANDS[swingType]
    local bar = hand and Module.bars[hand]
    if not bar then return end

    bar.lastSwing = GetTime()
    bar.speed = duration
    bar.windupStart = nil
    bar.phase = nil
    SetRemaining(bar, duration)

    if not bar:IsShown() then
        bar:Show()
        LayoutBars()
    end

    if hand == "ranged" then
        SetPhase(bar, "cooldown")
        SetFill(bar, 1)
    else
        SetFill(bar, 0)
    end
end

local function ResetBars()
    for _, bar in pairs(Module.bars) do
        bar.lastSwing = nil
        bar.speed = nil
        bar.windupStart = nil
        bar.phase = nil
        SetRemaining(bar, nil)
        bar:Hide()
    end
end

function Module:Apply()
    if not next(self.bars) then
        for _, hand in ipairs(ORDER) do
            if hand ~= "ranged" or playerClass == "HUNTER" then
                self.bars[hand] = CreateBar(hand)
            end
        end
        -- A lightweight visual update; timing comes from PLAYER_SWING.
        self.driver = CreateFrame("Frame")
        self.driver:SetScript("OnUpdate", UpdateBars)
    end

    SuppressNativeTimers()
    LayoutBars()
end

function Module:Initialize()
    self:Apply()

    UI:RegisterEvent("PLAYER_SWING", function(_, duration, swingType)
        StartSwing(duration, swingType)
    end)

    if playerClass == "HUNTER" then
        UI:RegisterEvent("START_AUTOREPEAT_SPELL", function()
            Module.autoShooting = true
            local ranged = Module.bars.ranged
            if ranged and not ranged:IsShown() then
                ranged:Show()
                LayoutBars()
            end
        end)
        UI:RegisterEvent("STOP_AUTOREPEAT_SPELL", function()
            Module.autoShooting = false
        end)
    end

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module.autoShooting = false
        ResetBars()
        C_Timer.After(0, function() Module:Apply() end)
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        Module.autoShooting = false
        ResetBars()
        if Module.nativePending then SuppressNativeTimers() end
    end)

    UI:RegisterEvent("PLAYER_DEAD", function()
        Module.autoShooting = false
        ResetBars()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        C_Timer.After(0, function() Module:Apply() end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_SwingTimer" then
            C_Timer.After(0, SuppressNativeTimers)
        end
    end)
end

Module:Initialize()
