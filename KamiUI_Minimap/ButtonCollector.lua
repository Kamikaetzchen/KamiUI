local UI = KamiUI
local Module = UI:GetModule("Minimap")
local Layout = UI.Layout.Minimap.ButtonCollector

-- Adopt the original addon buttons so their clicks and tooltips keep working.
-- Frame ownership/size/anchors are only changed outside combat.
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
    AddonCompartmentFrame = true,
    AddOnCompartmentFrame = true,
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

    if name and name:match("^LibDBIcon10_") then
        return true
    end

    -- Legacy addons often place a named, clickable button on Minimap.
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
        -- Respect buttons an addon has intentionally hidden.
        if button:IsShown() then
            ordered[#ordered + 1] = button
        end
    end

    table.sort(ordered, function(left, right)
        local a = string.lower(ReadableLabel(left))
        local b = string.lower(ReadableLabel(right))
        if a == b then
            return ButtonName(left) < ButtonName(right)
        end
        return a < b
    end)
end

local function CreateDock()
    local width = Layout.COLUMNS * Layout.BUTTON_SIZE
        + (Layout.COLUMNS - 1) * Layout.SPACING

    -- A plain, permanently visible scroll viewport: no toggle and no panel
    -- background. It is capped at six rows to fit alongside the minimap.
    local dock = CreateFrame(
        "ScrollFrame", "KamiUIMinimapButtonCollector", UIParent
    )
    dock:SetFrameStrata("HIGH")
    dock:SetSize(width, 1)
    dock:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMRIGHT",
        Layout.OFFSET_X, Layout.OFFSET_Y)
    dock:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, dock)
    content:SetSize(width, 1)
    dock:SetScrollChild(content)

    dock:SetScript("OnMouseWheel", function(_, delta)
        if Module.collectorOverflowRows <= 0 then return end

        local offset = Module.collectorScrollRows
        if delta > 0 then
            offset = math.min(offset + 1, Module.collectorOverflowRows)
        elseif delta < 0 then
            offset = math.max(offset - 1, 0)
        end

        Module.collectorScrollRows = offset
        Module:ApplyButtonCollectorScroll()
    end)

    Module.collectorPanel = dock
    Module.collectorContent = content
    Module.collectorScrollRows = 0
    Module.collectorOverflowRows = 0
    Module.collectorFullHeight = 1
end

local function FindCandidates()
    local found = {}

    -- LibDBIcon and many legacy addon buttons sit directly on the minimap
    -- or its cluster. The Blizzard addon-compartment button stays untouched.
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

    return point ~= "BOTTOMLEFT"
        or relative ~= Module.collectorContent
        or relativePoint ~= "BOTTOMLEFT"
        or actualX ~= x
        or actualY ~= y
end

function Module:ApplyButtonCollectorScroll()
    if not self.collectorPanel then return end

    local viewportHeight = self.collectorPanel:GetHeight()
    local maxScroll = math.max(0, self.collectorFullHeight - viewportHeight)
    local cell = Layout.BUTTON_SIZE + Layout.SPACING
    local offset = math.min(
        maxScroll, self.collectorScrollRows * cell
    )

    -- Bottom row is the default; scrolling up reveals older/top rows.
    local scrollValue = maxScroll - offset
    if self.collectorPanel:GetVerticalScroll() ~= scrollValue then
        self.collectorPanel:SetVerticalScroll(scrollValue)
    end
end

function Module:RefreshButtonCollector()
    if not self.collectorPanel then return end

    if InCombat() then
        UI:RunOutOfCombat("minimap.collector.refresh", function()
            Module:RefreshButtonCollector()
        end)
        return
    end

    for _, button in ipairs(FindCandidates()) do
        collected[button] = true
        button:SetParent(self.collectorContent)
        button:SetFrameStrata("HIGH")
        button:SetFrameLevel(self.collectorContent:GetFrameLevel() + 2)
    end

    SortButtons()

    local rows = math.ceil(#ordered / Layout.COLUMNS)
    local visibleRows = math.max(1, math.min(rows, Layout.MAX_ROWS))
    local cell = Layout.BUTTON_SIZE + Layout.SPACING
    local width = Layout.COLUMNS * Layout.BUTTON_SIZE
        + (Layout.COLUMNS - 1) * Layout.SPACING
    local fullHeight = math.max(1, rows * Layout.BUTTON_SIZE
        + math.max(0, rows - 1) * Layout.SPACING)
    local viewportHeight = visibleRows * Layout.BUTTON_SIZE
        + (visibleRows - 1) * Layout.SPACING

    self.collectorContent:SetSize(width, fullHeight)
    self.collectorPanel:SetSize(width, viewportHeight)
    self.collectorFullHeight = fullHeight
    self.collectorOverflowRows = math.max(0, rows - Layout.MAX_ROWS)
    self.collectorScrollRows = math.min(
        self.collectorScrollRows, self.collectorOverflowRows
    )

    for index, button in ipairs(ordered) do
        local column = (index - 1) % Layout.COLUMNS
        local row = math.floor((index - 1) / Layout.COLUMNS)
        local x = column * cell
        local y = row * cell

        if button:GetParent() ~= self.collectorContent then
            button:SetParent(self.collectorContent)
        end

        if button:GetWidth() ~= Layout.BUTTON_SIZE
            or button:GetHeight() ~= Layout.BUTTON_SIZE
        then
            button:SetSize(Layout.BUTTON_SIZE, Layout.BUTTON_SIZE)
        end

        if NeedsAnchor(button, x, y) then
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", self.collectorContent,
                "BOTTOMLEFT", x, y)
        end
    end

    self:ApplyButtonCollectorScroll()
end

function Module:InitializeButtonCollector()
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

    -- Addons can create buttons late or reset their positions; do not
    -- poll every frame or reanchor anything during combat.
    C_Timer.NewTicker(Layout.SCAN_INTERVAL, function()
        Module:RefreshButtonCollector()
    end)
end

Module:InitializeButtonCollector()
