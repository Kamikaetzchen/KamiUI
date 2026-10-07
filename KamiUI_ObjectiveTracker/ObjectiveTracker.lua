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
local MAX_HEIGHT_RATIO = 0.35
local CONTENT_PADDING = 6
local SECTION_HEADER_HEIGHT = 20
local HEADER_INDENT = 2
local SECTION_INDENT = 4
local QUEST_INDENT = 2
local QUEST_SELECT_SIZE = 14
local QUEST_SELECT_GAP = 1
local QUEST_LEVEL_WIDTH = 28
local QUEST_TITLE_GAP = 5
local QUEST_ITEM_SIZE = 18
local QUEST_ITEM_GAP = 4
local OBJECTIVE_INDENT =
    QUEST_SELECT_SIZE
        + QUEST_SELECT_GAP
        + QUEST_LEVEL_WIDTH
        + QUEST_TITLE_GAP
local QUEST_SPACING = 5
local OBJECTIVE_SPACING = 1
local OBJECTIVE_COUNT_WIDTH = 34
local OBJECTIVE_COUNT_GAP = 5

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

local function GetSuperTrackedQuestID()
    if C_SuperTrack
        and C_SuperTrack.GetSuperTrackedQuestID
    then
        return C_SuperTrack.GetSuperTrackedQuestID()
    end

    return nil
end

local function ToggleSuperTrackedQuest(questID)
    if not questID
        or not C_SuperTrack
        or not C_SuperTrack.SetSuperTrackedQuestID
    then
        return
    end

    local current = GetSuperTrackedQuestID()

    C_SuperTrack.SetSuperTrackedQuestID(
        current == questID and 0 or questID
    )

    Module:Refresh()
end

local function CreateQuestRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(18)
    row:RegisterForClicks("LeftButtonUp")

    local selectButton = Components:CreateRadioButton(
        row,
        {
            size = QUEST_SELECT_SIZE,
        }
    )
    selectButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
    selectButton:RegisterForClicks("LeftButtonUp")

    selectButton:SetScript("OnClick", function()
        ToggleSuperTrackedQuest(row.questID)
    end)

    selectButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(
            selectButton,
            "ANCHOR_CURSOR_RIGHT"
        )
        GameTooltip:SetText(
            row.questID == GetSuperTrackedQuestID()
                and "Stop tracking quest"
                or "Track quest"
        )
        GameTooltip:Show()
    end)

    selectButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.selectButton = selectButton

    local level = row:CreateFontString(nil, "OVERLAY")
    level:SetPoint(
        "TOPLEFT",
        selectButton,
        "TOPRIGHT",
        QUEST_SELECT_GAP,
        2
    )
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
            - QUEST_SELECT_SIZE
            - QUEST_SELECT_GAP
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

    local itemBorder = itemButton:CreateTexture(nil, "BACKGROUND")
    itemBorder:SetAllPoints()
    itemBorder:SetColorTexture(0, 0, 0, 0.85)

    local itemIcon = itemButton:CreateTexture(nil, "ARTWORK")
    itemIcon:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 1, -1)
    itemIcon:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -1, 1)
    itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    itemButton.icon = itemIcon

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
    row.objectiveCounts = {}

    row:SetScript("OnClick", function(self)
        if self.onClick then
            self.onClick(self)
        elseif self.questID then
            OpenQuest(self.questID)
        end
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

local function GetObjectiveCountFont(row, index)
    local count = row.objectiveCounts[index]

    if count then
        return count
    end

    count = row:CreateFontString(nil, "OVERLAY")
    count:SetWidth(OBJECTIVE_COUNT_WIDTH)
    count:SetJustifyH("RIGHT")
    count:SetJustifyV("TOP")
    count:SetWordWrap(false)
    count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    row.objectiveCounts[index] = count

    return count
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
    row.onClick = item.onClick

    local showQuestControls = item.showQuestControls ~= false
    local titleWidth

    row.title:ClearAllPoints()

    if showQuestControls then
        local level = tonumber(item.level) or 0
        local difficultyColor =
            Palette:GetLevelDifficultyColor(level)

        row.selectButton:Show()
        row.level:Show()
        row.level:SetText(
            level > 0
                and string.format("[%d]", level)
                or "[?]"
        )
        Styles:SetTextColor(row.level, difficultyColor)
        Components:SetToggleState(
            row.selectButton,
            item.questID == GetSuperTrackedQuestID(),
            true
        )

        row.title:SetPoint(
            "TOPLEFT",
            row.level,
            "TOPRIGHT",
            QUEST_TITLE_GAP,
            0
        )

        titleWidth =
            PANEL_WIDTH
                - SECTION_INDENT
                - QUEST_INDENT
                - QUEST_SELECT_SIZE
                - QUEST_SELECT_GAP
                - QUEST_LEVEL_WIDTH
                - QUEST_TITLE_GAP
                - CONTENT_PADDING
                - 4
    else
        Components:SetToggleState(
            row.selectButton,
            false,
            true
        )
        row.selectButton:Hide()
        row.level:Hide()

        row.title:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            4,
            0
        )

        titleWidth =
            PANEL_WIDTH
                - SECTION_INDENT
                - QUEST_INDENT
                - CONTENT_PADDING
                - 10
    end

    row.title:SetText(item.title or "Unknown")
    UpdateQuestItemButton(row, item.questItem)

    if item.questItem then
        titleWidth = titleWidth
            - QUEST_ITEM_SIZE
            - QUEST_ITEM_GAP
    end

    row.title:SetWidth(titleWidth)

    local titleHeight = math.max(14, math.ceil(row.title:GetStringHeight() or 14))
    local height = titleHeight

    local objectiveIndent = showQuestControls
        and OBJECTIVE_INDENT
        or (item.objectiveIndent or 14)

    for index, objective in ipairs(item.objectives or {}) do
        local text = GetObjectiveFont(row, index)
        local count = GetObjectiveCountFont(row, index)
        local hasCount =
            objective.countText ~= nil
            and objective.countText ~= ""
        local textWidth =
            PANEL_WIDTH
                - SECTION_INDENT
                - QUEST_INDENT
                - objectiveIndent
                - CONTENT_PADDING
                - 4

        if hasCount then
            textWidth = textWidth
                - OBJECTIVE_COUNT_WIDTH
                - OBJECTIVE_COUNT_GAP
        end

        text:SetWidth(textWidth)
        text:ClearAllPoints()

        if index > 1 then
            local previousText = row.objectives[index - 1]
            local previousObjective =
                item.objectives[index - 1] or {}
            local previousHasCount =
                previousObjective.countText ~= nil
                and previousObjective.countText ~= ""
            local currentOffset = hasCount
                and OBJECTIVE_COUNT_WIDTH
                    + OBJECTIVE_COUNT_GAP
                or 0
            local previousOffset = previousHasCount
                and OBJECTIVE_COUNT_WIDTH
                    + OBJECTIVE_COUNT_GAP
                or 0

            text:SetPoint(
                "TOPLEFT",
                previousText,
                "BOTTOMLEFT",
                currentOffset - previousOffset,
                -OBJECTIVE_SPACING
            )
        else
            text:SetPoint(
                "TOPLEFT",
                row,
                "TOPLEFT",
                objectiveIndent
                    + (hasCount
                        and OBJECTIVE_COUNT_WIDTH
                            + OBJECTIVE_COUNT_GAP
                        or 0),
                -titleHeight
            )
        end

        if hasCount then
            count:ClearAllPoints()
            count:SetPoint(
                "TOPRIGHT",
                text,
                "TOPLEFT",
                -OBJECTIVE_COUNT_GAP,
                0
            )
            count:SetText(objective.countText)
            count:Show()
            text:SetText(objective.text or "")
        else
            count:Hide()
            text:SetText("- " .. (objective.text or ""))
        end

        if objective.finished then
            text:SetTextColor(unpack(Palette.success))
            count:SetTextColor(unpack(Palette.success))
        else
            text:SetTextColor(unpack(Palette.muted))
            count:SetTextColor(unpack(Palette.muted))
        end

        text:Show()

        local objectiveHeight =
            math.ceil(text:GetStringHeight() or 0)

        if objectiveHeight <= 0 then
            objectiveHeight = 10
        end

        height = height
            + (index == 1 and 0 or OBJECTIVE_SPACING)
            + objectiveHeight
    end

    for index = #(item.objectives or {}) + 1, #row.objectives do
        row.objectives[index]:Hide()

        if row.objectiveCounts[index] then
            row.objectiveCounts[index]:Hide()
        end
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

        if self.frame.scrollFrame then
            self.frame.scrollFrame:SetVerticalScroll(0)
        end

        if self.frame.scrollbar then
            self.frame.scrollbar:SetValue(0)
            self.frame.scrollbar:Hide()
        end
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

    local contentHeight = y + CONTENT_PADDING
    local parentHeight = UIParent:GetHeight() or 0
    local maxFrameHeight = math.max(
        HEADER_HEIGHT + 40,
        math.floor(parentHeight * MAX_HEIGHT_RATIO)
    )
    local viewportHeight = math.min(
        contentHeight,
        maxFrameHeight - HEADER_HEIGHT
    )
    local maxScroll = math.max(
        0,
        contentHeight - viewportHeight
    )

    frame.content:SetHeight(contentHeight)
    frame:SetHeight(HEADER_HEIGHT + viewportHeight)

    if frame.scrollbar then
        frame.scrollbar:SetMinMaxValues(0, maxScroll)

        if maxScroll > 0 then
            local current = math.min(
                frame.scrollbar:GetValue() or 0,
                maxScroll
            )
            frame.scrollbar:SetValue(current)
            frame.scrollFrame:SetVerticalScroll(current)

            if frame.scrollThumb then
                local trackHeight = math.max(
                    1,
                    frame.scrollbar:GetHeight() or 1
                )
                local thumbHeight = math.max(
                    20,
                    trackHeight
                        * viewportHeight
                        / math.max(contentHeight, 1)
                )
                frame.scrollThumb:SetHeight(
                    math.min(trackHeight, thumbHeight)
                )
            end

            frame.scrollbar:Show()
        else
            frame.scrollbar:SetValue(0)
            frame.scrollFrame:SetVerticalScroll(0)
            frame.scrollbar:Hide()
        end
    end
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

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        1,
        -HEADER_HEIGHT
    )
    scrollFrame:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -1,
        1
    )
    scrollFrame:EnableMouseWheel(true)
    frame.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(PANEL_WIDTH - 2)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    frame.content = content

    local scrollbar = CreateFrame("Slider", nil, frame)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetPoint(
        "TOPRIGHT",
        scrollFrame,
        "TOPRIGHT",
        -3,
        -4
    )
    scrollbar:SetPoint(
        "BOTTOMRIGHT",
        scrollFrame,
        "BOTTOMRIGHT",
        -3,
        4
    )
    scrollbar:SetWidth(6)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValueStep(20)
    local _, scrollThumb = Components:StyleScrollBar(scrollbar)

    scrollbar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value or 0)
    end)
    scrollbar:Hide()

    frame.scrollbar = scrollbar
    frame.scrollThumb = scrollThumb

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local _, maxScroll = scrollbar:GetMinMaxValues()

        if not maxScroll or maxScroll <= 0 then
            return
        end

        scrollbar:SetValue(
            math.max(
                0,
                math.min(
                    maxScroll,
                    (scrollbar:GetValue() or 0)
                        - delta * 32
                )
            )
        )
    end)

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
        "SUPER_TRACKING_CHANGED",
        "SUPER_TRACKING_PATH_UPDATED",
        "DISPLAY_SIZE_CHANGED",
        "UI_SCALE_CHANGED",
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
