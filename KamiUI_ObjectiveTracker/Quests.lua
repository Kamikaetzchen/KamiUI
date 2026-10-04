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

    if complete and #objectives == 0 then
        objectives[#objectives + 1] = {
            text = "Ready for turn-in",
            finished = true,
        }
    end

    return {
        questID = questID,
        title = title or ("Quest " .. tostring(questID)),
        level = level,
        objectives = objectives,
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
