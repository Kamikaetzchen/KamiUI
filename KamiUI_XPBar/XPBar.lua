local UI = KamiUI

local Module = UI:NewModule("XPBar")

Module.name = "KamiUI_XPBar"
Module.version = "0.1.0"

local defaults = {
    height = UI.defaults.layout.xpBarHeight,
    background = { 0.02, 0.02, 0.02, 0.95 },
    restedColor = { 0.10, 0.55, 0.95, 1 },
    xpColor = { 0.12, 0.32, 0.85, 1 },
}

local function HideNativeXPBar()
    if not StatusTrackingBarManager then
        return
    end

    for _, container in ipairs(
        StatusTrackingBarManager.barContainers or {}
    ) do
        for _, bar in pairs(container.bars or {}) do
            if bar.isExpBar then
                bar:SetAlpha(0)

                if bar.EnableMouse then
                    bar:EnableMouse(false)
                end

                if not bar.KamiXPBarHiddenHooked then
                    bar.KamiXPBarHiddenHooked = true

                    bar:HookScript("OnShow", function(self)
                        self:SetAlpha(0)

                        if self.EnableMouse then
                            self:EnableMouse(false)
                        end
                    end)
                end
            end
        end
    end
end

local function CreateBar()
    if Module.frame then
        return
    end

    local frame = CreateFrame(
        "Frame",
        "KamiUIXPBar",
        UIParent,
        "BackdropTemplate"
    )
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    frame:SetHeight(defaults.height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    frame:SetBackdropColor(unpack(defaults.background))

    local restedBar = CreateFrame("StatusBar", nil, frame)
    restedBar:SetAllPoints(frame)
    restedBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    restedBar:SetStatusBarColor(unpack(defaults.restedColor))

    local xpBar = CreateFrame("StatusBar", nil, frame)
    xpBar:SetAllPoints(frame)
    xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    xpBar:SetStatusBarColor(unpack(defaults.xpColor))
    xpBar:SetFrameLevel(restedBar:GetFrameLevel() + 1)

    frame.restedBar = restedBar
    frame.xpBar = xpBar
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
            end)
        end
    end)
end

Module:Initialize()
