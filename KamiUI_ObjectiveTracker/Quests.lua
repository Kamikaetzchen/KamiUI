local UI = KamiUI
local Module = UI:GetModule("ObjectiveTracker")

if not Module then
    return
end

local Provider = {
    order = 10,
}

local function GetWatchedQuestIDs()
    local questIDs = {}

    if not C_QuestLog
        or not C_QuestLog.GetNumQuestWatches
        or not C_QuestLog.GetQuestIDForQuestWatchIndex
    then
        return questIDs
    end

    local count = C_QuestLog.GetNumQuestWatches() or 0

    for index = 1, count do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)

        if questID and questID > 0 then
            questIDs[#questIDs + 1] = questID
        end
    end

    return questIDs
end

-- Read the per-quest timer instead of the currently selected quest's timer.
-- Forbidden/restricted quest API calls can fail in 12.x combat, so guard
-- them and only do arithmetic on readable, ordinary numbers.
local function GetQuestTimerDeadline(questID)
    if not C_QuestLog or not C_QuestLog.GetTimeAllowed then
        return nil
    end

    local ok, total, elapsed = pcall(C_QuestLog.GetTimeAllowed, questID)
    if not ok or not UI:CanAccessValue(total)
        or not UI:CanAccessValue(elapsed) then
        return nil
    end
    if type(total) ~= "number" or type(elapsed) ~= "number"
        or total <= 0 then
        return nil
    end

    return GetTime() + math.max(0, total - elapsed)
end

local function GetQuestData(questID)
    local logIndex = C_QuestLog
        and C_QuestLog.GetLogIndexForQuestID
        and C_QuestLog.GetLogIndexForQuestID(questID)
    local info = logIndex
        and C_QuestLog
        and C_QuestLog.GetInfo
        and C_QuestLog.GetInfo(logIndex)
    local title = info and info.title

    if (not title or title == "")
        and C_QuestLog
        and C_QuestLog.GetTitleForQuestID
    then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end

    local level = info and info.level or 0
    -- Match Forever's native [level+] marker for elite quests.
    local isElite = false
    if C_QuestLog and C_QuestLog.IsEliteQuest then
        local ok, result = pcall(C_QuestLog.IsEliteQuest, questID)
        isElite = ok and UI:CanAccessValue(result) and result == true
    end
    local objectives = {}

    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local questObjectives = C_QuestLog.GetQuestObjectives(questID) or {}

        for _, objective in ipairs(questObjectives) do
            if objective.text and objective.text ~= "" then
                objectives[#objectives + 1] = {
                    text = objective.text,
                    finished = objective.finished == true,
                }
            end
        end
    end

    local complete = C_QuestLog
        and C_QuestLog.IsComplete
        and C_QuestLog.IsComplete(questID)

    local questItem

    if logIndex
        and GetQuestLogSpecialItemInfo
    then
        local itemLink, itemTexture, charges, showWhenComplete =
            GetQuestLogSpecialItemInfo(logIndex)

        if itemLink
            and (
                not complete
                or showWhenComplete
            )
        then
            questItem = {
                link = itemLink,
                texture = itemTexture,
                charges = charges,
            }
        end
    end

    -- Forever may retain the last objective text (especially for escorts)
    -- after the quest is complete. The quest completion flag, not the
    -- presence of objectives, determines the ready-for-turn-in state.
    if complete == true then
        objectives = {
            { text = "Ready for turn-in", finished = true },
        }
    end

    return {
        questID = questID,
        title = title or ("Quest " .. tostring(questID)),
        timerDeadline = GetQuestTimerDeadline(questID),
        level = level,
        isElite = isElite,
        objectives = objectives,
        questItem = questItem,
    }
end

function Provider:GetSection()
    local items = {}

    for _, questID in ipairs(GetWatchedQuestIDs()) do
        items[#items + 1] = GetQuestData(questID)
    end

    table.sort(items, function(left, right)
        local leftLevel = tonumber(left.level) or 0
        local rightLevel = tonumber(right.level) or 0

        if leftLevel <= 0 then
            leftLevel = math.huge
        end

        if rightLevel <= 0 then
            rightLevel = math.huge
        end

        if leftLevel == rightLevel then
            return (left.title or "") < (right.title or "")
        end

        return leftLevel < rightLevel
    end)

    return {
        title = "Quests",
        items = items,
    }
end

Module:RegisterProvider("quests", Provider)

-- Blizzard collapses out-of-zone headers when the quest log is reopened.
-- Expand them after the map has finished showing, without replacing or
-- modifying any Blizzard quest-map handlers.
local questLogHooked = false
local expandQueued = false

local function QueueExpandQuestLog()
    if expandQueued then return end
    expandQueued = true

    C_Timer.After(0, function()
        expandQueued = false

        if not QuestMapFrame or not QuestMapFrame:IsShown()
            or not ExpandQuestHeader then
            return
        end

        -- Expanding quests can trigger a map refresh. Avoid doing that
        -- through an insecure addon callback while protected in combat.
        if InCombatLockdown and InCombatLockdown() then
            UI:RunOutOfCombat("questlog.expand", QueueExpandQuestLog)
            return
        end

        -- An update is unnecessary if all headers are already open.
        if C_QuestLog and C_QuestLog.GetNumQuestLogEntries
            and C_QuestLog.GetInfo then
            local count = C_QuestLog.GetNumQuestLogEntries()
            local collapsed = false

            for index = 1, count do
                local info = C_QuestLog.GetInfo(index)
                if info and info.isHeader and info.isCollapsed then
                    collapsed = true
                    break
                end
            end

            if not collapsed then return end
        end

        ExpandQuestHeader(0)
    end)
end

local function HookQuestLog()
    if questLogHooked or not QuestMapFrame then return end
    questLogHooked = true
    QuestMapFrame:HookScript("OnShow", QueueExpandQuestLog)

    if QuestMapFrame:IsShown() then
        QueueExpandQuestLog()
    end
end

-- The world map may not have loaded when this module initializes.
HookQuestLog()
UI:RegisterEvent("ADDON_LOADED", HookQuestLog)
