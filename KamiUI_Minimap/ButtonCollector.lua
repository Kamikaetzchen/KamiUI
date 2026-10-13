local UI = KamiUI
local Module = UI:GetModule("Minimap")
local Layout = UI.Layout.Minimap.ButtonCollector

-- Keep the real third-party buttons: their OnClick/OnEnter scripts, tooltips
-- and LibDataBroker integrations continue to work without synthetic clicks.
-- Only reparent/reanchor unprotected buttons outside combat.
local collected = {}
local ordered = {}

local excluded = {
    GameTimeFrame = true,
    TimeManagerClockButton = true,
    MinimapZoomIn = true,
    MinimapZoomOut = true,
    MinimapZoneTextButton = true,
    MiniMapTrackingButton = true,
    MiniMapWorldMapButton = true,
    MiniMapMailFrame = true,
    MiniMapBattlefieldFrame = true,
    MiniMapInstanceDifficulty = true,
    MinimapCluster = true,
    GarrisonLandingPageMinimapButton = true,
    ExpansionLandingPageMinimapButton = true,
    QueueStatusMinimapButton = true,
}

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function ButtonName(button)
    local name = button:GetName()
    if name and name:match("^LibDBIcon10_") then
        return name:sub(13)
    end
    return name or ""
end

local function IsCandidate(button)
    if not button
        or collected[button]
        or not button.IsObjectType
        or not button:IsObjectType("Button")
        or (button.IsForbidden and button:IsForbidden())
        or (button.IsProtected and button:IsProtected())
    then
        return false
    end

    local name = button:GetName()
    if name and excluded[name] then
        return false
    end
    if name and (
        name:match("^MiniMap")
        or name:match("^Minimap")
        or name:match("^KamiUI")
        or name:match("^QueueStatus")
        or name:match("^GameTime")
    ) then
        return false
    end

    -- LibDBIcon buttons are the common case. Only accept other buttons
    -- directly attached to the minimap if they have an actual click script.
    -- Anonymous Blizzard decorative frames are intentionally not collected.
    if name and name:match("^LibDBIcon10_") then
        return true
    end
    return name ~= nil
        and name ~= ""
        and button:GetParent() == Minimap
        and button:GetScript("OnClick") ~= nil
end

local function ReadableLabel(button)
    local object = button.dataObject
    local label = object and object.label
    if type(label) == "string" and label ~= "" then
        return label
    end
    return ButtonName(button)
end

local function SortButtons()
    wipe(ordered)
    for button in pairs(collected) do
        -- The icon itself can be hidden by its owning addon; don't override
        -- that choice or reserve a permanent blank slot for it.
        if button:IsShown() then
            ordered[#ordered + 1] = button
        end
    end
    table.sort(ordered, function(left, right)
        return string.lower(ReadableLabel(left))
            < string.lower(ReadableLabel(right))
    end)
end

local function StyleBorder(frame)
    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetColorTexture(0.22, 0.22, 0.24, 1)
    border:SetPoint("TOPLEFT")
    border:SetPoint("TOPRIGHT")
    border:SetHeight(1)

    border = frame:CreateTexture(nil, "OVERLAY")
    border:SetColorTexture(0.22, 0.22, 0.24, 1)
    border:SetPoint("BOTTOMLEFT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetHeight(1)

    border = frame:CreateTexture(nil, "OVERLAY")
    border:SetColorTexture(0.22, 0.22, 0.24, 1)
    border:SetPoint("TOPLEFT")
    border:SetPoint("BOTTOMLEFT")
    border:SetWidth(1)

    border = frame:CreateTexture(nil, "OVERLAY")
    border:SetColorTexture(0.22, 0.22, 0.24, 1)
    border:SetPoint("TOPRIGHT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetWidth(1)
end

local function CreateDock()
    local toggle = CreateFrame(
        "Button", "KamiUIMinimapButtonCollectorToggle", UIParent
    )
    toggle:SetSize(Layout.TOGGLE_SIZE, Layout.TOGGLE_SIZE)
    toggle:SetPoint("TOPLEFT", Minimap, "TOPRIGHT",
        Layout.OFFSET_X, Layout.OFFSET_Y)
    toggle:SetFrameStrata("HIGH")

    local background = toggle:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.02, 0.02, 0.025, 0.88)
    StyleBorder(toggle)

    local icon = toggle:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local count = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", -2, 1)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(1, 0.82, 0.25, 1)
    toggle.count = count
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("KamiUI: Minimap buttons")
        GameTooltip:AddLine("Click to show or hide addon buttons", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toggle:Hide()

    local panel = CreateFrame(
        "Frame", "KamiUIMinimapButtonCollector", UIParent
    )
    panel:SetFrameStrata("HIGH")
    panel:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -Layout.PANEL_GAP)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.015, 0.015, 0.02, 0.9)
    StyleBorder(panel)
    panel:Hide()

    toggle:SetScript("OnClick", function()
        Module:SetButtonCollectorExpanded(not Module.collectorExpanded)
    end)

    Module.collectorToggle = toggle
    Module.collectorPanel = panel
end

local function IsDockProtected()
    return Module.collectorPanel
        and Module.collectorPanel.IsProtected
        and Module.collectorPanel:IsProtected()
end

function Module:SetButtonCollectorExpanded(expanded)
    if InCombat() and IsDockProtected() then
        UI:RunOutOfCombat("minimap.collector.toggle", function()
            Module:SetButtonCollectorExpanded(expanded)
        end)
        return
    end

    self.collectorExpanded = expanded == true
    self.collectorDB.expanded = self.collectorExpanded
    if self.collectorExpanded and #ordered > 0 then
        self.collectorPanel:Show()
        -- Showing the dock may trigger third-party OnShow positioning.
        -- Restore the collector grid immediately when not in combat.
        if not InCombat() then
            self:RefreshButtonCollector()
        end
    else
        self.collectorPanel:Hide()
    end
end

local function FindCandidates()
    local found = {}
    -- LibDBIcon and most legacy addon buttons are direct Minimap children.
    for _, parent in ipairs({ Minimap, MinimapCluster }) do
        if parent then
            for _, frame in ipairs({ parent:GetChildren() }) do
                if IsCandidate(frame) and frame:IsShown() then
                    found[#found + 1] = frame
                end
            end
        end
    end
    return found
end

local function NeedsAnchor(button, x, y)
    if button:GetNumPoints() ~= 1 then return true end
    local point, relative, relativePoint, actualX, actualY =
        button:GetPoint(1)
    return point ~= "TOPLEFT"
        or relative ~= Module.collectorPanel
        or relativePoint ~= "TOPLEFT"
        or actualX ~= x or actualY ~= y
end

function Module:RefreshButtonCollector()
    if not self.collectorPanel then return end

    -- Never reparent, resize or alter points of addon frames in combat.
    if InCombat() then
        UI:RunOutOfCombat("minimap.collector.refresh", function()
            Module:RefreshButtonCollector()
        end)
        return
    end

    local additions = FindCandidates()
    for _, button in ipairs(additions) do
        collected[button] = true
        button:SetParent(self.collectorPanel)
        -- LibDBIcon icons commonly request MEDIUM strata. Raise the real
        -- button above our HIGH-strata dock background after reparenting.
        button:SetFrameStrata("HIGH")
        button:SetFrameLevel(self.collectorPanel:GetFrameLevel() + 2)
    end

    SortButtons()
    local count = #ordered
    local columns = math.min(Layout.COLUMNS, math.max(1, count))
    local rows = math.ceil(count / Layout.COLUMNS)
    local cell = Layout.BUTTON_SIZE + Layout.SPACING
    self.collectorPanel:SetSize(
        2 * Layout.PADDING + columns * Layout.BUTTON_SIZE
            + (columns - 1) * Layout.SPACING,
        2 * Layout.PADDING + math.max(1, rows) * Layout.BUTTON_SIZE
            + math.max(0, rows - 1) * Layout.SPACING
    )

    for index, button in ipairs(ordered) do
        local col = (index - 1) % Layout.COLUMNS
        local row = math.floor((index - 1) / Layout.COLUMNS)
        local x = Layout.PADDING + col * cell
        local y = -Layout.PADDING - row * cell
        if button:GetParent() ~= self.collectorPanel then
            button:SetParent(self.collectorPanel)
        end
        if NeedsAnchor(button, x, y) then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.collectorPanel,
                "TOPLEFT", x, y)
        end
    end

    self.collectorToggle.count:SetText(count)
    if count == 0 then
        self.collectorPanel:Hide()
        self.collectorToggle:Hide()
    else
        self.collectorToggle:Show()
        if self.collectorExpanded then
            self.collectorPanel:Show()
        else
            self.collectorPanel:Hide()
        end
    end
end

function Module:InitializeButtonCollector()
    self.collectorDB = UI:GetDatabase("MinimapButtonCollector", {
        expanded = false,
    })
    self.collectorExpanded = self.collectorDB.expanded == true
    CreateDock()
    self:RefreshButtonCollector()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function() Module:RefreshButtonCollector() end)
    end)
    UI:RegisterEvent("ADDON_LOADED", function()
        C_Timer.After(0, function() Module:RefreshButtonCollector() end)
    end)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        Module:RefreshButtonCollector()
    end)

    -- Late-loading addons and LibDBIcon may reset their minimap anchors.
    -- Check occasionally, not every frame; native button scripts remain intact.
    C_Timer.NewTicker(Layout.SCAN_INTERVAL, function()
        Module:RefreshButtonCollector()
    end)
end

Module:InitializeButtonCollector()
