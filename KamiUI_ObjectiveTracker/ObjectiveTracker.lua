local UI = KamiUI

local Module = UI:NewModule("ObjectiveTracker")

Module.name = "KamiUI_ObjectiveTracker"
Module.version = "0.1.0"
Module.providers = {}
Module.providerOrder = {}

local PANEL_WIDTH = 300
local HEADER_HEIGHT = 24
local CONTENT_PADDING = 6
local SECTION_HEADER_HEIGHT = 20
local QUEST_SPACING = 4
local OBJECTIVE_SPACING = 1

local colors = {
    background = { 0.00, 0.00, 0.00, 0.40 },
    border = { 0.16, 0.16, 0.18, 1.00 },
    header = { 1.00, 1.00, 1.00, 0.04 },
    section = { 1.00, 1.00, 1.00, 0.055 },
    gold = { 0.88, 0.72, 0.16, 1.00 },
    text = { 0.92, 0.92, 0.94, 1.00 },
    muted = { 0.62, 0.62, 0.66, 1.00 },
    complete = { 0.32, 0.86, 0.38, 1.00 },
}

local function EnsureDatabase()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.objectiveTracker = KamiUIDB.objectiveTracker or {}

    local db = KamiUIDB.objectiveTracker

    if db.minimized == nil then
        db.minimized = false
    end

    db.collapsedSections = db.collapsedSections or {}

    return db
end

local function CreateBorder(parent)
    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    top:SetColorTexture(unpack(colors.border))

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    bottom:SetColorTexture(unpack(colors.border))

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    left:SetColorTexture(unpack(colors.border))

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    right:SetColorTexture(unpack(colors.border))
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)

    if not point then
        return
    end

    EnsureDatabase().position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function ApplySavedPosition(frame)
    local position = EnsureDatabase().position

    frame:ClearAllPoints()

    if position then
        frame:SetPoint(
            position.point or "TOPRIGHT",
            UIParent,
            position.relativePoint or "TOPRIGHT",
            position.x or -40,
            position.y or -160
        )
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -160)
    end
end

local function HideBlizzardTracker()
    local tracker = _G.ObjectiveTrackerFrame

    if not tracker then
        return
    end

    tracker:Hide()

    if not tracker.KamiUIHideHooked and tracker.HookScript then
        tracker.KamiUIHideHooked = true
        tracker:HookScript("OnShow", function(self)
            self:Hide()
        end)
    end
end

local function GetDifficultyColor(level)
    level = tonumber(level) or 0

    if level <= 0 then
        return 1, 0.82, 0
    end

    local playerLevel = UnitLevel and UnitLevel("player") or level
    local difference = level - playerLevel

    if difference >= 5 then
        return 1.00, 0.15, 0.15
    elseif difference >= 3 then
        return 1.00, 0.50, 0.10
    elseif difference >= -2 then
        return 1.00, 0.82, 0.00
    elseif difference >= -5 then
        return 0.25, 0.85, 0.25
    end

    return 0.55, 0.55, 0.55
end

local function OpenQuest(questID)
    if not questID then
        return
    end

    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questID)
        return
    end

    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(questID)
    end

    if ToggleQuestLog then
        ToggleQuestLog()
    end
end

local function CreateQuestRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(18)
    row:RegisterForClicks("LeftButtonUp")

    local level = row:CreateFontString(nil, "OVERLAY")
    level:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    level:SetWidth(34)
    level:SetJustifyH("RIGHT")
    level:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    row.level = level

    local title = row:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", level, "TOPRIGHT", 5, 0)
    title:SetWidth(PANEL_WIDTH - (CONTENT_PADDING * 2) - 41)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("TOP")
    title:SetWordWrap(true)
    title:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    title:SetTextColor(unpack(colors.text))
    row.title = title

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 1)
    highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -1)
    highlight:SetColorTexture(1, 1, 1, 0.05)

    row.objectives = {}

    row:SetScript("OnClick", function(self)
        OpenQuest(self.questID)
    end)

    return row
end

local function GetObjectiveFont(row, index)
    local text = row.objectives[index]

    if text then
        return text
    end

    text = row:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", row, "LEFT", 39, 0)
    text:SetWidth(PANEL_WIDTH - (CONTENT_PADDING * 2) - 41)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    row.objectives[index] = text

    return text
end

local function UpdateQuestRow(row, item, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", CONTENT_PADDING, -y)
    row:SetWidth(PANEL_WIDTH - (CONTENT_PADDING * 2))
    row.questID = item.questID

    local level = tonumber(item.level) or 0
    local r, g, b = GetDifficultyColor(level)

    row.level:SetText(level > 0 and string.format("[%d]", level) or "[?]")
    row.level:SetTextColor(r, g, b)
    row.title:SetText(item.title or "Unknown Quest")

    local titleHeight = math.max(16, math.ceil(row.title:GetStringHeight() or 16))
    local height = titleHeight

    for index, objective in ipairs(item.objectives or {}) do
        local text = GetObjectiveFont(row, index)

        text:ClearAllPoints()
        text:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            39,
            -(titleHeight + OBJECTIVE_SPACING)
        )

        if index > 1 then
            local previousText = row.objectives[index - 1]

            if previousText and previousText:IsShown() then
                text:ClearAllPoints()
                text:SetPoint(
                    "TOPLEFT",
                    previousText,
                    "BOTTOMLEFT",
                    0,
                    -OBJECTIVE_SPACING
                )
            end
        end
        text:SetText("- " .. (objective.text or ""))

        if objective.finished then
            text:SetTextColor(unpack(colors.complete))
        else
            text:SetTextColor(unpack(colors.muted))
        end

        text:Show()

        local objectiveHeight = math.max(
            14,
            math.ceil(text:GetStringHeight() or 14)
        )

        height = height + OBJECTIVE_SPACING + objectiveHeight
    end

    for index = #(item.objectives or {}) + 1, #row.objectives do
        row.objectives[index]:Hide()
    end

    row:SetHeight(height)

    return height
end

local function CreateSection(parent, id)
    local section = CreateFrame("Frame", nil, parent)
    section.id = id

    local header = CreateFrame("Button", nil, section)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(SECTION_HEADER_HEIGHT)
    header:RegisterForClicks("LeftButtonUp")

    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(colors.section))

    local toggle = header:CreateFontString(nil, "OVERLAY")
    toggle:SetPoint("LEFT", header, "LEFT", 6, 0)
    toggle:SetWidth(10)
    toggle:SetJustifyH("CENTER")
    toggle:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    toggle:SetTextColor(unpack(colors.gold))
    header.toggle = toggle

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    title:SetJustifyH("LEFT")
    title:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    title:SetTextColor(unpack(colors.gold))
    header.title = title

    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.04)

    header:SetScript("OnClick", function()
        local db = EnsureDatabase()
        db.collapsedSections[id] = not db.collapsedSections[id]
        Module:Refresh()
    end)

    section.header = header
    section.rows = {}

    return section
end

function Module:RegisterProvider(id, provider)
    if not id or not provider then
        return
    end

    if not self.providers[id] then
        self.providerOrder[#self.providerOrder + 1] = id
    end

    self.providers[id] = provider

    table.sort(self.providerOrder, function(left, right)
        local leftProvider = self.providers[left] or {}
        local rightProvider = self.providers[right] or {}

        return (leftProvider.order or 100)
            < (rightProvider.order or 100)
    end)

    if self.initialized then
        self:Refresh()
    end
end

function Module:SetMinimized(minimized)
    local db = EnsureDatabase()
    db.minimized = minimized == true

    if not self.frame then
        return
    end

    self.frame.content:SetShown(not db.minimized)
    self.frame.toggle:SetText(db.minimized and "+" or "-")

    if db.minimized then
        self.frame:SetHeight(HEADER_HEIGHT)
    else
        self:Refresh()
    end
end

function Module:ToggleMinimized()
    self:SetMinimized(not EnsureDatabase().minimized)
end

function Module:Refresh()
    local frame = self.frame

    if not frame then
        return
    end

    if EnsureDatabase().minimized then
        frame:SetHeight(HEADER_HEIGHT)
        frame.content:Hide()
        return
    end

    frame.content:Show()

    local y = 0
    local shownSections = 0

    for _, id in ipairs(self.providerOrder) do
        local provider = self.providers[id]
        local data = provider
            and provider.GetSection
            and provider:GetSection()
        local section = frame.sections[id]

        if data and data.items and #data.items > 0 then
            if not section then
                section = CreateSection(frame.content, id)
                frame.sections[id] = section
            end

            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
            section:SetWidth(PANEL_WIDTH - 2)
            section.header.title:SetText(data.title or id)
            section:Show()

            local collapsed = EnsureDatabase().collapsedSections[id] == true
            section.header.toggle:SetText(collapsed and "+" or "-")

            local sectionHeight = SECTION_HEADER_HEIGHT
            local rowY = SECTION_HEADER_HEIGHT + 3

            if collapsed then
                for _, row in ipairs(section.rows) do
                    row:Hide()
                end
            else
                for index, item in ipairs(data.items) do
                    local row = section.rows[index]

                    if not row then
                        row = CreateQuestRow(section)
                        section.rows[index] = row
                    end

                    row:Show()
                    local rowHeight = UpdateQuestRow(row, item, rowY)
                    rowY = rowY + rowHeight + QUEST_SPACING
                    sectionHeight = rowY
                end

                for index = #data.items + 1, #section.rows do
                    section.rows[index]:Hide()
                end
            end

            section:SetHeight(sectionHeight)
            y = y + sectionHeight + 4
            shownSections = shownSections + 1
        elseif section then
            section:Hide()
        end
    end

    frame.empty:SetShown(shownSections == 0)

    if shownSections == 0 then
        y = 24
    end

    frame.content:SetHeight(y)
    frame:SetHeight(HEADER_HEIGHT + y + CONTENT_PADDING)
end

local function ScheduleRefresh()
    if Module.refreshPending then
        return
    end

    Module.refreshPending = true

    C_Timer.After(0, function()
        Module.refreshPending = false
        Module:Refresh()
    end)
end

local function CreateFrameUI()
    local frame = CreateFrame(
        "Frame",
        "KamiUIObjectiveTrackerFrame",
        UIParent,
        "BackdropTemplate"
    )

    frame:SetWidth(PANEL_WIDTH)
    frame:SetHeight(HEADER_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    frame:SetBackdropColor(unpack(colors.background))
    CreateBorder(frame)

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT - 2)
    header:RegisterForClicks("LeftButtonUp")
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function(self)
        self.dragging = true
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        SavePosition(frame)

        C_Timer.After(0, function()
            self.dragging = false
        end)
    end)
    header:SetScript("OnClick", function(self)
        if self.dragging then
            return
        end

        Module:ToggleMinimized()
    end)
    frame.header = header

    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetAllPoints()
    headerBackground:SetColorTexture(unpack(colors.header))

    local toggle = CreateFrame("Button", nil, header)
    toggle:SetSize(18, 18)
    toggle:SetPoint("LEFT", header, "LEFT", 4, 0)
    toggle:SetNormalFontObject("GameFontNormal")
    toggle:SetHighlightFontObject("GameFontHighlight")
    toggle:SetText("-")
    toggle:SetScript("OnClick", function()
        Module:ToggleMinimized()
    end)
    frame.toggle = toggle

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    title:SetJustifyH("LEFT")
    title:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    title:SetTextColor(unpack(colors.gold))
    title:SetText("Objectives")
    frame.title = title

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEADER_HEIGHT)
    content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_HEIGHT)
    content:SetHeight(1)
    frame.content = content

    local empty = content:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("TOPLEFT", content, "TOPLEFT", CONTENT_PADDING, -5)
    empty:SetPoint("RIGHT", content, "RIGHT", -CONTENT_PADDING, 0)
    empty:SetJustifyH("LEFT")
    empty:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    empty:SetTextColor(unpack(colors.muted))
    empty:SetText("No tracked objectives")
    frame.empty = empty

    frame.sections = {}

    ApplySavedPosition(frame)

    return frame
end

function Module:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    EnsureDatabase()
    self.frame = CreateFrameUI()

    HideBlizzardTracker()
    self:SetMinimized(EnsureDatabase().minimized)
    self:Refresh()

    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
        "QUEST_POI_UPDATE",
        "QUEST_DATA_LOAD_RESULT",
    }) do
        UI:RegisterEvent(event, ScheduleRefresh)
    end

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_ObjectiveTracker" then
            HideBlizzardTracker()
        end
    end)
end

C_Timer.After(0, function()
    Module:Initialize()
end)
