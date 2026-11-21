local UI = KamiUI
local Module = UI:GetModule("ItemRating")

local PREFIX = "Item Rating ("

local function GetLink(tooltip, data)
    if data and data.hyperlink
        and UI:CanAccessValue(data.hyperlink)
        and type(data.hyperlink) == "string" then
        return data.hyperlink
    end

    if tooltip and tooltip.GetItem then
        local _, link = UI:SafeCall(tooltip.GetItem, tooltip)
        if link and UI:CanAccessValue(link)
            and type(link) == "string" then
            return link
        end
    end

    if data and data.id and UI:CanAccessValue(data.id)
        and type(data.id) == "number" then
        return "item:" .. data.id
    end
end

local function HasRatingLine(tooltip)
    local lines = tooltip and tooltip.NumLines
        and tooltip:NumLines() or 0
    local tooltipName = tooltip and tooltip.GetName
        and tooltip:GetName()

    for index = 1, lines do
        local line
        if tooltip.GetLeftLine then
            line = tooltip:GetLeftLine(index)
        elseif tooltipName then
            line = _G[tooltipName .. "TextLeft" .. index]
        end

        if line and line.GetText then
            local text = UI:SafeCall(line.GetText, line)
            if text and UI:CanAccessValue(text)
                and type(text) == "string"
                and string.find(text, PREFIX, 1, true) == 1 then
                return true
            end
        end
    end

    return false
end

local function FormatDifference(delta)
    local color = "|cffb8b8b8"
    if delta > 0.049 then
        color = "|cff40e666"
    elseif delta < -0.049 then
        color = "|cffff6161"
    end

    return string.format("%s%+.1f|r", color, delta)
end

local function FormatScore(score, comparisons)
    local formatted = string.format("%.1f", score)
    if #comparisons == 0 then
        return formatted
    end

    local differences = {}
    for _, comparison in ipairs(comparisons) do
        differences[#differences + 1] =
            FormatDifference(comparison.difference)
    end

    -- Ring/trinket values use slot 1 / slot 2 order; both fit one line.
    return formatted .. " (" .. table.concat(differences, " / ") .. ")"
end

function Module:AppendRating(tooltip, data)
    if not tooltip or not tooltip.AddLine
        or not tooltip.AddDoubleLine or HasRatingLine(tooltip) then
        return
    end

    local profiles = self:GetClassProfiles()
    if #profiles == 0 then return end

    local link = GetLink(tooltip, data)
    if not link then return end
    local itemCache = {}

    -- Show every spec of the player's class, regardless of which
    -- profile is being edited. The editor dropdown affects only edits.
    for _, profile in ipairs(profiles) do
        local result = self:RateItem(link, profile, itemCache)
        if result then
            local label = PREFIX
                .. (profile.shortLabel or profile.label) .. ")"
            if result.score == nil then
                tooltip:AddDoubleLine(
                    label, "Unscored effect",
                    1, 0.78, 0.32,
                    0.65, 0.69, 0.76
                )
            else
                local comparisons =
                    self:GetEquippedComparisons(result, profile, itemCache)
                tooltip:AddDoubleLine(
                    label,
                    FormatScore(result.score, comparisons),
                    1, 0.78, 0.32,
                    1, 0.78, 0.32
                )
            end
        end
    end
end

local function InstallHook()
    if Module.ratingHookInstalled
        or not TooltipDataProcessor
        or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum or not Enum.TooltipDataType
        or not Enum.TooltipDataType.Item then
        return
    end

    Module.ratingHookInstalled = true
    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Item,
        function(tooltip, data)
            Module:AppendRating(tooltip, data)
        end
    )
end

InstallHook()
UI:RegisterEvent("ADDON_LOADED", InstallHook)
