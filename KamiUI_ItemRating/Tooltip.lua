local UI = KamiUI
local Module = UI:GetModule("ItemRating")

local PREFIX = "Item Rating (Cat)"

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

local function AddComparison(tooltip, comparison)
    local delta = comparison.difference
    local r, g, b = 0.72, 0.72, 0.72
    if delta > 0.049 then
        r, g, b = 0.25, 0.9, 0.4
    elseif delta < -0.049 then
        r, g, b = 1, 0.38, 0.38
    end

    tooltip:AddDoubleLine(
        "vs. " .. comparison.label,
        string.format("%+.1f", delta),
        0.72, 0.77, 0.85,
        r, g, b
    )
end

function Module:AppendRating(tooltip, data)
    if not tooltip or not tooltip.AddLine
        or not tooltip.AddDoubleLine or HasRatingLine(tooltip) then
        return
    end

    local profile = self:GetActiveProfile()
    if not profile then
        return
    end

    local link = GetLink(tooltip, data)
    local result = link and self:RateItem(link, profile)
    if not result then
        return
    end

    if result.score == nil then
        tooltip:AddDoubleLine(
            PREFIX, "Unscored effect",
            1, 0.78, 0.32,
            0.65, 0.69, 0.76
        )
        return
    end

    tooltip:AddDoubleLine(
        PREFIX,
        string.format("%.1f pts", result.score),
        1, 0.78, 0.32,
        1, 0.78, 0.32
    )

    for _, comparison in ipairs(
        self:GetEquippedComparisons(result, profile)
    ) do
        AddComparison(tooltip, comparison)
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
