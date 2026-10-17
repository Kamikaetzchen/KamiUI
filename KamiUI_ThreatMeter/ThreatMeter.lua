local UI = KamiUI
local Styles = UI.Styles

local Module = UI:NewModule("ThreatMeter", "KamiUI_ThreatMeter")


local Layout = UI.Layout.ThreatMeter

local frame
local rows = {}
local updateQueued = false

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(Layout.WIDTH, Layout.ROW_HEIGHT)

    if index == 1 then
        row:SetPoint("TOPRIGHT", frame.titleBar, "BOTTOMRIGHT")
    else
        row:SetPoint("TOPRIGHT", rows[index - 1], "BOTTOMRIGHT")
    end

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.03, 0.03, 0.03, Styles.State.threatMeterBackgroundAlpha)

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 100)

    local texture = bar:GetStatusBarTexture()
    texture:SetAlpha(Styles.State.threatMeterBarAlpha)

    local overlay = CreateFrame("Frame", nil, row)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)

    local name = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", row, "LEFT", 5, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -112, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    local threatValue = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    threatValue:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    threatValue:SetJustifyH("RIGHT")
    threatValue:SetWordWrap(false)

    local fontPath, _, fontFlags = GameFontNormal:GetFont()

    if fontPath then
        name:SetFont(fontPath, Styles.FontSize.ThreatMeter, fontFlags)
        threatValue:SetFont(fontPath, Styles.FontSize.ThreatMeter, fontFlags)
    end

    name:SetTextColor(1, 1, 1)
    threatValue:SetTextColor(1, 1, 1)

    Styles:CreateBorder(row, { color = { 0, 0, 0, 1 } })

    row.bar = bar
    row.name = name
    row.threatValue = threatValue
    row:Hide()

    rows[index] = row
end

local function PositionFrame()
    if not frame then return end

    frame:ClearAllPoints()
    frame:SetPoint(
        "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
        0, UI:GetBottomInset()
            + UI.Layout.DamageMeter.HEIGHT + Layout.GAP_ABOVE_DAMAGE
    )
end

local function EnsureFrame()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "KamiUIThreatMeter", UIParent)
    frame:SetSize(
        Layout.WIDTH,
        Layout.TITLE_HEIGHT + Layout.ROW_HEIGHT * Layout.MAX_ROWS
    )
    PositionFrame()
    frame:SetFrameStrata("LOW")
    frame:Hide()

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(Layout.WIDTH, Layout.TITLE_HEIGHT)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

    local titleBackground = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBackground:SetAllPoints()
    titleBackground:SetColorTexture(
        0.03,
        0.03,
        0.03,
        Styles.State.threatMeterBackgroundAlpha
    )

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 5, 0)
    title:SetPoint("RIGHT", titleBar, "RIGHT", -5, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText("KamiThreat")

    local fontPath, _, fontFlags = GameFontNormal:GetFont()
    if fontPath then
        title:SetFont(fontPath, Styles.FontSize.ThreatMeter, fontFlags)
    end

    title:SetTextColor(1, 1, 1)
    Styles:CreateBorder(titleBar, { color = { 0, 0, 0, 1 } })

    frame.titleBar = titleBar
    frame.title = title

    for index = 1, Layout.MAX_ROWS do
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
    local _, _, _, _, rawThreat =
        UnitDetailedThreatSituation(unit, "target")

    -- Forever can mark threat values secret in restricted contexts. Only
    -- compare and format raw threat after confirming that it is accessible.
    if not UI:CanAccessValue(rawThreat)
        or type(rawThreat) ~= "number"
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
        frame:SetHeight(Layout.TITLE_HEIGHT)
        frame:SetShown(inCombat)
        return
    end

    local entries = CollectThreat()

    if #entries == 0 then
        HideRows()
        frame:SetHeight(Layout.TITLE_HEIGHT)
        frame:SetShown(inCombat)
        return
    end

    -- Bars show each unit's raw threat relative to the highest entry;
    -- the right-hand values show the full absolute threat without K/M rounding.
    local barMaximum = entries[1].threat

    local shown = math.min(#entries, Layout.MAX_ROWS)

    for index = 1, Layout.MAX_ROWS do
        local row = rows[index]
        local entry = entries[index]

        if index <= shown and entry then
            row.bar:SetMinMaxValues(0, barMaximum)
            row.bar:SetValue(entry.threat)
            row.bar:SetStatusBarColor(entry.r, entry.g, entry.b, 1)
            row.name:SetText(entry.name)
            row.threatValue:SetText(
                UI:FormatNumber(math.floor(entry.threat + 0.5))
            )
            row:Show()
        else
            row:Hide()
        end
    end

    frame:SetHeight(
        Layout.TITLE_HEIGHT + math.max(shown, 1) * Layout.ROW_HEIGHT
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
    UI:RegisterBottomInsetCallback(PositionFrame)

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
