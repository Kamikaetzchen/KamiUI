local UI = KamiUI
local Module = UI:GetModule("DamageMeter")
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

-- Blizzard's meter exposes per-spell information for an individual source,
-- including while combat meter totals are protected. No CombatLog parsing.
local WIDTH = 432
local HEIGHT = 228
local MAX_ROWS = 7
local ROW_HEIGHT = 21

local window
local sourceSelection
local spellRows = {}
local offset = 0
local displayedSpells = {}
local sliderSyncing = false
local meterFont, _, meterFlags = GameFontNormalSmall:GetFont()

local function SetFont(fontString, size, color)
    fontString:SetFont(meterFont, size, meterFlags)
    fontString:SetWordWrap(false)
    Styles:SetTextColor(fontString, color or Palette.text)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
end

local function CreateText(parent, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY")
    SetFont(label, size or Styles.FontSize.DamageMeter, color)
    return label
end

local function GetSourceBreakdown()
    if not sourceSelection or not C_DamageMeter then return nil end

    -- On Forever sourceGUID can be ConditionalSecret while fighting.
    -- The per-source API explicitly disallows tainted secret arguments,
    -- unlike the session list (which supports direct display sinks).
    -- Never submit an opaque GUID to that API, even inside pcall.
    local guid = sourceSelection.sourceGUID
    if not UI:CanAccessValue(guid) then guid = nil end
    local creatureID = sourceSelection.sourceCreatureID
    if not UI:CanAccessValue(creatureID) then creatureID = nil end
    if not guid and not creatureID then
        return nil, "restricted"
    end

    local ok, result
    if sourceSelection.sessionID ~= nil then
        ok, result = pcall(
            C_DamageMeter.GetCombatSessionSourceFromID,
            sourceSelection.sessionID,
            sourceSelection.meterType, guid, creatureID
        )
    else
        ok, result = pcall(
            C_DamageMeter.GetCombatSessionSourceFromType,
            sourceSelection.sessionType,
            sourceSelection.meterType, guid, creatureID
        )
    end

    if not ok or not result or not UI:CanAccessValue(result) then
        return nil, "restricted"
    end
    return result
end

local function GetSpellIdentity(spell)
    local spellID = spell.spellID
    local available = UI:CanAccessValue(spellID)
        and type(spellID) == "number"
        and spellID > 0

    local name
    local icon
    if available and C_Spell then
        if C_Spell.GetSpellName then
            name = UI:SafeCall(C_Spell.GetSpellName, spellID)
        end
        if C_Spell.GetSpellTexture then
            icon = UI:SafeCall(C_Spell.GetSpellTexture, spellID)
        end
    end

    if UI:CanAccessValue(name) then
        name = name or (UNKNOWN or "Unknown")
    end
    return name, icon, available and spellID or nil
end

local function CreateSpellRow(index)
    local row = CreateFrame("Button", nil, window)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", window, "LEFT", 7, 0)
    row:SetPoint("RIGHT", window, "RIGHT", -23, 0)
    if index == 1 then
        row:SetPoint("TOP", window.columnHeader, "BOTTOM", 0, -1)
    else
        row:SetPoint("TOP", spellRows[index - 1], "BOTTOM", 0, 0)
    end

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.075)

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(0.30, 0.30, 0.34, 1)
    local texture = bar:GetStatusBarTexture()
    if texture then
        texture:SetAlpha(Styles.State.damageMeterBarAlpha)
    end

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.02, 0.02, 0.025,
        Styles.State.damageMeterRowAlpha)

    local overlay = CreateFrame("Frame", nil, row)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)

    local icon = overlay:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("LEFT", 3, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local name = CreateText(overlay, Styles.FontSize.DamageMeter)
    name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    name:SetWidth(212)
    name:SetJustifyH("LEFT")

    local rate = CreateText(overlay, Styles.FontSize.DamageMeter,
        Palette.muted)
    rate:SetWidth(62)
    rate:SetPoint("RIGHT", overlay, "RIGHT", -5, 0)
    rate:SetJustifyH("RIGHT")

    local amount = CreateText(overlay, Styles.FontSize.DamageMeter,
        Palette.text)
    amount:SetWidth(84)
    amount:SetPoint("RIGHT", rate, "LEFT", -4, 0)
    amount:SetJustifyH("RIGHT")

    local separator = overlay:CreateTexture(nil, "OVERLAY")
    separator:SetHeight(1)
    separator:SetPoint("BOTTOMLEFT")
    separator:SetPoint("BOTTOMRIGHT")
    separator:SetColorTexture(0, 0, 0, 0.70)

    row:SetScript("OnEnter", function(self)
        if not self.spellID or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    row.bar = bar
    row.icon = icon
    row.name = name
    row.amount = amount
    row.rate = rate
    row:Hide()
    spellRows[index] = row
end

local function RenderDetails()
    if not window or not window:IsShown() or not sourceSelection then
        return
    end

    local breakdown, restriction = GetSourceBreakdown()
    local spells = breakdown and breakdown.combatSpells or {}
    -- The native session may not grant an accessible per-spell table
    -- while the addon is tainted by combat. Show a reason, not a blank.
    if not UI:CanAccessValue(spells) then
        spells = {}
        restriction = "restricted"
    end
    displayedSpells = spells

    local maxOffset = math.max(0, #spells - MAX_ROWS)
    offset = math.min(offset, maxOffset)

    local color = sourceSelection.classFilename
    if UI:CanAccessValue(color) then
        color = color and Palette:GetClassColor(color)
    else
        color = nil
    end
    local r = color and (color.r or color[1]) * 0.60 or 0.30
    local g = color and (color.g or color[2]) * 0.60 or 0.30
    local b = color and (color.b or color[3]) * 0.60 or 0.34

    for index, row in ipairs(spellRows) do
        local spell = spells[index + offset]
        if spell then
            local name, icon, spellID = GetSpellIdentity(spell)
            row.name:SetText(name)
            row.icon:SetTexture(icon)
            row.spellID = spellID

            -- Feed secret amounts directly to native widget setters.
            -- Arithmetic / comparisons on them would taint in combat.
            row.bar:SetMinMaxValues(0, breakdown.maxAmount)
            row.bar:SetValue(spell.totalAmount)
            row.bar:SetStatusBarColor(r, g, b, 1)
            row.amount:SetText(spell.totalAmount)
            row.rate:SetFormattedText("%.1f", spell.amountPerSecond)
            row:Show()
        else
            row.spellID = nil
            row:Hide()
        end
    end

    if #spells == 0 then
        if restriction == "restricted" then
            window.emptyText:SetText(
                "Spell details unavailable during combat"
                .. "\n(Blizzard restricts the source data)")
        else
            window.emptyText:SetText("No spell breakdown available")
        end
        window.emptyText:Show()
    else
        window.emptyText:Hide()
    end

    window.scrollbar:SetShown(maxOffset > 0)
    sliderSyncing = true
    window.scrollbar:SetMinMaxValues(0, maxOffset)
    window.scrollbar:SetValue(offset)
    sliderSyncing = false
    window.pageLabel:SetFormattedText("%d-%d / %d",
        #spells == 0 and 0 or offset + 1,
        math.min(#spells, offset + MAX_ROWS), #spells)
end

local function ScrollDetails(direction)
    local last = math.max(0, #displayedSpells - MAX_ROWS)
    offset = math.max(0, math.min(last, offset + direction))
    RenderDetails()
end

local function CreateDetailsWindow()
    if window then return end
    window = Components:CreateWindow("KamiUIDamageMeterDetails", {
        width = WIDTH,
        height = HEIGHT,
        strata = "DIALOG",
        movable = true,
        clamped = true,
        header = {
            title = "Spell Breakdown",
            subtitle = "",
            hasSubtitle = true,
            height = 36,
        },
    })
    window:SetFrameLevel(110)

    -- The header sits above the base window. Its close button must be
    -- parented/raised above the header or clicks hit the header instead.
    local close = Components:CreateWindowCloseButton(window.header, {
        relativeTo = window.header,
        frameLevelOffset = 12,
        x = -2, y = -4,
        onClick = function() window:Hide() end,
    })
    close:EnableMouse(true)
    close:RegisterForClicks("LeftButtonUp")
    window.closeButton = close
    Components:RegisterEscapeClose(window)

    local header = CreateFrame("Frame", nil, window)
    header:SetHeight(21)
    header:SetPoint("TOPLEFT", window.header, "BOTTOMLEFT", 6, -1)
    header:SetPoint("TOPRIGHT", window.header, "BOTTOMRIGHT", -6, -1)
    window.columnHeader = header

    local spellLabel = CreateText(header, 9, Palette.gold)
    spellLabel:SetText("Spell")
    spellLabel:SetPoint("LEFT", header, "LEFT", 25, 0)
    local perSecond = CreateText(header, 9, Palette.gold)
    perSecond:SetText("Per sec")
    perSecond:SetWidth(62)
    perSecond:SetJustifyH("RIGHT")
    perSecond:SetPoint("RIGHT", header, "RIGHT", -5, 0)
    local total = CreateText(header, 9, Palette.gold)
    total:SetText("Total")
    total:SetWidth(84)
    total:SetJustifyH("RIGHT")
    total:SetPoint("RIGHT", perSecond, "LEFT", -4, 0)

    for index = 1, MAX_ROWS do CreateSpellRow(index) end

    local emptyText = CreateText(window, 10, Palette.muted)
    emptyText:SetPoint("CENTER", window, "CENTER", 0, 0)
    emptyText:SetText("No spell breakdown available")
    window.emptyText = emptyText

    local scrollbar = CreateFrame("Slider", nil, window)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetWidth(10)
    scrollbar:SetHeight(MAX_ROWS * ROW_HEIGHT)
    scrollbar:SetPoint(
        "TOPRIGHT", header, "BOTTOMRIGHT", -2, -1)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(1)
    if scrollbar.SetObeyStepOnDrag then
        scrollbar:SetObeyStepOnDrag(true)
    end
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.10, 0.10, 0.12, 0.85)
    scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollbar:GetThumbTexture()
    thumb:SetSize(10, 26)
    thumb:SetVertexColor(0.54, 0.54, 0.59, 1)
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if sliderSyncing then return end
        local nextOffset = math.floor(value + 0.5)
        if nextOffset ~= offset then
            offset = nextOffset
            RenderDetails()
        end
    end)
    window.scrollbar = scrollbar

    local pageLabel = CreateText(window, 9, Palette.muted)
    pageLabel:SetPoint("BOTTOM", window, "BOTTOM", 0, 6)
    window.pageLabel = pageLabel

    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(_, delta)
        ScrollDetails(delta < 0 and 1 or -1)
    end)
    for _, row in ipairs(spellRows) do
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            ScrollDetails(delta < 0 and 1 or -1)
        end)
    end
    window:SetScript("OnHide", function()
        sourceSelection = nil
        displayedSpells = {}
        offset = 0
        if GameTooltip then GameTooltip:Hide() end
    end)
    window:Hide()
end

function Module:OpenSourceDetails(source, meterType, sessionType, sessionID)
    if not source or not meterType then return end
    if not C_DamageMeter.GetCombatSessionSourceFromType
        or not C_DamageMeter.GetCombatSessionSourceFromID then
        return
    end

    CreateDetailsWindow()
    sourceSelection = {
        sourceGUID = source.sourceGUID,
        sourceCreatureID = source.sourceCreatureID,
        classFilename = source.classFilename,
        sessionType = sessionType,
        sessionID = sessionID,
        meterType = meterType,
    }
    offset = 0
    window.header:SetTitle(source.name)
    window.header:SetSubtitle("Spell Breakdown")
    if not window:IsShown() then
        window:ClearAllPoints()
        if self.GetMainFrame then
            local main = self:GetMainFrame()
            if main then
                window:SetPoint("BOTTOMRIGHT", main, "BOTTOMLEFT", -4, 0)
            end
        end
    end
    window:Show()
    RenderDetails()
end

function Module:RefreshSourceDetails()
    if window and window:IsShown() then RenderDetails() end
end

function Module:CloseSourceDetails()
    if window then window:Hide() end
end
