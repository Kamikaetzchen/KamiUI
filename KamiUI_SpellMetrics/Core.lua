local UI = KamiUI

local Module = UI:NewModule(
    "SpellMetrics",
    "KamiUI_SpellMetrics"
)

Module.defaults = {
    refreshDelay = 0.08,
}

Module.analysisCache = {}
-- Retain the last valid estimate when the client temporarily hides
-- weapon values during combat. Ordinary invalidation still forces a
-- fresh calculation as soon as those values become accessible again.
Module.lastValidAnalyses = {}

function Module:InvalidateCache()
    wipe(self.analysisCache)
end

function Module:FormatMetric(value)
    value = tonumber(value)

    if not value then
        return "-"
    end

    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    elseif value >= 100 then
        return string.format("%.0f", value)
    elseif value >= 10 then
        return string.format("%.1f", value)
    end

    return string.format("%.2f", value)
end

function Module:GetMetricLabels(analysis)
    local prefix = analysis.outputType == "healing"
        and "H"
        or "D"

    local labels = {
        throughput = prefix .. "PS",
        execution = prefix .. "PET",
    }

    local resourceCodes = {
        Mana = "M",
        Energy = "E",
        Rage = "R",
        Focus = "F",
    }

    local code = resourceCodes[analysis.resourceType]

    if code then
        labels.efficiency = prefix .. "P" .. code
    end

    return labels
end

function Module:GetButtonMetric(analysis)
    return analysis
        and analysis.metrics
        and analysis.metrics.full
        and analysis.metrics.full.execution
end
