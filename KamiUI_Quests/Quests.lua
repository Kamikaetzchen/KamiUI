local UI = KamiUI

local Module = UI:NewModule("Quests", "KamiUI_Quests")


local function ShouldBypass()
    return IsShiftKeyDown and IsShiftKeyDown()
end

-- Quest events can precede the server/UI finishing a dialog transition.
-- Keep every delayed action tied to its original quest and dialog stage.
local dialogGeneration = 0
local debugEnabled = false
local lastAction
local activeAccept

local function DebugLog(...)
    if debugEnabled then
        UI:Print(string.format("|cff99ccff[QuestDebug %.2f]|r",
            GetTime()), ...)
    end
end

local function CurrentQuestID()
    if not GetQuestID then return nil end
    local id = GetQuestID()
    if UI:CanAccessValue(id) and type(id) == "number" and id > 0 then
        return id
    end
end

local function NewDialog(event)
    dialogGeneration = dialogGeneration + 1
    DebugLog(event, "quest=" .. tostring(CurrentQuestID() or "?"),
        "generation=" .. dialogGeneration)
    return dialogGeneration
end

local function DialogMatches(generation, questID, panel)
    return generation == dialogGeneration
        and not ShouldBypass()
        and panel and panel:IsShown()
        and questID and CurrentQuestID() == questID
end

local function TrackAction(action, questID)
    lastAction = { action = action, questID = questID, time = GetTime() }
    DebugLog("CALL", action, "quest=" .. tostring(questID or "?"))
end

local function SetDebug(value)
    debugEnabled = value
    UI:Print("Quest debug " .. (debugEnabled and "enabled" or "disabled")
        .. " (chat output, /kquestdebug to toggle)")
end

SLASH_KAMIQUESTDEBUG1 = "/kquestdebug"
SlashCmdList["KAMIQUESTDEBUG"] = function(arg)
    arg = (arg or ""):lower()
    if arg == "on" then
        SetDebug(true)
    elseif arg == "off" then
        SetDebug(false)
    else
        SetDebug(not debugEnabled)
    end
end

local function SelectGossipQuest()
    if ShouldBypass() or not C_GossipInfo then
        return
    end

    if C_GossipInfo.GetActiveQuests
        and C_GossipInfo.SelectActiveQuest
    then
        local activeQuests = C_GossipInfo.GetActiveQuests() or {}

        for _, questInfo in ipairs(activeQuests) do
            if questInfo.isComplete and questInfo.questID then
                C_GossipInfo.SelectActiveQuest(questInfo.questID)
                return true
            end
        end
    end

    if C_GossipInfo.GetAvailableQuests
        and C_GossipInfo.SelectAvailableQuest
    then
        local availableQuests = C_GossipInfo.GetAvailableQuests() or {}

        for _, questInfo in ipairs(availableQuests) do
            if questInfo.questID and not questInfo.isIgnored then
                C_GossipInfo.SelectAvailableQuest(questInfo.questID)
                return true
            end
        end
    end
end

local function SelectGreetingQuest()
    if ShouldBypass() then
        return
    end

    if GetNumActiveQuests
        and GetActiveTitle
        and SelectActiveQuest
    then
        local activeCount = GetNumActiveQuests() or 0

        for index = 1, activeCount do
            local _, isComplete = GetActiveTitle(index)

            if isComplete then
                SelectActiveQuest(index)
                return true
            end
        end
    end

    if GetNumAvailableQuests and SelectAvailableQuest then
        local availableCount = GetNumAvailableQuests() or 0

        if availableCount > 0 then
            SelectAvailableQuest(1)
            return true
        end
    end
end

-- Retry an incomplete gossip list once; never revisit a dismissed gossip.
local function OpenGossipQuest(event, selector, panel)
    local generation = NewDialog(event)
    if ShouldBypass() or selector() then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            if generation ~= dialogGeneration or ShouldBypass()
                or not panel or not panel:IsShown() then
                return
            end
            DebugLog("RETRY", event, "quest list was initially empty")
            selector()
        end)
    end
end

local function AcceptCurrentQuest(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After then return end

    local questID = CurrentQuestID()
    local attempts = 0
    local checks = 0
    activeAccept = { questID = questID, accepted = false }

    local function TryAccept()
        if generation ~= dialogGeneration or ShouldBypass() then return end
        checks = checks + 1
        if not QuestFrameDetailPanel
            or not QuestFrameDetailPanel:IsShown() then
            if checks < 6 then
                C_Timer.After(0.1, TryAccept)
            else
                DebugLog("TIMEOUT accept", "detail panel not shown")
            end
            return
        end

        local currentID = CurrentQuestID()
        if not questID then
            questID = currentID
            activeAccept.questID = questID
        end
        if not questID then
            if checks < 6 then
                C_Timer.After(0.1, TryAccept)
            else
                DebugLog("TIMEOUT accept", "quest ID unavailable")
            end
            return
        end
        if currentID ~= questID then
            DebugLog("SKIP accept", "quest ID changed")
            return
        end
        if not activeAccept or activeAccept.accepted then return end

        -- PvP and auto-accept quests retain the native confirmation flow.
        if QuestFlagsPVP and QuestFlagsPVP() then
            DebugLog("SKIP accept", "PvP confirmation")
            return
        end

        attempts = attempts + 1
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            if AcknowledgeAutoAcceptQuest then
                TrackAction("AcknowledgeAutoAcceptQuest", questID)
                AcknowledgeAutoAcceptQuest()
            end
        elseif AcceptQuest then
            TrackAction("AcceptQuest #" .. attempts, questID)
            AcceptQuest()
        end

        -- Some first quest dialogs aren't ready on the first attempt.
        -- Never retry after confirmation, navigation, or dialog closure.
        if attempts < 2 and not (QuestGetAutoAccept
            and QuestGetAutoAccept()) then
            C_Timer.After(0.4, TryAccept)
        end
    end

    C_Timer.After(0.08, TryAccept)
end

local function CompleteCurrentQuest(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After then return end
    local questID = CurrentQuestID()
    if not questID then
        DebugLog("SKIP progress", "quest ID unavailable")
        return
    end

    local attempts = 0
    local function TryComplete()
        if generation ~= dialogGeneration or ShouldBypass()
            or CurrentQuestID() ~= questID then return end

        attempts = attempts + 1
        if not QuestFrameProgressPanel
            or not QuestFrameProgressPanel:IsShown() then
            if attempts < 6 then
                C_Timer.After(0.15, TryComplete)
            else
                DebugLog("TIMEOUT progress", "panel not shown")
            end
            return
        end
        local completable = IsQuestCompletable and IsQuestCompletable()
        if UI:CanAccessValue(completable) and completable then
            if CompleteQuest then
                TrackAction("CompleteQuest", questID)
                CompleteQuest()
            end
            return
        end

        if attempts < 6 then
            C_Timer.After(0.15, TryComplete)
        else
            DebugLog("TIMEOUT progress", "quest=" .. questID)
        end
    end

    C_Timer.After(0.05, TryComplete)
end

local function ClaimCurrentQuestReward(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After
        or not GetQuestReward or not GetNumQuestChoices then
        return
    end

    local questID = CurrentQuestID()
    if not questID then
        DebugLog("SKIP reward", "quest ID unavailable")
        return
    end

    local startTime = GetTime()
    local lastChoices
    local stableChecks = 0
    local attempts = 0

    local function CheckReward()
        if generation ~= dialogGeneration or ShouldBypass()
            or CurrentQuestID() ~= questID then
            DebugLog("CANCEL reward", "dialog changed")
            return
        end
        if not QuestFrameRewardPanel
            or not QuestFrameRewardPanel:IsShown() then
            if GetTime() - startTime < 0.8 then
                C_Timer.After(0.1, CheckReward)
            else
                DebugLog("CANCEL reward", "reward panel not shown")
            end
            return
        end

        attempts = attempts + 1
        local choices = GetNumQuestChoices()
        if not UI:CanAccessValue(choices)
            or type(choices) ~= "number" or choices < 0 then
            DebugLog("REWARD pending", "unavailable choice count")
        elseif choices > 1 then
            DebugLog("REWARD manual", "quest=" .. questID,
                "choices=" .. choices)
            return
        else
            if choices == lastChoices then
                stableChecks = stableChecks + 1
            else
                stableChecks = 1
                lastChoices = choices
            end
            local elapsed = GetTime() - startTime
            DebugLog("REWARD check", "quest=" .. questID,
                "choices=" .. choices, "stable=" .. stableChecks,
                string.format("elapsed=%.2fs", elapsed))

            -- A zero can temporarily mean "choices have not arrived yet".
            -- Wait longer for zero than for a single known choice.
            local minimumWait = choices == 0 and 0.6 or 0.35
            local ready = elapsed >= minimumWait and stableChecks >= 3

            if ready and choices == 1 and GetQuestItemInfo then
                local itemName = GetQuestItemInfo("choice", 1)
                ready = UI:CanAccessValue(itemName) and itemName ~= nil
            end

            if ready then
                local money = GetQuestMoneyToGet
                    and GetQuestMoneyToGet() or 0
                if not UI:CanAccessValue(money) or type(money) ~= "number"
                    or money > 0 then
                    DebugLog("REWARD manual", "money confirmation")
                    return
                end

                TrackAction("GetQuestReward(" .. (choices == 1 and 1 or 0)
                    .. ")", questID)
                GetQuestReward(choices == 1 and 1 or 0)
                return
            end
        end

        if GetTime() - startTime < 1.6 then
            C_Timer.After(0.1, CheckReward)
        else
            DebugLog("TIMEOUT reward", "quest=" .. questID,
                "left for manual completion")
        end
    end

    C_Timer.After(0.1, CheckReward)
end

function Module:Initialize()
    UI:RegisterEvent("GOSSIP_SHOW", function()
        OpenGossipQuest("GOSSIP_SHOW", SelectGossipQuest, GossipFrame)
    end)

    UI:RegisterEvent("QUEST_GREETING", function()
        OpenGossipQuest("QUEST_GREETING", SelectGreetingQuest,
            QuestFrameGreetingPanel)
    end)

    UI:RegisterEvent("QUEST_DETAIL", function()
        local generation = NewDialog("QUEST_DETAIL")
        AcceptCurrentQuest(generation)
    end)

    UI:RegisterEvent("QUEST_PROGRESS", function()
        local generation = NewDialog("QUEST_PROGRESS")
        CompleteCurrentQuest(generation)
    end)

    UI:RegisterEvent("QUEST_COMPLETE", function()
        local generation = NewDialog("QUEST_COMPLETE")
        ClaimCurrentQuestReward(generation)
    end)

    UI:RegisterEvent("QUEST_FINISHED", function()
        NewDialog("QUEST_FINISHED")
        activeAccept = nil
    end)

    UI:RegisterEvent("QUEST_ACCEPTED", function(_, id, alternateID)
        DebugLog("QUEST_ACCEPTED", "id=" .. tostring(id or "?"),
            "alternate=" .. tostring(alternateID or "?"))
        if activeAccept and (id == activeAccept.questID
            or alternateID == activeAccept.questID) then
            activeAccept.accepted = true
        end
    end)

    UI:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
        DebugLog("QUEST_TURNED_IN", "quest=" .. tostring(questID or "?"))
    end)

    UI:RegisterEvent("UI_ERROR_MESSAGE", function(_, _, message)
        if not debugEnabled then return end
        local action = "none"
        if lastAction and GetTime() - lastAction.time < 3 then
            action = lastAction.action .. " quest="
                .. tostring(lastAction.questID)
        end
        DebugLog("UI_ERROR", tostring(message or "?"),
            "lastAction=" .. action)
    end)
end

Module:Initialize()
