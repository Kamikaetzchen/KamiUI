local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Module = UI:GetModule("SpellMetrics")

local refreshPending = false
local invalidatePending = false

local fontPath, _, fontFlags =
    GameFontNormalSmall:GetFont()


local function GetColorHex(color)
    if not color then
        return "ffffff"
    end

    local r = color.r or color[1] or 1
    local g = color.g or color[2] or 1
    local b = color.b or color[3] or 1

    return string.format(
        "%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
end

local function ColorizeMetric(value, color)
    return "|cff"
        .. GetColorHex(color)
        .. value
        .. "|r"
end

local function GetActionBars()
    return UI.GetModule
        and UI:GetModule("ActionBars")
end

local function ForEachActionButton(callback)
    local actionBars = GetActionBars()

    if not actionBars or not actionBars.bars then
        return
    end

    for _, bar in pairs(actionBars.bars) do
        for _, button in ipairs(bar.buttons or {}) do
            callback(button)
        end
    end
end

local function EnsureMetricOverlay(button)
    if button.KamiSpellMetricsText then
        return button.KamiSpellMetricsText
    end

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 20)
    overlay:EnableMouse(false)

    local text = overlay:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", overlay, "LEFT", 2, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)

    local size = button:GetWidth() <= 30
        and Styles.FontSize.SpellMetrics.buttonSmall
        or Styles.FontSize.SpellMetrics.button

    text:SetFont(
        fontPath,
        size,
        "OUTLINE"
    )
    text:SetTextColor(1, 1, 1, 1)

    button.KamiSpellMetricsOverlay = overlay
    button.KamiSpellMetricsText = text

    return text
end

local function GetButtonSpellID(button)
    if not button or not button.GetSpellId then
        return nil
    end

    local spellID = UI:SafeCall(
        button.GetSpellId,
        button
    )

    if not spellID
        or not UI:CanAccessValue(spellID)
    then
        return nil
    end

    return tonumber(spellID)
end

local function RefreshButton(button)
    local text = EnsureMetricOverlay(button)
    local spellID = GetButtonSpellID(button)

    if not spellID then
        text:SetText("")
        return
    end

    local analysis = Module:GetSpellAnalysis(spellID)
    local full = analysis
        and analysis.metrics
        and analysis.metrics.full
    local execution = full and full.execution

    if not execution then
        text:SetText("")
        return
    end

    local outputColor = analysis.outputType == "healing"
        and Palette.success
        or Palette.damage

    local value = ColorizeMetric(
        (analysis.weaponEstimate and "~" or "")
            .. Module:FormatMetric(execution),
        outputColor
    )

    if full.efficiency then
        local resourceColor = {
            0x33 / 255,
            0xAA / 255,
            0xFF / 255,
            1,
        }

        value = value
            .. "\n"
            .. ColorizeMetric(
                (analysis.weaponEstimate and "~" or "")
                    .. Module:FormatMetric(full.efficiency),
                resourceColor
            )
    end

    text:SetText(value)
end

function Module:RefreshActionButtons(invalidate)
    refreshPending = false

    if invalidate or invalidatePending then
        self:InvalidateCache()
    end

    invalidatePending = false

    ForEachActionButton(RefreshButton)
end

function Module:ScheduleActionButtonRefresh(invalidate)
    invalidatePending = invalidatePending
        or invalidate == true

    if refreshPending then
        return
    end

    refreshPending = true

    local function Refresh()
        Module:RefreshActionButtons()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(
            self.defaults.refreshDelay,
            Refresh
        )
    else
        Refresh()
    end
end

local function RefreshWithNewValues()
    Module:ScheduleActionButtonRefresh(true)
end

local function RefreshActions()
    Module:ScheduleActionButtonRefresh(false)
end

Module:RefreshActionButtons(true)

UI:RegisterEvent(
    "PLAYER_ENTERING_WORLD",
    RefreshWithNewValues
)
UI:RegisterEvent(
    "PLAYER_EQUIPMENT_CHANGED",
    RefreshWithNewValues
)
-- Damage and attack power can change from buffs or temporary modifiers
-- without an equipment change. Recompute estimates from fresh UnitDamage.
for _, event in ipairs({
    "UNIT_DAMAGE",
    "UNIT_ATTACK_POWER",
    "UNIT_ATTACK_SPEED",
    "UNIT_STATS",
}) do
    UI:RegisterEvent(event, function(_, unit)
        if unit == "player" then
            RefreshWithNewValues()
        end
    end)
end
UI:RegisterEvent(
    "PLAYER_LEVEL_UP",
    RefreshWithNewValues
)
UI:RegisterEvent(
    "SPELLS_CHANGED",
    RefreshWithNewValues
)

UI:RegisterEvent("UNIT_AURA", function(_, unit)
    if unit == "player" then
        RefreshWithNewValues()
    end
end)

UI:RegisterEvent(
    "ACTIONBAR_SLOT_CHANGED",
    RefreshActions
)
UI:RegisterEvent(
    "ACTIONBAR_PAGE_CHANGED",
    RefreshActions
)
UI:RegisterEvent(
    "UPDATE_BONUS_ACTIONBAR",
    RefreshActions
)
UI:RegisterEvent(
    "UPDATE_SHAPESHIFT_FORM",
    RefreshWithNewValues
)
UI:RegisterEvent(
    "UPDATE_MACROS",
    RefreshActions
)

UI:RegisterCommand(
    "spellmetrics",
    "refresh",
    function()
        Module:RefreshActionButtons(true)
    end,
    "Refresh Spell Metrics action button values"
)
