local UI = KamiUI
local Module = UI:GetModule("SpellMatrix")

local NUMBER = "([%d,]+%.?%d*)"

local RESOURCE_TYPES = {
    ["mana"] = "Mana",
    ["energy"] = "Energy",
    ["rage"] = "Rage",
    ["focus"] = "Focus",
}

local scanner

local function CleanText(text)
    if type(text) ~= "string"
        or not UI:CanAccessValue(text)
    then
        return nil
    end

    text = text
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("\194\160", " ")
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$")

    if text == "" then
        return nil
    end

    return text
end

local function ParseNumber(value)
    if not value then
        return nil
    end

    return tonumber((value:gsub(",", "")))
end

local function AddText(texts, value)
    value = CleanText(value)

    if value then
        texts[#texts + 1] = value
    end
end

local function ReadTooltipData(data)
    if type(data) ~= "table"
        or type(data.lines) ~= "table"
    then
        return nil
    end

    local texts = {}

    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            AddText(texts, line.leftText)
            AddText(texts, line.rightText)
        end
    end

    return #texts > 0 and texts or nil
end

local function GetScanner()
    if scanner then
        return scanner
    end

    scanner = CreateFrame(
        "GameTooltip",
        "KamiUISpellMatrixScanner",
        UIParent,
        "GameTooltipTemplate"
    )
    scanner.KamiSpellMatrixScanner = true
    scanner:SetOwner(UIParent, "ANCHOR_NONE")

    return scanner
end

local function ReadScannerSpell(spellID)
    local tooltip = GetScanner()

    if not tooltip.SetSpellByID then
        return nil
    end

    tooltip:ClearLines()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetSpellByID(spellID)

    local texts = {}
    local name = tooltip:GetName()

    for index = 1, tooltip:NumLines() do
        AddText(
            texts,
            _G[name .. "TextLeft" .. index]
                and _G[name .. "TextLeft" .. index]:GetText()
        )
        AddText(
            texts,
            _G[name .. "TextRight" .. index]
                and _G[name .. "TextRight" .. index]:GetText()
        )
    end

    tooltip:Hide()

    return #texts > 0 and texts or nil
end

function Module:GetSpellTooltipTexts(spellID)
    spellID = tonumber(spellID)

    if not spellID then
        return nil
    end

    if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
        local data = UI:SafeCall(
            C_TooltipInfo.GetSpellByID,
            spellID
        )
        local texts = ReadTooltipData(data)

        if texts then
            return texts
        end
    end

    return ReadScannerSpell(spellID)
end

local function ParseResourceAmount(lower, token)
    local amount = lower:match(
        "^"
        .. NUMBER
        .. "%s+"
        .. token
        .. "%f[%A]"
    )

    return ParseNumber(amount)
end

local function ParseResourceCost(texts)
    for _, text in ipairs(texts) do
        local lower = string.lower(text)

        for token, resourceType in pairs(RESOURCE_TYPES) do
            local amount = ParseResourceAmount(lower, token)

            if amount then
                return amount, resourceType
            end
        end
    end

    return nil, nil
end

local function ParseCastMetadata(texts)
    local castTime
    local instant = false
    local channeled = false

    for _, text in ipairs(texts) do
        local lower = string.lower(text)

        if lower == "instant"
            or lower == "instant cast"
        then
            instant = true
        end

        local seconds = lower:match(
            "^([%d%.]+)%s*sec%s+cast"
        )

        if seconds then
            castTime = tonumber(seconds)
        end

        if string.find(lower, "channeled", 1, true)
            or string.find(lower, "channelled", 1, true)
        then
            channeled = true
        end
    end

    return castTime, instant, channeled
end

local function IsMetadataText(text, index)
    local lower = string.lower(text)

    if index == 1
        or lower:match("^rank%s+%d+")
        or lower == "instant"
        or lower == "instant cast"
        or lower:match("^[%d%.]+%s*sec%s+cast")
        or lower == "channeled"
        or lower == "channelled"
        or lower:find("yd range", 1, true)
        or lower == "melee range"
        or lower:find("cooldown", 1, true)
    then
        return true
    end

    for token in pairs(RESOURCE_TYPES) do
        if ParseResourceAmount(lower, token) then
            return true
        end
    end

    return false
end

local function BuildDescription(texts)
    local parts = {}

    for index, text in ipairs(texts) do
        if not IsMetadataText(text, index) then
            parts[#parts + 1] = text
        end
    end

    return table.concat(parts, " ")
end

local function IsNextSwingAbility(lower)
    return lower:find("next melee attack", 1, true)
        or lower:find("next melee swing", 1, true)
        or lower:find("next weapon attack", 1, true)
        or lower:find("next weapon swing", 1, true)
        or lower:find("on your next attack", 1, true)
end

local function IsPartialWeaponDamage(lower)
    return lower:find(
        "in addition to your normal weapon damage",
        1,
        true
    ) ~= nil
end

local function ParseComboPointDamage(lower)
    local bestAmount
    local bestDuration
    local bestPoints = 0

    local pointPatterns = {
        "(%d+)%s+points?%s*:%s*",
        "(%d+)%s+combo%s+points?%s*:%s*",
    }

    for _, pointPattern in ipairs(pointPatterns) do
        local periodicPattern =
            pointPattern
            .. NUMBER
            .. "%s+[%a%s]-damage%s+over%s+"
            .. NUMBER
            .. "%s*sec"

        for points, amount, duration in lower:gmatch(
            periodicPattern
        ) do
            points = tonumber(points)
            amount = ParseNumber(amount)
            duration = tonumber(duration)

            if points
                and amount
                and duration
                and (
                    points == 5
                    or (
                        bestPoints ~= 5
                        and points > bestPoints
                    )
                )
            then
                bestPoints = points
                bestAmount = amount
                bestDuration = duration
            end
        end
    end

    if bestAmount then
        return bestAmount, bestDuration, bestPoints
    end

    for _, pointPattern in ipairs(pointPatterns) do
        local directPattern =
            pointPattern
            .. NUMBER
            .. "%s+[%a%s]-damage"

        for points, amount in lower:gmatch(directPattern) do
            points = tonumber(points)
            amount = ParseNumber(amount)

            if points
                and amount
                and (
                    points == 5
                    or (
                        bestPoints ~= 5
                        and points > bestPoints
                    )
                )
            then
                bestPoints = points
                bestAmount = amount
            end
        end
    end

    return bestAmount, nil, bestPoints > 0 and bestPoints or nil
end

local function ParsePeriodicDamage(lower)
    local count, amount, duration = lower:match(
        "(%d+)%s+waves?%s+of%s+"
        .. NUMBER
        .. "%s+[%a%s]*damage%s+over%s+"
        .. NUMBER
        .. "%s*sec"
    )

    count = tonumber(count)
    amount = ParseNumber(amount)
    duration = tonumber(duration)

    if count and amount and duration then
        return count * amount, duration
    end

    local everyAmount, interval, everyDuration = lower:match(
        NUMBER
        .. "%s+[%a%s]*damage%s+every%s+"
        .. NUMBER
        .. "%s*sec%s+for%s+"
        .. NUMBER
        .. "%s*sec"
    )

    everyAmount = ParseNumber(everyAmount)
    interval = tonumber(interval)
    everyDuration = tonumber(everyDuration)

    if everyAmount
        and interval
        and interval > 0
        and everyDuration
    then
        return everyAmount
            * math.floor(everyDuration / interval + 0.001),
            everyDuration
    end

    local total, overDuration = lower:match(
        NUMBER
        .. "%s+[%a%s]*damage%s+over%s+"
        .. NUMBER
        .. "%s*sec"
    )

    total = ParseNumber(total)
    overDuration = tonumber(overDuration)

    if total and overDuration then
        return total, overDuration
    end

    return nil, nil
end

local function ParsePeriodicHealing(lower)
    local amount, duration = lower:match(
        "heals?.-for%s+"
        .. NUMBER
        .. "%s+over%s+"
        .. NUMBER
        .. "%s*sec"
    )

    amount = ParseNumber(amount)
    duration = tonumber(duration)

    if amount and duration then
        return amount, duration
    end

    amount, duration = lower:match(
        "healing.-for%s+"
        .. NUMBER
        .. "%s+over%s+"
        .. NUMBER
        .. "%s*sec"
    )

    amount = ParseNumber(amount)
    duration = tonumber(duration)

    if amount and duration then
        return amount, duration
    end

    amount, duration = lower:match(
        "restores?%s+"
        .. NUMBER
        .. "%s+health%s+over%s+"
        .. NUMBER
        .. "%s*sec"
    )

    amount = ParseNumber(amount)
    duration = tonumber(duration)

    if amount and duration then
        return amount, duration
    end

    amount, duration = lower:match(
        "another%s+"
        .. NUMBER
        .. "%s+over%s+"
        .. NUMBER
        .. "%s*sec"
    )

    amount = ParseNumber(amount)
    duration = tonumber(duration)

    if amount and duration then
        return amount, duration
    end

    return nil, nil
end

local function ParseDirectDamage(lower, hasPeriodic)
    local low, high, finish = lower:match(
        NUMBER
        .. "%s+to%s+"
        .. NUMBER
        .. "%s+[%a%s]*damage()"
    )

    low = ParseNumber(low)
    high = ParseNumber(high)

    if low and high then
        local after = finish and lower:sub(finish) or ""

        if not after:match("^%s+over%s+") then
            return (low + high) / 2
        end
    end

    local patterns

    if hasPeriodic then
        patterns = {
            "deals%s+" .. NUMBER .. "%s+[%a%s]*damage%s+and",
            "causes%s+" .. NUMBER .. "%s+[%a%s]*damage%s+and",
            "for%s+" .. NUMBER .. "%s+[%a%s]*damage%s+and",
        }
    else
        patterns = {
            "deals%s+" .. NUMBER .. "%s+[%a%s]*damage",
            "causes%s+" .. NUMBER .. "%s+[%a%s]*damage",
            "causing%s+" .. NUMBER .. "%s+[%a%s]*damage",
            "inflicts%s+" .. NUMBER .. "%s+[%a%s]*damage",
            "for%s+" .. NUMBER .. "%s+[%a%s]*damage",
        }
    end

    for _, pattern in ipairs(patterns) do
        local amount = ParseNumber(lower:match(pattern))

        if amount then
            return amount
        end
    end

    return nil
end

local function ParseDirectHealing(lower, hasPeriodic)
    local low, high = lower:match(
        "heals?.-for%s+"
        .. NUMBER
        .. "%s+to%s+"
        .. NUMBER
    )

    low = ParseNumber(low)
    high = ParseNumber(high)

    if low and high then
        return (low + high) / 2
    end

    low, high = lower:match(
        "restores?%s+"
        .. NUMBER
        .. "%s+to%s+"
        .. NUMBER
        .. "%s+health"
    )

    low = ParseNumber(low)
    high = ParseNumber(high)

    if low and high then
        return (low + high) / 2
    end

    local patterns

    if hasPeriodic then
        patterns = {
            "heals?.-for%s+" .. NUMBER .. "%s+and",
            "restores?%s+" .. NUMBER .. "%s+health%s+and",
        }
    else
        patterns = {
            "heals?.-for%s+" .. NUMBER,
            "restores?%s+" .. NUMBER .. "%s+health",
        }
    end

    for _, pattern in ipairs(patterns) do
        local amount = ParseNumber(lower:match(pattern))

        if amount then
            return amount
        end
    end

    return nil
end

local function GetFallbackCastTime(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = UI:SafeCall(
            C_Spell.GetSpellInfo,
            spellID
        )

        if type(info) == "table"
            and tonumber(info.castTime)
            and info.castTime > 0
        then
            return info.castTime / 1000
        end
    end

    if GetSpellInfo then
        local _name, _rank, _icon, castMS =
            UI:SafeCall(GetSpellInfo, spellID)

        castMS = tonumber(castMS)

        if castMS and castMS > 0 then
            return castMS / 1000
        end
    end

    return nil
end

local function GetInstantExecutionTime(resourceType)
    if resourceType == "Energy" then
        return 1.0
    end

    return 1.5
end

function Module:BuildSpellData(spellID)
    local texts = self:GetSpellTooltipTexts(spellID)

    if not texts then
        return nil, "noTooltip"
    end

    local description = BuildDescription(texts)
    local lower = string.lower(description)

    if IsNextSwingAbility(lower) then
        return nil, "nextSwing"
    end

    if IsPartialWeaponDamage(lower) then
        return nil, "partialWeaponDamage"
    end

    local cost, resourceType = ParseResourceCost(texts)
    local castTime, instant, channeled =
        ParseCastMetadata(texts)

    castTime = castTime or GetFallbackCastTime(spellID)

    local comboDamage, comboDuration, comboPoints =
        ParseComboPointDamage(lower)
    local periodicDamage, damageDuration =
        ParsePeriodicDamage(lower)
    local periodicHealing, healingDuration =
        ParsePeriodicHealing(lower)

    local comboDirectDamage

    if comboDamage then
        if comboDuration or damageDuration then
            periodicDamage = comboDamage
            damageDuration = comboDuration or damageDuration
        else
            comboDirectDamage = comboDamage
        end
    end

    local directDamage = comboDirectDamage or ParseDirectDamage(
        lower,
        periodicDamage ~= nil
    )
    local directHealing = ParseDirectHealing(
        lower,
        periodicHealing ~= nil
    )

    local damageTotal =
        (directDamage or 0) + (periodicDamage or 0)
    local healingTotal =
        (directHealing or 0) + (periodicHealing or 0)

    if damageTotal > 0 and healingTotal > 0 then
        return nil, "mixedDamageHealing"
    end

    local outputType
    local direct
    local periodic
    local periodicDuration

    if damageTotal > 0 then
        outputType = "damage"
        direct = directDamage
        periodic = periodicDamage
        periodicDuration = damageDuration
    elseif healingTotal > 0 then
        outputType = "healing"
        direct = directHealing
        periodic = periodicHealing
        periodicDuration = healingDuration
    else
        return nil, "noOutput"
    end

    local executionTime

    if castTime and castTime > 0 then
        executionTime = castTime
    elseif channeled and periodicDuration then
        executionTime = periodicDuration
    elseif instant
        or direct
        or periodic
    then
        executionTime =
            GetInstantExecutionTime(resourceType)
    end

    if not executionTime or executionTime <= 0 then
        return nil, "noExecutionTime"
    end

    return {
        spellID = spellID,
        name = texts[1],
        description = description,
        outputType = outputType,
        direct = direct,
        periodic = periodic,
        periodicDuration = periodicDuration,
        resourceCost = cost,
        resourceType = resourceType,
        comboPoints = comboPoints,
        castTime = castTime,
        instant = instant,
        channeled = channeled,
        executionTime = executionTime,
    }
end

function Module:GetSpellAnalysis(spellID)
    spellID = tonumber(spellID)

    if not spellID then
        return nil, "invalidSpell"
    end

    local cached = self.analysisCache[spellID]

    if cached then
        return cached.analysis, cached.reason
    end

    local data, reason = self:BuildSpellData(spellID)
    local analysis

    if data and self.CalculateMetrics then
        analysis = self:CalculateMetrics(data)
    end

    self.analysisCache[spellID] = {
        analysis = analysis,
        reason = reason,
    }

    return analysis, reason
end

UI:RegisterCommand(
    "spellmatrix",
    "debug",
    function(value)
        local spellID = tonumber(value)

        if not spellID then
            UI:Print(
                "Usage: /kami spellmatrix debug <spellID>"
            )
            return
        end

        Module:InvalidateCache()

        local texts = Module:GetSpellTooltipTexts(spellID)

        UI:Print("Spell Matrix tooltip:", spellID)

        for index, text in ipairs(texts or {}) do
            UI:Print(index .. ":", text)
        end

        local analysis, reason =
            Module:GetSpellAnalysis(spellID)

        if not analysis then
            UI:Print("Unsupported:", reason or "unknown")
            return
        end

        UI:Print(
            "Parsed:",
            analysis.outputType,
            "direct=" .. tostring(analysis.direct or 0),
            "periodic=" .. tostring(analysis.periodic or 0),
            "duration=" .. tostring(
                analysis.periodicDuration or 0
            ),
            "execution=" .. tostring(
                analysis.executionTime or 0
            ),
            "cost=" .. tostring(
                analysis.resourceCost or 0
            ),
            tostring(analysis.resourceType or ""),
            "comboPoints=" .. tostring(
                analysis.comboPoints or 0
            )
        )
    end,
    "Dump parsed spell tooltip data"
)
