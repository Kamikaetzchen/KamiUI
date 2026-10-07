local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("ObjectiveTracker", "KamiUI_ObjectiveTracker")

Module.providers = {}
Module.providerOrder = {}

local PANEL_WIDTH = 300
local COLLAPSED_WIDTH = 120
local HEADER_HEIGHT = 24
local CONTENT_PADDING = 6
local SECTION_HEADER_HEIGHT = 20
local HEADER_INDENT = 2
local SECTION_INDENT = 4
local QUEST_INDENT = 2
local QUEST_LEVEL_WIDTH = 34
local QUEST_TITLE_GAP = 5
local QUEST_ITEM_SIZE = 18
local QUEST_ITEM_GAP = 4
local OBJECTIVE_INDENT = 52
local QUEST_SPACING = 4
local OBJECTIVE_SPACING = 1

local OBJECTIVE_DATABASE_DEFAULTS = {
    minimized = false,
    collapsedSections = {},
}

local function GetDatabase()
    return UI:GetDatabase(
        "objectiveTracker",
        OBJECTIVE_DATABASE_DEFAULTS
    )
end

local function SavePosition(frame)
    local centerX = frame:GetCenter()
    local parentCenterX = UIParent:GetCenter()
    local top = frame:GetTop()
    local parentTop = UIParent:GetTop()

    if not centerX or not parentCenterX or not top or not parentTop then
        return
    end

    local anchor
    local x

    if centerX < parentCenterX then
        local left = frame:GetLeft()
        local parentLeft = UIParent:GetLeft()

        if not left or not parentLeft then
            return
        end

        anchor = "TOPLEFT"
        x = left - parentLeft
    else
        local right = frame:GetRight()
        local parentRight = UIParent:GetRight()

        if not right or not parentRight then
            return
        end

        anchor = "TOPRIGHT"
        x = right - parentRight
    end

    local y = top - parentTop

    frame:ClearAllPoints()
    frame:SetPoint(anchor, UIParent, anchor, x, y)

    GetDatabase().position = {
        anchor = anchor,
        x = x,
        y = y,
    }
end

local function ApplySavedPosition(frame)
    local position = GetDatabase().position

    frame:ClearAllPoints()

    if position
        and (position.anchor == "TOPLEFT"
            or position.anchor == "TOPRIGHT")
    then
        frame:SetPoint(
            position.anchor,
            UIParent,
            position.anchor,
            position.x or 0,
            position.y or -160
        )
    elseif position then
        frame:SetPoint(
            position.point or "TOPRIGHT",
            UIParent,
            position.relativePoint or "TOPRIGHT",
            position.x or -40,
            position.y or -160
        )
        Module.positionNeedsMigration = true
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -160)
    end
end

local function HideBlizzardTracker()
    UI:KeepFrameHidden(_G.ObjectiveTrackerFrame)
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
    level:SetWidth(QUEST_LEVEL_WIDTH)
    level:SetJustifyH("RIGHT")
    level:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    row.level = level

    local title = row:CreateFontString(nil, "OVERLAY")
    title:SetPoint(
        "TOPLEFT",
        level,
        "TOPRIGHT",
        QUEST_TITLE_GAP,
        0
    )
    title:SetWidth(
        PANEL_WIDTH
            - SECTION_INDENT
            - QUEST_INDENT
            - QUEST_LEVEL_WIDTH
            - QUEST_TITLE_GAP
            - CONTENT_PADDING
            - 4
    )
    title:SetJustifyH("LEFT")
    title:SetJustifyV("TOP")
    title:SetWordWrap(true)
    title:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    title:SetTextColor(unpack(Palette.text))
    row.title = title

    local itemButton = CreateFrame(
        "Button",
        nil,
        row,
        "SecureActionButtonTemplate"
    )
    itemButton:SetSize(QUEST_ITEM_SIZE, QUEST_ITEM_SIZE)
    itemButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -1, -1)
    itemButton:RegisterForClicks("LeftButtonUp")
    itemButton:SetAttribute("type", "item")
    itemButton:Hide()

    local itemIcon = itemButton:CreateTexture(nil, "ARTWORK")
    itemIcon:SetAllPoints()
    itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    itemButton.icon = itemIcon

    local itemBorder = itemButton:CreateTexture(nil, "OVERLAY")
    itemBorder:SetPoint("TOPLEFT", -1, 1)
    itemBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    itemBorder:SetColorTexture(0, 0, 0, 0.85)
    itemBorder:SetDrawLayer("OVERLAY", -1)

    local itemCount = itemButton:CreateFontString(nil, "OVERLAY")
    itemCount:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -1, 1)
    itemCount:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    itemCount:SetJustifyH("RIGHT")
    itemButton.count = itemCount

    itemButton:SetScript("OnEnter", function(self)
        if not self.itemLink then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end)

    itemButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.itemButton = itemButton

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
    text:SetPoint("LEFT", row, "LEFT", OBJECTIVE_INDENT, 0)
    text:SetWidth(
        PANEL_WIDTH
            - SECTION_INDENT
            - QUEST_INDENT
            - OBJECTIVE_INDENT
            - CONTENT_PADDING
            - 4
    )
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    row.objectives[index] = text

    return text
end

local function UpdateQuestItemButton(row, questItem)
    local button = row.itemButton

    if not button then
        return
    end

    if not questItem or not questItem.link then
        button.itemLink = nil
        button.icon:SetTexture(nil)
        button.count:SetText("")

        if not InCombatLockdown or not InCombatLockdown() then
            button:SetAttribute("item", nil)
            button:Hide()
        else
            Module.questItemRefreshPending = true
        end

        return
    end

    button.itemLink = questItem.link
    button.icon:SetTexture(questItem.texture)

    local charges = tonumber(questItem.charges) or 0
    button.count:SetText(charges > 0 and charges or "")

    if not InCombatLockdown or not InCombatLockdown() then
        button:SetAttribute("item", questItem.link)
        button:Show()
    else
        local currentItem = button:GetAttribute("item")

        if currentItem == questItem.link then
            button:Show()
        else
            Module.questItemRefreshPending = true
        end
    end
end

local function UpdateQuestRow(row, item, y)
    row:ClearAllPoints()
    row:SetPoint(
        "TOPLEFT",
        row:GetParent(),
        "TOPLEFT",
        QUEST_INDENT,
        -y
    )
    row:SetWidth(
        PANEL_WIDTH
            - SECTION_INDENT
            - QUEST_INDENT
            - CONTENT_PADDING
            - 2
    )
    row.questID = item.questID

    local level = tonumber(item.level) or 0
    local difficultyColor = Palette:GetLevelDifficultyColor(level)

    row.level:SetText(level > 0 and string.format("[%d]", level) or "[?]")
    Styles:SetTextColor(row.level, difficultyColor)
    row.title:SetText(item.title or "Unknown Quest")

    UpdateQuestItemButton(row, item.questItem)

    local titleWidth =
        PANEL_WIDTH
            - SECTION_INDENT
            - QUEST_INDENT
            - QUEST_LEVEL_WIDTH
            - QUEST_TITLE_GAP
            - CONTENT_PADDING
            - 4

    if item.questItem then
        titleWidth = titleWidth
            - QUEST_ITEM_SIZE
            - QUEST_ITEM_GAP
    end

    row.title:SetWidth(titleWidth)

    local titleHeight = math.max(16, math.ceil(row.title:GetStringHeight() or 16))
    local height = titleHeight

    for index, objective in ipairs(item.objectives or {}) do
        local text = GetObjectiveFont(row, index)

        text:ClearAllPoints()
        text:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            OBJECTIVE_INDENT,
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
            text:SetTextColor(unpack(Palette.success))
        else
            text:SetTextColor(unpack(Palette.muted))
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

    local header = Components:CreateSection(section, {
        text = id,
        collapsible = true,
        expanded = true,
        height = SECTION_HEADER_HEIGHT,
        inset = 0,
    })
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:RegisterForClicks("LeftButtonUp")

    header:SetScript("OnClick", function()
        local db = GetDatabase()
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
    local db = GetDatabase()
    db.minimized = minimized == true

    if not self.frame then
        return
    end

    self.frame.content:SetShown(not db.minimized)
    self.frame.toggle:SetText(db.minimized and "+" or "-")
    self.frame:SetWidth(db.minimized and COLLAPSED_WIDTH or PANEL_WIDTH)

    if db.minimized then
        self.frame:SetHeight(HEADER_HEIGHT)
    else
        self:Refresh()
    end
end

function Module:ToggleMinimized()
    self:SetMinimized(not GetDatabase().minimized)
end

function Module:Refresh()
    local frame = self.frame

    if not frame then
        return
    end

    if GetDatabase().minimized then
        frame:SetWidth(COLLAPSED_WIDTH)
        frame:SetHeight(HEADER_HEIGHT)
        frame.content:Hide()
        return
    end

    frame:SetWidth(PANEL_WIDTH)
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
            section:SetPoint(
                "TOPLEFT",
                frame.content,
                "TOPLEFT",
                SECTION_INDENT,
                -y
            )
            section:SetWidth(PANEL_WIDTH - SECTION_INDENT - 2)
            section.header:SetSectionText(data.title or id)
            section:Show()

            local collapsed = GetDatabase().collapsedSections[id] == true
            section.header:SetExpanded(not collapsed)

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
    Styles:ApplyBackdrop(
        frame,
        Palette.window.neutral,
        Palette.border
    )

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
    Styles:SetColor(headerBackground, Palette.white, 0.04)

    local toggle = CreateFrame("Button", nil, header)
    toggle:SetSize(18, 18)
    toggle:SetPoint("LEFT", header, "LEFT", HEADER_INDENT, 0)
    toggle:SetNormalFontObject("GameFontNormal")
    toggle:SetHighlightFontObject("GameFontHighlight")
    toggle:SetText("-")
    Components:StyleButton(toggle)
    toggle:SetScript("OnClick", function()
        Module:ToggleMinimized()
    end)
    frame.toggle = toggle

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
    title:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    title:SetJustifyH("LEFT")
    Styles:ApplyText(title, "panelTitle")
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
    Styles:ApplyText(empty, 9, Palette.muted)
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
    GetDatabase()
    self.frame = CreateFrameUI()

    HideBlizzardTracker()
    self:SetMinimized(GetDatabase().minimized)
    self:Refresh()

    if self.positionNeedsMigration then
        self.positionNeedsMigration = nil
        SavePosition(self.frame)
    end

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

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.questItemRefreshPending then
            Module.questItemRefreshPending = nil
            Module:Refresh()
        end
    end)
end

C_Timer.After(0, function()
    Module:Initialize()
end)
