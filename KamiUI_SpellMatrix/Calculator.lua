local UI = KamiUI
local Module = UI:GetModule("SpellMatrix")

local function Divide(value, divisor)
    value = tonumber(value)
    divisor = tonumber(divisor)

    if not value
        or not divisor
        or divisor <= 0
    then
        return nil
    end

    return value / divisor
end

local function BuildMetricSet(
    output,
    throughputTime,
    executionTime,
    resourceCost
)
    return {
        throughput = Divide(output, throughputTime),
        execution = Divide(output, executionTime),
        efficiency = Divide(output, resourceCost),
    }
end

function Module:CalculateMetrics(data)
    if not data then
        return nil
    end

    local direct = tonumber(data.direct) or 0
    local periodic = tonumber(data.periodic) or 0
    local total = direct + periodic

    if total <= 0 then
        return nil
    end

    local fullDuration = data.periodicDuration
        or data.executionTime

    data.total = total
    data.metrics = {
        full = BuildMetricSet(
            total,
            fullDuration,
            data.executionTime,
            data.resourceCost
        ),
    }

    if direct > 0 and periodic > 0 then
        data.metrics.spam = BuildMetricSet(
            direct,
            data.executionTime,
            data.executionTime,
            data.resourceCost
        )
    end

    return data
end
