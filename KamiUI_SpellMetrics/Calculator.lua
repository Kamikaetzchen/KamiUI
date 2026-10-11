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

local function GetPhysicalCritChance()
    if not GetCritChance then return nil end
    local chance = GetCritChance()
    if not UI:CanAccessValue(chance)
        or type(chance) ~= "number" then
        return nil
    end
    return math.max(0, math.min(100, chance))
end

function Module:CalculateMetrics(data)
    if not data then
        return nil
    end

    local direct = tonumber(data.direct) or 0
    local periodic = tonumber(data.periodic) or 0
    -- Physical Feral attacks and bleeds use the player's melee crit chance.
    -- A 200% crit adds one extra normal hit on average.
    local critChance
    if data.outputType == "damage"
        and (data.resourceType == "Energy"
            or data.resourceType == "Rage") then
        critChance = GetPhysicalCritChance()
    end
    local critMultiplier = critChance and (1 + critChance / 100) or 1
    data.critChance = critChance
    direct = direct * critMultiplier
    periodic = periodic * critMultiplier
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
                local amount = variant.amount * critMultiplier
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
