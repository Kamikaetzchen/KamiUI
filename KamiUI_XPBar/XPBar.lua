local UI = KamiUI
local Styles = UI.Styles

local Module = UI:NewModule("XPBar", "KamiUI_XPBar")


local defaults = {
    height = UI.defaults.layout.xpBarHeight,
    segments = 20,
    background = { 0.10, 0.10, 0.12, 0.50 },
    restedColor = { 0.08, 0.32, 0.72, 0.50 },
    xpColor = { 0.45, 0.16, 0.62, 1 },
    borderColor = { 0, 0, 0, 1 },
    dividerColor = { 0, 0, 0, 0.9 },
}

local function HideNativeDividers(container)
    local pool = container and container.HorizontalDividersPool

    if not pool or not pool.EnumerateActive then
        return
    end

    for divider in pool:EnumerateActive() do
        divider:SetAlpha(0)
    end
end

local function HideNativeXPBar()
    if not StatusTrackingBarManager then
        return
    end

    for _, container in ipairs(
        StatusTrackingBarManager.barContainers or {}
    ) do
        local shownBar = container.GetShownBar
            and container:GetShownBar()
            or nil
        local showingXP = shownBar and shownBar.isExpBar

        if container.BarFrameTexture then
            container.BarFrameTexture:SetAlpha(showingXP and 0 or 1)
        end

        if showingXP then
            HideNativeDividers(container)
        end

        for _, bar in pairs(container.bars or {}) do
            if bar.isExpBar then
                bar:SetAlpha(0)

                if bar.EnableMouse then
                    bar:EnableMouse(false)
                end

            end
        end

    end

end

local function ScheduleNativeXPBarHide()
    HideNativeXPBar()

    if not C_Timer or not C_Timer.After then
        return
    end

    for _, delay in ipairs({ 0, 0.25, 1.0 }) do
        C_Timer.After(delay, HideNativeXPBar)
    end
end

local function UpdateDividers(frame)
    if not frame.dividers then
        frame.dividers = {}

        for index = 1, defaults.segments - 1 do
            local divider = frame:CreateTexture(nil, "OVERLAY")
            divider:SetColorTexture(unpack(defaults.dividerColor))
            divider:SetWidth(1)
            frame.dividers[index] = divider
        end
    end

    local width = frame:GetWidth()

    if width <= 2 then
        return
    end

    local innerWidth = width - 2
    local segmentWidth = innerWidth / defaults.segments

    for index = 1, defaults.segments - 1 do
        local divider = frame.dividers[index]
        local x = 1 + math.floor(index * segmentWidth + 0.5)

        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -1)
        divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 1)
    end
end

local function ShowTooltip(frame)
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local restedXP = GetXPExhaustion and GetXPExhaustion() or 0
    restedXP = restedXP or 0

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Experience", 1, 0.82, 0)

    local text = string.format(
        "%s/%s",
        UI:FormatNumber(currentXP),
        UI:FormatNumber(maxXP)
    )

    if maxXP > 0 and restedXP > 0 then
        local restedPercent = restedXP / maxXP * 100
        text = string.format(
            "%s (+%.1f%% rested)",
            text,
            restedPercent
        )
    end

    GameTooltip:AddLine(text, 1, 1, 1)
    GameTooltip:Show()
end

local function CreateBar()
    if Module.frame then
        return
    end

    local frame = CreateFrame("Frame", "KamiUIXPBar", UIParent)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    frame:SetHeight(defaults.height)
    frame:SetFrameStrata("HIGH")

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(unpack(defaults.background))
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.background = background

    local restedBar = CreateFrame("StatusBar", nil, frame)
    restedBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    restedBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    restedBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    restedBar:SetStatusBarColor(unpack(defaults.restedColor))
    restedBar:EnableMouse(false)

    local xpBar = CreateFrame("StatusBar", nil, frame)
    xpBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    xpBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    xpBar:SetStatusBarColor(unpack(defaults.xpColor))
    xpBar:SetFrameLevel(restedBar:GetFrameLevel() + 1)
    xpBar:EnableMouse(false)

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(xpBar:GetFrameLevel() + 100)
    overlay:EnableMouse(true)

    frame.restedBar = restedBar
    frame.xpBar = xpBar
    frame.overlay = overlay

    Styles:CreateBorder(overlay, {
        key = "KamiBorder",
        color = defaults.borderColor,
    })
    UpdateDividers(overlay)

    frame:SetScript("OnSizeChanged", function(self)
        UpdateDividers(self.overlay)
    end)

    overlay:SetScript("OnEnter", function()
        ShowTooltip(frame)
    end)

    overlay:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    Module.frame = frame
end

function Module:Refresh()
    CreateBar()
    HideNativeXPBar()

    if UI:GetBottomInset() <= 0 then
        self.frame:Hide()
        return
    end

    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0

    if maxXP <= 0 then
        self.frame:Hide()
        return
    end

    local restedXP = GetXPExhaustion and GetXPExhaustion() or 0
    restedXP = restedXP or 0

    self.frame.restedBar:SetMinMaxValues(0, maxXP)
    self.frame.restedBar:SetValue(math.min(currentXP + restedXP, maxXP))

    self.frame.xpBar:SetMinMaxValues(0, maxXP)
    self.frame.xpBar:SetValue(currentXP)

    UpdateDividers(self.frame.overlay)
    self.frame:Show()
end

function Module:Initialize()
    self:Refresh()

    UI:RegisterBottomInsetCallback(function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Refresh()
            ScheduleNativeXPBarHide()
        end)
    end)

    UI:RegisterEvent("PLAYER_XP_UPDATE", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        C_Timer.After(0, function()
            Module:Refresh()
        end)
    end)

    UI:RegisterEvent("UPDATE_EXHAUSTION", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE", function()
        C_Timer.After(0, function()
            Module:Refresh()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_StatusTrackingBar" then
            C_Timer.After(0, function()
                Module:Refresh()
                ScheduleNativeXPBarHide()
            end)
        end
    end)
end

Module:Initialize()
