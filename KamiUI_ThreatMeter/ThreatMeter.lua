local UI = KamiUI
local Styles = UI.Styles

local Module = UI:NewModule("ThreatMeter", "KamiUI_ThreatMeter")


local defaults = {
    width = 260,
    titleHeight = 20,
    rowHeight = 20,
    maxRows = 10,
    fontSize = 11,
    barAlpha = 0.45,
    backgroundAlpha = 0.70,
}

local frame
local rows = {}
local updateQueued = false

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(defaults.width, defaults.rowHeight)

    if index == 1 then
        row:SetPoint("TOPRIGHT", frame.titleBar, "BOTTOMRIGHT")
    else
        row:SetPoint("TOPRIGHT", rows[index - 1], "BOTTOMRIGHT")
    end

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.03, 0.03, 0.03, defaults.backgroundAlpha)

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 100)

    local texture = bar:GetStatusBarTexture()
    texture:SetAlpha(defaults.barAlpha)

    local overlay = CreateFrame("Frame", nil, row)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)

    local name = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", row, "LEFT", 5, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    local percent = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    percent:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    percent:SetJustifyH("RIGHT")

    local fontPath, _, fontFlags = GameFontNormal:GetFont()

    if fontPath then
        name:SetFont(fontPath, defaults.fontSize, fontFlags)
        percent:SetFont(fontPath, defaults.fontSize, fontFlags)
    end

    name:SetTextColor(1, 1, 1)
    percent:SetTextColor(1, 1, 1)

    Styles:CreateBorder(row, { color = { 0, 0, 0, 1 } })

    row.bar = bar
    row.name = name
    row.percent = percent
    row:Hide()

    rows[index] = row
end

local function EnsureFrame()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "KamiUIThreatMeter", UIParent)
    frame:SetSize(
        defaults.width,
        defaults.titleHeight + defaults.rowHeight * defaults.maxRows
    )
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    frame:SetFrameStrata("LOW")
    frame:Hide()

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(defaults.width, defaults.titleHeight)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

    local titleBackground = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBackground:SetAllPoints()
    titleBackground:SetColorTexture(
        0.03,
        0.03,
        0.03,
        defaults.backgroundAlpha
    )

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 5, 0)
    title:SetPoint("RIGHT", titleBar, "RIGHT", -5, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("KamiThreat")

    local fontPath, _, fontFlags = GameFontNormal:GetFont()
    if fontPath then
        title:SetFont(fontPath, defaults.fontSize, fontFlags)
    end

    title:SetTextColor(1, 1, 1)
    Styles:CreateBorder(titleBar, { color = { 0, 0, 0, 1 } })

    frame.titleBar = titleBar
    frame.title = title

    for index = 1, defaults.maxRows do
        CreateRow(index)
    end
end

local function GetUnitColor(unit)
    local unitFrames = UI:GetModule("UnitFrames")

    if unitFrames and unitFrames.GetUnitColor then
        return unitFrames:GetUnitColor(unit)
    end

    -- Keep the standalone fallback visually close to UnitFrames in case the
    -- UnitFrames addon is disabled.
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)

        if UI:CanAccessValue(class) and class then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

            if color then
                return color.r * 0.60, color.g * 0.60, color.b * 0.60
            end
        end
    end

    if string.find(unit, "pet") then
        return 0.12, 0.48, 0.12
    end

    return 0.24, 0.24, 0.24
end

local function AddUnitToken(tokens, unit)
    if UnitExists(unit) then
        tokens[#tokens + 1] = unit
    end
end

local function BuildUnitList()
    local tokens = {}

    if IsInRaid() then
        local count = GetNumGroupMembers()

        for index = 1, count do
            AddUnitToken(tokens, "raid" .. index)
            AddUnitToken(tokens, "raidpet" .. index)
        end
    else
        AddUnitToken(tokens, "player")
        AddUnitToken(tokens, "pet")

        local count = GetNumSubgroupMembers()

        for index = 1, count do
            AddUnitToken(tokens, "party" .. index)
            AddUnitToken(tokens, "partypet" .. index)
        end
    end

    return tokens
end

local function GetThreatEntry(unit)
    local isTanking, _, scaledPercentage, rawPercentage, rawThreat =
        UnitDetailedThreatSituation(unit, "target")

    -- Forever can mark threat values secret in restricted contexts. Never
    -- branch on or do arithmetic with them unless the client says we may.
    if not UI:CanAccessValue(isTanking)
        or not UI:CanAccessValue(scaledPercentage)
        or not UI:CanAccessValue(rawPercentage)
        or not UI:CanAccessValue(rawThreat)
        or rawThreat == nil
        or rawThreat <= 0
    then
        return
    end

    local firstName, surname = UnitName(unit)

    if not UI:CanAccessValue(firstName)
        or not firstName
        or firstName == ""
    then
        return
    end

    local name = firstName

    if surname
        and UI:CanAccessValue(surname)
        and surname ~= ""
    then
        name = firstName .. " " .. surname
    end

    local r, g, b = GetUnitColor(unit)

    return {
        unit = unit,
        name = name,
        threat = rawThreat,
        isTanking = isTanking,
        scaledPercentage = scaledPercentage,
        rawPercentage = rawPercentage,
        r = r,
        g = g,
        b = b,
    }
end

local function CollectThreat()
    local entries = {}

    for _, unit in ipairs(BuildUnitList()) do
        local entry = GetThreatEntry(unit)

        if entry then
            entries[#entries + 1] = entry
        end
    end

    table.sort(entries, function(a, b)
        return a.threat > b.threat
    end)

    return entries
end

local function HideRows()
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function UpdateTitle()
    local title = "KamiThreat"

    if UnitExists("target") then
        local targetName = UnitName("target")

        if UI:CanAccessValue(targetName) and targetName and targetName ~= "" then
            title = title .. " - " .. targetName
        end
    end

    frame.title:SetText(title)
end

local function Update()
    EnsureFrame()
    UpdateTitle()

    local inCombat = UnitAffectingCombat("player")

    if not UnitExists("target")
        or UnitIsDead("target")
        or not UnitCanAttack("player", "target")
    then
        HideRows()
        frame:SetHeight(defaults.titleHeight)
        frame:SetShown(inCombat)
        return
    end

    local entries = CollectThreat()

    if #entries == 0 then
        HideRows()
        frame:SetHeight(defaults.titleHeight)
        frame:SetShown(inCombat)
        return
    end

    -- rawPercentage is relative to the mob's current primary target, not to
    -- whoever happens to have the most raw threat. That distinction matters
    -- because a unit can sit above 100% raw threat without pulling aggro.
    local barMaximum = 130

    for _, entry in ipairs(entries) do
        local percentage = entry.isTanking and 100 or entry.rawPercentage

        if percentage and percentage > barMaximum then
            barMaximum = percentage
        end
    end

    local shown = math.min(#entries, defaults.maxRows)

    for index = 1, defaults.maxRows do
        local row = rows[index]
        local entry = entries[index]

        if index <= shown and entry then
            local percentage = entry.isTanking and 100 or entry.rawPercentage

            row.bar:SetMinMaxValues(0, barMaximum)
            row.bar:SetValue(percentage)
            row.bar:SetStatusBarColor(entry.r, entry.g, entry.b, 1)
            row.name:SetText(entry.name)
            row.percent:SetFormattedText("%.0f%%", percentage)
            row:Show()
        else
            row:Hide()
        end
    end

    frame:SetHeight(
        defaults.titleHeight + math.max(shown, 1) * defaults.rowHeight
    )
    frame:Show()
end

local function QueueUpdate()
    if updateQueued then
        return
    end

    updateQueued = true

    C_Timer.After(0, function()
        updateQueued = false
        Update()
    end)
end

function Module:Initialize()
    EnsureFrame()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", QueueUpdate)
    UI:RegisterEvent("PLAYER_TARGET_CHANGED", QueueUpdate)
    UI:RegisterEvent("GROUP_ROSTER_UPDATE", QueueUpdate)
    UI:RegisterEvent("UNIT_PET", QueueUpdate)
    UI:RegisterEvent("UNIT_THREAT_LIST_UPDATE", QueueUpdate)
    UI:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", QueueUpdate)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", QueueUpdate)
    UI:RegisterEvent("PLAYER_REGEN_DISABLED", QueueUpdate)
end

Module:Initialize()
