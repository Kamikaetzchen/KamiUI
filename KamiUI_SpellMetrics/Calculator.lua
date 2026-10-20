local UI = KamiUI
local Module = UI:GetModule("SpellMetrics")

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

    -- Apply per-component expected crit with an explicit source/profile.
    -- Physical feral calculations retain the original 2x behavior.
    -- Unknown spell schools are intentionally not guessed.
    local directFactor, directCrit =
        self:GetExpectedCritFactor(data, "direct")
    local periodicFactor, periodicCrit =
        self:GetExpectedCritFactor(data, "periodic")

    data.critComponents = {
        direct = direct > 0 and directCrit or nil,
        periodic = periodic > 0 and periodicCrit or nil,
    }
    data.critChance = directCrit and directCrit.chance
        or periodicCrit and periodicCrit.chance

    direct = direct * directFactor
    periodic = periodic * periodicFactor
    local total = direct + periodic

    if total <= 0 then
        return nil
    end

    local fullDuration = data.periodicDuration
        or data.executionTime

    if data.comboVariants then
        data.comboMetrics = {}
        for points = 1, 5 do
            local variant = data.comboVariants[points]
            if variant then
                local comboFactor, comboCrit =
                    self:GetExpectedCritFactor(data, "combo")
                data.critComponents.combo = comboCrit
                local amount = variant.amount * comboFactor
                local duration = variant.duration
                data.comboMetrics[points] = {
                    damage = amount,
                    duration = duration,
                    dps = Divide(amount, duration or data.executionTime),
                    efficiency = Divide(amount, data.resourceCost),
                }
            end
        end
    end

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
