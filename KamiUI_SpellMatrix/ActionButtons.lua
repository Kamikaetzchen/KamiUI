local UI = KamiUI
local Palette = UI.Palette
local Module = UI:GetModule("SpellMatrix")

local refreshPending = false
local invalidatePending = false

local fontPath, _, fontFlags =
    GameFontNormalSmall:GetFont()

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
    if button.KamiSpellMatrixText then
        return button.KamiSpellMatrixText
    end

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 20)
    overlay:EnableMouse(false)

    local text = overlay:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOPLEFT", overlay, "TOPLEFT", 2, -2)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)

    local size = button:GetWidth() <= 30
        and Module.defaults.buttonFontSizeSmall
        or Module.defaults.buttonFontSize

    text:SetFont(
        fontPath,
        size,
        fontFlags or "OUTLINE"
    )

    local color = Palette.gold

    if color then
        text:SetTextColor(
            color.r or color[1] or 1,
            color.g or color[2] or 0.82,
            color.b or color[3] or 0,
            1
        )
    else
        text:SetTextColor(1, 0.82, 0, 1)
    end

    button.KamiSpellMatrixOverlay = overlay
    button.KamiSpellMatrixText = text

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
    local value = Module:GetButtonMetric(analysis)

    if not value then
        text:SetText("")
        return
    end

    text:SetText(Module:FormatMetric(value))
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
    "spellmatrix",
    "refresh",
    function()
        Module:RefreshActionButtons(true)
    end,
    "Refresh Spell Matrix action button values"
)
