local UI = KamiUI
local Module = UI:GetModule("SpellMatrix")

local HEADING_COLOR = { 0.40, 0.80, 1.00 }
local LABEL_COLOR = { 0.85, 0.85, 0.85 }
local VALUE_COLOR = { 1.00, 1.00, 1.00 }

local function GetSpellID(tooltip, data)
    if data then
        local spellID = data.id or data.spellID

        if spellID and UI:CanAccessValue(spellID) then
            return tonumber(spellID)
        end
    end

    if tooltip and tooltip.GetSpell then
        local _name, spellID = tooltip:GetSpell()

        if spellID and UI:CanAccessValue(spellID) then
            return tonumber(spellID)
        end
    end

    return nil
end

local function FormatMetricLine(label, value)
    return string.format(
        "%s  %s",
        label,
        Module:FormatMetric(value)
    )
end

local function AddSingleMetrics(tooltip, analysis, labels)
    local full = analysis.metrics.full

    tooltip:AddDoubleLine(
        labels.throughput,
        Module:FormatMetric(full.throughput),
        LABEL_COLOR[1],
        LABEL_COLOR[2],
        LABEL_COLOR[3],
        VALUE_COLOR[1],
        VALUE_COLOR[2],
        VALUE_COLOR[3]
    )

    if labels.efficiency and full.efficiency then
        tooltip:AddDoubleLine(
            labels.efficiency,
            Module:FormatMetric(full.efficiency),
            LABEL_COLOR[1],
            LABEL_COLOR[2],
            LABEL_COLOR[3],
            VALUE_COLOR[1],
            VALUE_COLOR[2],
            VALUE_COLOR[3]
        )
    end

    tooltip:AddDoubleLine(
        labels.execution,
        Module:FormatMetric(full.execution),
        LABEL_COLOR[1],
        LABEL_COLOR[2],
        LABEL_COLOR[3],
        VALUE_COLOR[1],
        VALUE_COLOR[2],
        VALUE_COLOR[3]
    )
end

local function AddMixedMetrics(tooltip, analysis, labels)
    local spam = analysis.metrics.spam
    local full = analysis.metrics.full

    tooltip:AddDoubleLine(
        "Spam",
        "Full duration",
        HEADING_COLOR[1],
        HEADING_COLOR[2],
        HEADING_COLOR[3],
        HEADING_COLOR[1],
        HEADING_COLOR[2],
        HEADING_COLOR[3]
    )

    tooltip:AddDoubleLine(
        FormatMetricLine(
            labels.throughput,
            spam.throughput
        ),
        FormatMetricLine(
            labels.throughput,
            full.throughput
        ),
        LABEL_COLOR[1],
        LABEL_COLOR[2],
        LABEL_COLOR[3],
        VALUE_COLOR[1],
        VALUE_COLOR[2],
        VALUE_COLOR[3]
    )

    if labels.efficiency
        and spam.efficiency
        and full.efficiency
    then
        tooltip:AddDoubleLine(
            FormatMetricLine(
                labels.efficiency,
                spam.efficiency
            ),
            FormatMetricLine(
                labels.efficiency,
                full.efficiency
            ),
            LABEL_COLOR[1],
            LABEL_COLOR[2],
            LABEL_COLOR[3],
            VALUE_COLOR[1],
            VALUE_COLOR[2],
            VALUE_COLOR[3]
        )
    end

    tooltip:AddDoubleLine(
        FormatMetricLine(
            labels.execution,
            spam.execution
        ),
        FormatMetricLine(
            labels.execution,
            full.execution
        ),
        LABEL_COLOR[1],
        LABEL_COLOR[2],
        LABEL_COLOR[3],
        VALUE_COLOR[1],
        VALUE_COLOR[2],
        VALUE_COLOR[3]
    )
end

local function ResetTooltipMarker(tooltip)
    tooltip.KamiSpellMatrixSpellID = nil
end

local function AddSpellAnalysis(tooltip, data)
    if not tooltip
        or tooltip.KamiSpellMatrixScanner
    then
        return
    end

    local spellID = GetSpellID(tooltip, data)

    if not spellID
        or tooltip.KamiSpellMatrixSpellID == spellID
    then
        return
    end

    local analysis = Module:GetSpellAnalysis(spellID)

    if not analysis then
        return
    end

    tooltip.KamiSpellMatrixSpellID = spellID

    if tooltip.HookScript
        and not tooltip.KamiSpellMatrixResetHook
    then
        tooltip.KamiSpellMatrixResetHook = true
        tooltip:HookScript(
            "OnHide",
            ResetTooltipMarker
        )

        if tooltip.HasScript
            and tooltip:HasScript("OnTooltipCleared")
        then
            tooltip:HookScript(
                "OnTooltipCleared",
                ResetTooltipMarker
            )
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(
        "Spell Matrix",
        unpack(HEADING_COLOR)
    )

    local labels = Module:GetMetricLabels(analysis)

    if analysis.metrics.spam then
        AddMixedMetrics(tooltip, analysis, labels)
    else
        AddSingleMetrics(tooltip, analysis, labels)
    end
end

local function InstallTooltipHook()
    if Module.tooltipHookInstalled then
        return
    end

    if TooltipDataProcessor
        and TooltipDataProcessor.AddTooltipPostCall
        and Enum
        and Enum.TooltipDataType
        and Enum.TooltipDataType.Spell
    then
        Module.tooltipHookInstalled = true

        TooltipDataProcessor.AddTooltipPostCall(
            Enum.TooltipDataType.Spell,
            AddSpellAnalysis
        )
    elseif GameTooltip
        and GameTooltip.HookScript
        and GameTooltip.HasScript
        and GameTooltip:HasScript("OnTooltipSetSpell")
    then
        Module.tooltipHookInstalled = true
        GameTooltip:HookScript(
            "OnTooltipSetSpell",
            AddSpellAnalysis
        )
    end
end

InstallTooltipHook()

UI:RegisterEvent("ADDON_LOADED", function()
    InstallTooltipHook()
end)
