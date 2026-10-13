local UI = KamiUI
local Module = UI:NewModule("Timers", "KamiUI_Timers")
local Layout = UI.Layout.Timers
local Palette = UI.Palette
local Styles = UI.Styles

-- Blizzard owns the secure aura data, layout and countdowns. To prevent
-- duplicates WITHOUT inspecting secret GUIDs, use non-overlapping sources:
-- friendly self/party tokens only show our buffs and HoTs; nameplates only
-- show our DoTs. Target/focus/boss are deliberately not scanned separately.
-- If enemy nameplates are disabled, enemy DoTs cannot be tracked here.
local TRACKED_UNITS = { { token = "player", friendly = true } }
for index = 1, 4 do
    TRACKED_UNITS[#TRACKED_UNITS + 1] = {
        token = "party" .. index, friendly = true,
    }
end
for index = 1, 8 do
    TRACKED_UNITS[#TRACKED_UNITS + 1] = {
        token = "nameplate" .. index, friendly = false,
    }
end

local function Border(frame)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetColorTexture(0, 0, 0, 1)
        if side == "TOP" then
            texture:SetPoint("TOPLEFT")
            texture:SetPoint("TOPRIGHT")
            texture:SetHeight(1)
        elseif side == "BOTTOM" then
            texture:SetPoint("BOTTOMLEFT")
            texture:SetPoint("BOTTOMRIGHT")
            texture:SetHeight(1)
        elseif side == "LEFT" then
            texture:SetPoint("TOPLEFT")
            texture:SetPoint("BOTTOMLEFT")
            texture:SetWidth(1)
        else
            texture:SetPoint("TOPRIGHT")
            texture:SetPoint("BOTTOMRIGHT")
            texture:SetWidth(1)
        end
    end
end

local function Color(bar, color)
    bar:SetStatusBarColor(color[1], color[2], color[3], 0.70)
end

local function CreateTimerBar(parent, color)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(Layout.WIDTH, Layout.HEIGHT)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.015, 0.015, 0.02, 0.85)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    Color(bar, color)

    -- Text stays outside the StatusBar, so the fill never covers it.
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
    overlay:EnableMouse(false)

    local font, _, flags = GameFontNormalSmall:GetFont()
    local function Text(justify)
        local label = overlay:CreateFontString(nil, "OVERLAY")
        label:SetFont(font, Layout.FONT_SIZE, flags or "OUTLINE")
        label:SetTextColor(1, 1, 1, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        label:SetJustifyH(justify)
        label:SetWordWrap(false)
        return label
    end

    local unit = Text("LEFT")
    unit:SetPoint("LEFT", frame, "LEFT", 4, 0)
    unit:SetWidth(Layout.UNIT_WIDTH)

    local name = Text("LEFT")
    name:SetPoint("LEFT", unit, "RIGHT", 3, 0)
    name:SetPoint("RIGHT", frame, "RIGHT", -Layout.TIME_WIDTH - 5, 0)

    local time = Text("RIGHT")
    time:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    time:SetWidth(Layout.TIME_WIDTH)

    Border(frame)
    return frame, bar, unit, name, time
end

local function InitializeAuraButton(button, color)
    button:SetSize(Layout.WIDTH, Layout.HEIGHT)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.HEIGHT - 2, Layout.HEIGHT - 2)
    icon:SetPoint("LEFT", button, "LEFT", 1, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- The aura-owned frame and visual regions must be constructed before
    -- SetIcon/SetDurationBar bind the native secure aura aspects.
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.015, 0.015, 0.02, 0.85)
    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
    bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    Color(bar, color)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
    overlay:EnableMouse(false)

    local font, _, flags = GameFontNormalSmall:GetFont()
    local function Label(width, justify)
        local fs = overlay:CreateFontString(nil, "OVERLAY")
        fs:SetFont(font, Layout.FONT_SIZE, flags or "OUTLINE")
        fs:SetJustifyH(justify)
        fs:SetWordWrap(false)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        if width then fs:SetWidth(width) end
        return fs
    end
    -- The unit name is a single sectionTitle above the entire group.
    -- The bar keeps the full remaining width for the spell name.
    local spellName = Label(nil, "LEFT")
    spellName:SetPoint("LEFT", bar, "LEFT", 4, 0)
    spellName:SetPoint("RIGHT", bar, "RIGHT", -Layout.TIME_WIDTH - 5, 0)

    local timeText = Label(Layout.TIME_WIDTH, "RIGHT")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    Border(button)

    button:SetIcon(icon)
    button:SetDurationBar(bar, {
        direction = Enum.StatusBarTimerDirection.RemainingTime,
        interpolation = Enum.StatusBarInterpolation.Immediate,
    })
    button:SetSpellName(spellName)
    button:SetDurationText(timeText)
    button:SetMouseMotionEnabled(true)
    button:SetTooltipAnchorPoint("ANCHOR_RIGHT")
end

local function CreateUnitHeader(parent, below, token)
    -- This is a normal UI frame, not part of Blizzard's secure AuraContainer.
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(Layout.WIDTH, Layout.SECTION_HEIGHT)
    frame:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, Layout.SECTION_GAP)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", frame, "LEFT", 2, 0)
    title:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    Styles:ApplyText(title, "sectionTitle")
    title:SetText(token)
    return frame, title
end

local function MakeAuraContainer(parent, unitToken, previous, friendly)
    local container = CreateFrame(
        "AuraContainer", nil, parent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )
    container:SetSize(Layout.WIDTH, 1)
    container:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, Layout.GAP)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
    container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up
    )
    container:SetFlowLayoutMaximumLineSize(Layout.WIDTH)

    local function Add(key, filter, color, maxCount, order)
        container:AddAuraGroup(key, filter, {
            maxFrameCount = maxCount,
            sortMethod = AuraContainerSortMethod.Expiration,
            sortDirection = AuraContainerSortDirection.Reverse,
            candidateFilters = {
                maxDuration = Layout.MAX_AURA_DURATION,
            },
            initializeFrame = function(button)
                InitializeAuraButton(button, color)
            end,
            layout = {
                elementWidth = Layout.WIDTH,
                elementHeight = Layout.HEIGHT,
                elementSpacing = Layout.GAP,
                groupSpacing = Layout.GAP,
                layoutIndex = order,
            },
        })
    end
    if friendly then
        Add("hots", "HELPFUL|PLAYER", Palette.auras.helpful, 6, 1)
    else
        Add("dots", "HARMFUL|PLAYER", Palette.auras.harmful, 6, 1)
    end
    container:SetEnabled(true)
    container:SetUnit(unitToken)
    container:UpdateAllAuras()

    -- Header above this unit's own native aura stack; the next unit anchors
    -- above the header, so each heading belongs to the bars immediately below.
    local header, title = CreateUnitHeader(parent, container, unitToken)
    return { frame = container, header = header, title = title,
        token = unitToken, headerActive = true }

end

local function RemainingText(seconds)
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60),
            math.floor(seconds % 60))
    end
    return string.format("%.1f", seconds)
end

local function MakeTotemRow(parent, slot)
    local frame, bar, unit, name, time =
        CreateTimerBar(parent, Palette.auras.weaponEnchant)
    unit:SetText("Totem")
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    cooldown:SetSize(Layout.TIME_WIDTH + 5, Layout.HEIGHT)
    cooldown:SetFrameLevel(frame:GetFrameLevel() + 5)
    cooldown:SetDrawSwipe(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:Hide()
    frame:Hide()
    return { frame = frame, bar = bar, name = name, time = time,
        cooldown = cooldown, slot = slot }
end

local function ReadTotem(row)
    local durationObject
    if GetTotemDuration then
        local ok, value = pcall(GetTotemDuration, row.slot)
        if ok then durationObject = value end
    end
    local name, start, duration
    if GetTotemInfo then
        local ok, _, n, startTime, seconds =
            pcall(GetTotemInfo, row.slot)
        if ok then
            name, start, duration = n, startTime, seconds
        end
    end

    -- Some clients return an empty duration object for an inactive slot.
    -- A readable empty name is the authoritative absence signal, not
    -- GetTotemInfo's first result (which indicates totem-tool possession).
    if UI:CanAccessValue(name)
        and type(name) == "string" and name == "" then
        row.manualEnd = nil
        row.cooldown:Hide()
        return false
    end

    -- In 12.1 the duration object works without Lua reading secret
    -- timestamps. A native Cooldown supplies the countdown text.
    if durationObject and row.cooldown.SetCooldownFromDurationObject
        and row.bar.SetTimerDuration then
        if UI:CanAccessValue(name)
            and (type(name) ~= "string" or name == "") then
            row.name:SetText("Totem")
        else
            -- Passing a secret name through to FontString is supported.
            row.name:SetText(name)
        end
        row.time:SetText("")
        row.cooldown:Show()
        row.bar:SetTimerDuration(durationObject,
            Enum.StatusBarInterpolation.Immediate,
            Enum.StatusBarTimerDirection.RemainingTime)
        row.cooldown:SetCooldownFromDurationObject(durationObject, true)
        row.manualEnd = nil
        return true
    end

    row.cooldown:Hide()
    if not UI:CanAccessValue(name)
        or not UI:CanAccessValue(start)
        or not UI:CanAccessValue(duration)
        or type(name) ~= "string" or name == ""
        or type(start) ~= "number" or type(duration) ~= "number"
        or duration <= 0 or start + duration <= GetTime()
    then
        row.manualEnd = nil
        return false
    end
    row.name:SetText(name)
    row.manualEnd = start + duration
    row.manualDuration = duration
    return true
end

function Module:RefreshTotems()
    if not self.totems then return end
    local visible = 0
    for _, row in ipairs(self.totems) do
        if ReadTotem(row) then
            row.frame:ClearAllPoints()
            row.frame:SetPoint("BOTTOMLEFT", self.totemAnchor,
                "BOTTOMLEFT", 0,
                visible * (Layout.HEIGHT + Layout.GAP))
            row.frame:Show()
            visible = visible + 1
        else
            row.frame:Hide()
        end
    end
    self.totemAnchor:SetHeight(math.max(1,
        visible * (Layout.HEIGHT + Layout.GAP)))
end

function Module:UpdateTotemCountdowns()
    if not self.totems then return end
    local now = GetTime()
    for _, row in ipairs(self.totems) do
        if row.manualEnd and row.frame:IsShown() then
            local left = math.max(0, row.manualEnd - now)
            row.bar:SetValue(left / row.manualDuration)
            row.time:SetText(RemainingText(left))
            if left == 0 then self:RefreshTotems() return end
        end
    end
end

-- SetUnit() is a no-op for an unchanged token. Blizzard may keep the
-- previously resolved target/focus/nameplate after that token changes.
-- Match KamiUI_UnitFrames/UnitAuras.lua: refresh immediately in combat,
-- and defer the rebind/visibility bounce of protected containers.
function Module:RefreshAuraUnits(token)
    if not self.units then return end
    if InCombatLockdown and InCombatLockdown() then
        for _, entry in ipairs(self.units) do
            if not token or entry.token == token then
                entry.frame:UpdateAllAuras()
            end
        end
        UI:RunOutOfCombat("timers.auraBindings", function()
            Module:RefreshAuraUnits()
        end)
        return
    end

    UI:CancelOutOfCombat("timers.auraBindings")
    for _, entry in ipairs(self.units) do
        if not token or entry.token == token then
            local container = entry.frame
            container:SetUnit("none")
            container:SetUnit(entry.token)
            container:Hide()
            container:Show()
            container:UpdateAllAuras()
        end
    end
end

-- Auras in combat are opaque; we can condition section titles only on the
-- *unit's existence*, never on whether its secret aura list is empty.
-- Collapse absent unit headers outside lockdown. Keep the header hierarchy
-- stable during combat and defer any protected reflow until afterwards.
function Module:RefreshUnitHeaders()
    if not self.units then return end
    local locked = InCombatLockdown and InCombatLockdown()
    local needsLayout = false

    for _, entry in ipairs(self.units) do
        local exists = UnitExists and UnitExists(entry.token)
        if not UI:CanAccessValue(exists) then
            exists = entry.headerActive
        end
        exists = exists == true

        if exists then
            -- UnitName can be a secret string; native FontString accepts it.
            entry.title:SetText(UnitName(entry.token))
        else
            entry.title:SetText("")
        end

        if entry.headerActive ~= exists then
            if locked then
                needsLayout = true
            else
                entry.header:SetHeight(
                    exists and Layout.SECTION_HEIGHT or 0.001
                )
                entry.headerActive = exists
            end
        end
    end

    if needsLayout then
        UI:RunOutOfCombat("timers.headers", function()
            Module:RefreshUnitHeaders()
        end)
    else
        UI:CancelOutOfCombat("timers.headers")
    end
end

function Module:Initialize()
    local pet = _G.KamiUIPetFrame
    if not pet or not AuraContainerSortMethod
        or not AnchorUtil or not AnchorUtil.FlowLayoutAxis then
        UI:Print("Timers: UnitFrames or native AuraContainer API unavailable")
        return
    end

    local anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetSize(Layout.WIDTH, 1)
    anchor:SetPoint("BOTTOMRIGHT", pet, "TOPLEFT",
        Layout.OFFSET_X, Layout.OFFSET_Y)
    self.anchor = anchor
    self.totemAnchor = CreateFrame("Frame", nil, anchor)
    self.totemAnchor:SetSize(Layout.WIDTH, 1)
    self.totemAnchor:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")

    self.totems = {}
    for slot = 1, (MAX_TOTEMS or 4) do
        self.totems[#self.totems + 1] = MakeTotemRow(anchor, slot)
    end

    self.units = {}
    local previous = self.totemAnchor
    for _, definition in ipairs(TRACKED_UNITS) do
        local entry = MakeAuraContainer(
            anchor, definition.token, previous, definition.friendly
        )
        self.units[#self.units + 1] = entry
        previous = entry.header
    end

    local elapsed = 0
    anchor:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.15 then return end
        elapsed = 0
        Module:UpdateTotemCountdowns()
    end)
    self:RefreshTotems()
    self:RefreshUnitLabels()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:RefreshTotems()
        Module:RefreshUnitHeaders()
        C_Timer.After(0, function() Module:RefreshAuraUnits() end)
    end)
    UI:RegisterEvent("PLAYER_TOTEM_UPDATE", function()
        Module:RefreshTotems()
    end)
    -- The "target" and "focus" aliases are deliberately not displayed,
    -- because each could duplicate an existing nameplate/party group.
    UI:RegisterEvent("UNIT_NAME_UPDATE", function()
        Module:RefreshUnitHeaders()
    end)
    UI:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
        Module:RefreshUnitHeaders()
        Module:RefreshAuraUnits(unit)
    end)
    UI:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
        Module:RefreshUnitHeaders()
        Module:RefreshAuraUnits(unit)
    end)
    UI:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        Module:RefreshUnitHeaders()
        Module:RefreshAuraUnits()
    end)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        Module:RefreshUnitHeaders()
    end)
end

Module:Initialize()
