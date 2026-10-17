local UI = KamiUI
local Module = UI:GetModule("SpellMetrics")

local Palette = UI.Palette
local HEADING_COLOR = { 0.40, 0.80, 1.00 }
local SECTION_COLOR = Palette.gold
local LABEL_COLOR = Palette.text
local VALUE_COLOR = Palette.highlight

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

-- Keep the label/value alignment within each section, but stack
-- the Spam and Full duration comparisons vertically.
local function AddMetricRow(tooltip, label, value)
    if value == nil then
        return
    end

    tooltip:AddDoubleLine(
        label,
        Module:FormatMetric(value),
        LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3],
        VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3]
    )
end

local function AddMetricSet(tooltip, metrics, labels)
    AddMetricRow(tooltip, labels.throughput, metrics.throughput)

    if labels.efficiency and metrics.efficiency then
        AddMetricRow(tooltip, labels.efficiency, metrics.efficiency)
    end

    AddMetricRow(tooltip, labels.execution, metrics.execution)
end

local function AddSingleMetrics(tooltip, analysis, labels)
    AddMetricSet(tooltip, analysis.metrics.full, labels)
end

local function AddMixedMetrics(tooltip, analysis, labels)
    tooltip:AddLine("Spam", unpack(SECTION_COLOR))
    AddMetricSet(tooltip, analysis.metrics.spam, labels)

    tooltip:AddLine("Full duration", unpack(SECTION_COLOR))
    AddMetricSet(tooltip, analysis.metrics.full, labels)
end

local function AddComboMetrics(tooltip, analysis)
    if not analysis.comboMetrics then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("Combo point breakdown", unpack(HEADING_COLOR))
    tooltip:AddDoubleLine(
        "CP    Damage    DPS",
        analysis.resourceCost and "Damage / resource" or "",
        unpack(HEADING_COLOR)
    )

    for points = 1, 5 do
        local metric = analysis.comboMetrics[points]
        if metric then
            local left = string.format(
                "%d       %s       %s",
                points,
                Module:FormatMetric(metric.damage),
                Module:FormatMetric(metric.dps)
            )
            tooltip:AddDoubleLine(
                left,
                metric.efficiency
                    and Module:FormatMetric(metric.efficiency) or "",
                LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3],
                VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3]
            )
        end
    end
end

local function ResetTooltipMarker(tooltip)
    tooltip.KamiSpellMetricsSpellID = nil
end

local function AddSpellAnalysis(tooltip, data)
    if not tooltip
        or tooltip.KamiSpellMetricsScanner
    then
        return
    end

    local spellID = GetSpellID(tooltip, data)

    if not spellID
        or tooltip.KamiSpellMetricsSpellID == spellID
    then
        return
    end

    local analysis = Module:GetSpellAnalysis(spellID)

    if not analysis then
        return
    end

    tooltip.KamiSpellMetricsSpellID = spellID

    if tooltip.HookScript
        and not tooltip.KamiSpellMetricsResetHook
    then
        tooltip.KamiSpellMetricsResetHook = true
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
        "Spell Metrics",
        unpack(HEADING_COLOR)
    )

    local labels = Module:GetMetricLabels(analysis)

    if analysis.metrics.spam then
        AddMixedMetrics(tooltip, analysis, labels)
    else
        AddSingleMetrics(tooltip, analysis, labels)
    end

    AddComboMetrics(tooltip, analysis)

    if analysis.critChance then
        tooltip:AddLine(
            string.format("Expected damage incl. %.1f%% melee crit (2x).",
                analysis.critChance),
            0.65, 0.65, 0.68
        )
    end

    if analysis.weaponEstimate then
        tooltip:AddLine(
            "~ Weapon damage estimate (before armor/misses).",
            0.65, 0.65, 0.68,
            true
        )

        if analysis.weaponKind == "weapon" then
            tooltip:AddLine(
                "Instant-attack weapon normalization not included.",
                0.65, 0.65, 0.68,
                true
            )
        end
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
