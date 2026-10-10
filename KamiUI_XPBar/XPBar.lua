local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("XPBar", "KamiUI_XPBar")


local Layout = UI.Layout.XPBar

local function GetEffectiveMaxLevel()
    if GameRulesUtil and GameRulesUtil.GetEffectiveMaxLevelForPlayer then
        return GameRulesUtil.GetEffectiveMaxLevelForPlayer()
    end

    if GetMaxPlayerLevel then
        return GetMaxPlayerLevel()
    end
end

local function IsPlayerAtMaxLevel()
    local level = UnitLevel("player")
    local maxLevel = GetEffectiveMaxLevel()

    return level and level > 0 and maxLevel and level >= maxLevel
end

-- Watched reputation also determines whether the XPBar stays visible at max level.
local function GetWatchedReputationData()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = UI:SafeCall(C_Reputation.GetWatchedFactionData)

        if type(data) == "table" and data.name then
            return data
        end
    end

    if GetWatchedFactionInfo then
        local name,
            reaction,
            lower,
            upper,
            standing,
            factionID = UI:SafeCall(GetWatchedFactionInfo)

        if name then
            return {
                name = name,
                reaction = reaction,
                currentReactionThreshold = lower,
                nextReactionThreshold = upper,
                currentStanding = standing,
                factionID = factionID,
            }
        end
    end

    return nil
end

local function SuppressNativeTrackingBars()
    local manager = _G.StatusTrackingBarManager

    if not manager then
        return
    end

    -- Preserve Blizzard's tracking backend; only suppress its visuals/input.
    -- OnShow re-suppression and recursive mouse suppression are handled in Core.
    local options = { persistent = true, children = true }
    UI:SuppressFrame(manager, options)

    -- Containers may be re-created or shown independently of the manager.
    for _, container in ipairs(manager.barContainers or {}) do
        UI:SuppressFrame(container, options)
    end
end

local function GetReputationProgress(data)
    if not data then
        return nil
    end

    local lower = tonumber(data.currentReactionThreshold) or 0
    local upper = tonumber(data.nextReactionThreshold) or lower
    local standing = tonumber(data.currentStanding) or lower

    if upper <= lower then
        return 1, 1
    end

    local maximum = upper - lower
    local current = math.max(
        0,
        math.min(maximum, standing - lower)
    )

    return current, maximum
end

local function GetReputationColor(data)
    local reaction = data and tonumber(data.reaction)
    local color = reaction
        and FACTION_BAR_COLORS
        and FACTION_BAR_COLORS[reaction]

    if color then
        return color.r, color.g, color.b
    end

    return 0.18, 0.55, 0.18
end

local function UpdateDividers(frame)
    if not frame.dividers then
        frame.dividers = {}

        for index = 1, Layout.SEGMENTS - 1 do
            -- The high-level overlay keeps the segment markers in front
            -- of both the purple XP fill and the blue rested fill.
            local divider = frame.overlay:CreateTexture(nil, "OVERLAY")
            divider:SetColorTexture(unpack(Palette.xpBar.divider))
            divider:SetWidth(1)
            frame.dividers[index] = divider
        end
    end

    local width = frame:GetWidth()

    if width <= 2 then
        return
    end

    local innerWidth = width - 2
    local segmentWidth = innerWidth / Layout.SEGMENTS
    local topInset = frame.hasReputation and frame.hasExperience and 4 or 1

    for index = 1, Layout.SEGMENTS - 1 do
        local divider = frame.dividers[index]
        local x = 1 + math.floor(index * segmentWidth + 0.5)

        divider:ClearAllPoints()
        divider:SetPoint(
            "TOPLEFT",
            frame,
            "TOPLEFT",
            x,
            -topInset
        )
        divider:SetPoint(
            "BOTTOMLEFT",
            frame,
            "BOTTOMLEFT",
            x,
            1
        )
    end
end

local function LayoutBars(frame, hasExperience, hasReputation)
    frame.hasExperience = hasExperience == true
    frame.hasReputation = hasReputation == true

    frame.restedBar:ClearAllPoints()
    frame.xpBar:ClearAllPoints()
    frame.reputationBar:ClearAllPoints()

    frame.restedBar:SetShown(frame.hasExperience)
    frame.xpBar:SetShown(frame.hasExperience)
    frame.reputationBar:SetShown(frame.hasReputation)
    frame.reputationDivider:SetShown(
        frame.hasExperience and frame.hasReputation
    )

    if frame.hasReputation then
        frame.reputationBar:SetPoint(
            "TOPLEFT", frame, "TOPLEFT", 1, -1
        )
        frame.reputationBar:SetPoint(
            "TOPRIGHT", frame, "TOPRIGHT", -1, -1
        )

        if frame.hasExperience then
            frame.reputationBar:SetHeight(2)
        else
            -- At max level the watched reputation occupies all 10 px.
            frame.reputationBar:SetPoint(
                "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1
            )
        end
    end

    if frame.hasExperience then
        local topInset = frame.hasReputation and 4 or 1

        for _, bar in ipairs({ frame.restedBar, frame.xpBar }) do
            bar:SetPoint(
                "TOPLEFT", frame, "TOPLEFT", 1, -topInset
            )
            bar:SetPoint(
                "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1
            )
        end
    end

    UpdateDividers(frame)
end

local function ShowTooltip(frame)
    GameTooltip:SetOwner(frame, Styles.Tooltip.anchor)
    GameTooltip:ClearLines()

    if frame.reputationData then
        local data = frame.reputationData
        local r, g, b = GetReputationColor(data)

        GameTooltip:AddLine(data.name or "Reputation", r, g, b)
        GameTooltip:AddLine(
            string.format(
                "%s/%s",
                UI:FormatNumber(frame.reputationCurrent or 0),
                UI:FormatNumber(frame.reputationMaximum or 0)
            ),
            1, 1, 1
        )

        if frame.hasExperience then
            GameTooltip:AddLine(" ")
        end
    end

    if frame.hasExperience then
        local currentXP = UnitXP("player") or 0
        local maxXP = UnitXPMax("player") or 0
        local restedXP = GetXPExhaustion and GetXPExhaustion() or 0
        restedXP = restedXP or 0

        -- Cache the values actually displayed. While hovered, poll them
        -- briefly because rested XP can tick without a tooltip refresh.
        frame.tooltipCurrentXP = currentXP
        frame.tooltipMaxXP = maxXP
        frame.tooltipRestedXP = restedXP

        GameTooltip:AddLine("Experience", 1, 0.82, 0)

        local text = string.format(
            "%s/%s",
            UI:FormatNumber(currentXP),
            UI:FormatNumber(maxXP)
        )

        if maxXP > 0 and restedXP > 0 then
            local restedPercent = restedXP / maxXP * 100
            text = string.format(
                "%s (+%.1f%% rested, %s XP)",
                text,
                restedPercent,
                UI:FormatNumber(restedXP)
            )
        end

        GameTooltip:AddLine(text, 1, 1, 1)
    end

    GameTooltip:Show()
end

local function CreateBar()
    if Module.frame then
        return
    end

    local frame = CreateFrame("Frame", "KamiUIXPBar", UIParent)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    frame:SetHeight(Layout.HEIGHT)
    frame:SetFrameStrata("HIGH")

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(unpack(Palette.xpBar.background))
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.background = background

    local reputationBar = CreateFrame("StatusBar", nil, frame)
    reputationBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    reputationBar:EnableMouse(false)
    reputationBar:Hide()

    local restedBar = CreateFrame("StatusBar", nil, frame)
    restedBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    restedBar:SetStatusBarColor(unpack(Palette.xpBar.rested))
    restedBar:EnableMouse(false)

    local xpBar = CreateFrame("StatusBar", nil, frame)
    xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    xpBar:SetStatusBarColor(unpack(Palette.xpBar.experience))
    xpBar:SetFrameLevel(restedBar:GetFrameLevel() + 1)
    xpBar:EnableMouse(false)

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(
        math.max(
            reputationBar:GetFrameLevel(),
            xpBar:GetFrameLevel()
        ) + 100
    )
    overlay:EnableMouse(true)

    local reputationDivider = overlay:CreateTexture(nil, "OVERLAY")
    reputationDivider:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        0,
        -3
    )
    reputationDivider:SetPoint(
        "TOPRIGHT",
        frame,
        "TOPRIGHT",
        0,
        -3
    )
    reputationDivider:SetHeight(1)
    reputationDivider:SetColorTexture(unpack(Palette.xpBar.border))
    reputationDivider:Hide()

    frame.reputationBar = reputationBar
    frame.reputationDivider = reputationDivider
    frame.restedBar = restedBar
    frame.xpBar = xpBar
    frame.overlay = overlay

    Styles:CreateBorder(overlay, {
        key = "KamiBorder",
        color = Palette.xpBar.border,
    })

    LayoutBars(frame, false)

    frame:SetScript("OnSizeChanged", function(self)
        UpdateDividers(self)
    end)

    overlay:SetScript("OnEnter", function(self)
        self.tooltipUpdateElapsed = 0
        ShowTooltip(frame)
        self:SetScript("OnUpdate", function(hover, elapsed)
            hover.tooltipUpdateElapsed = hover.tooltipUpdateElapsed + elapsed
            if hover.tooltipUpdateElapsed < 0.5 then
                return
            end
            hover.tooltipUpdateElapsed = 0

            -- Only update our own visible tooltip, never another addon
            -- or spell tooltip that might have replaced it.
            if not GameTooltip:IsShown()
                or GameTooltip:GetOwner() ~= frame
                or not frame.hasExperience
            then
                return
            end

            local currentXP = UnitXP("player") or 0
            local maxXP = UnitXPMax("player") or 0
            local restedXP = GetXPExhaustion and GetXPExhaustion() or 0
            restedXP = restedXP or 0

            if currentXP ~= frame.tooltipCurrentXP
                or maxXP ~= frame.tooltipMaxXP
                or restedXP ~= frame.tooltipRestedXP
            then
                ShowTooltip(frame)
            end
        end)
    end)

    overlay:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        GameTooltip:Hide()
    end)

    Module.frame = frame
end

function Module:Refresh()
    CreateBar()
    SuppressNativeTrackingBars()

    local maxXP = UnitXPMax("player") or 0
    local hasExperience = not IsPlayerAtMaxLevel() and maxXP > 0
    local reputationData = GetWatchedReputationData()
    local reputationCurrent
    local reputationMaximum

    if reputationData then
        reputationCurrent, reputationMaximum =
            GetReputationProgress(reputationData)
    end

    local hasReputation = reputationData ~= nil
        and reputationCurrent ~= nil
        and reputationMaximum ~= nil

    if not hasExperience and not hasReputation then
        self.frame:Hide()
        UI:SetBottomInset(0)
        return
    end

    self.frame.reputationData = hasReputation and reputationData or nil
    self.frame.reputationCurrent = hasReputation
        and reputationCurrent or nil
    self.frame.reputationMaximum = hasReputation
        and reputationMaximum or nil

    if hasExperience then
        local currentXP = UnitXP("player") or 0
        local restedXP = GetXPExhaustion and GetXPExhaustion() or 0
        restedXP = restedXP or 0

        self.frame.restedBar:SetMinMaxValues(0, maxXP)
        self.frame.restedBar:SetValue(
            math.min(currentXP + restedXP, maxXP)
        )

        self.frame.xpBar:SetMinMaxValues(0, maxXP)
        self.frame.xpBar:SetValue(currentXP)
    end

    if hasReputation then
        local r, g, b = GetReputationColor(reputationData)

        self.frame.reputationBar:SetMinMaxValues(
            0, reputationMaximum
        )
        self.frame.reputationBar:SetValue(reputationCurrent)
        self.frame.reputationBar:SetStatusBarColor(r, g, b, 1)
    end

    LayoutBars(self.frame, hasExperience, hasReputation)
    self.frame:Show()
    UI:SetBottomInset(Layout.HEIGHT)
end

function Module:Initialize()
    self:Refresh()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_XP_UPDATE", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_LEVEL_UP", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("UPDATE_EXHAUSTION", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("UPDATE_FACTION", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE", function()
        Module:Refresh()
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_StatusTrackingBar" then
            Module:Refresh()
        end
    end)
end

Module:Initialize()
