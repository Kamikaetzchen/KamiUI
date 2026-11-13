local UI = KamiUI

local Module = UI:NewModule("Quests", "KamiUI_Quests")


local function ShouldBypass()
    return IsShiftKeyDown and IsShiftKeyDown()
end

-- Quest events can precede the server/UI finishing a dialog transition.
-- Keep every delayed action tied to its original quest and dialog stage.
local dialogGeneration = 0
local activeAccept

local function CurrentQuestID()
    if not GetQuestID then return nil end
    local id = GetQuestID()
    if UI:CanAccessValue(id) and type(id) == "number" and id > 0 then
        return id
    end
end

local function NewDialog(event)
    dialogGeneration = dialogGeneration + 1
    return dialogGeneration
end

local function DialogMatches(generation, questID, panel)
    return generation == dialogGeneration
        and not ShouldBypass()
        and panel and panel:IsShown()
        and questID and CurrentQuestID() == questID
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

-- Select available quests immediately. Forever sometimes publishes the
-- gossip list a frame or two after GOSSIP_SHOW, so retry only while the
-- same dialog is still open and no quest was selected.
local function OpenGossipQuest(event, selector, panel)
    local generation = NewDialog(event)
    local retryDelays = { 0.04, 0.08, 0.15, 0.25 }
    local nextRetry = 1

    local function TrySelect()
        if generation ~= dialogGeneration or ShouldBypass() then return end
        if (nextRetry == 1 or (panel and panel:IsShown()))
            and selector() then
            return
        end

        local delay = retryDelays[nextRetry]
        if delay and C_Timer and C_Timer.After then
            nextRetry = nextRetry + 1
            C_Timer.After(delay, TrySelect)
        end
    end

    TrySelect()
end

local function AcceptCurrentQuest(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After then return end

    local state = { questID = CurrentQuestID(), accepted = false }
    activeAccept = state
    local checks = 0
    local attempts = 0

    local function TryAccept()
        if generation ~= dialogGeneration or ShouldBypass()
            or activeAccept ~= state or state.accepted then
            return
        end

        checks = checks + 1
        local currentID = CurrentQuestID()
        if not state.questID then
            state.questID = currentID
        end

        -- Do not apply a delayed action to a different quest.
        if currentID and state.questID and currentID ~= state.questID then
            return
        end

        local shown = QuestFrameDetailPanel
            and QuestFrameDetailPanel:IsShown()
        if not state.questID or (checks > 1 and not shown) then
            -- First attempt happens in QUEST_DETAIL itself. If Forever
            -- hasn't exposed the quest ID or panel yet, probe quickly.
            if checks < 9 then
                C_Timer.After(checks <= 4 and 0.04 or 0.1, TryAccept)
            end
            return
        end

        if QuestFlagsPVP and QuestFlagsPVP() then return end

        if QuestGetAutoAccept and QuestGetAutoAccept() then
            if AcknowledgeAutoAcceptQuest then
                AcknowledgeAutoAcceptQuest()
            end
            return
        end

        if not AcceptQuest or attempts >= 3 then return end
        attempts = attempts + 1
        AcceptQuest()

        -- The event may arrive before Forever is ready to process it.
        -- Retry only if QUEST_ACCEPTED hasn't confirmed the same ID and
        -- the detail dialog is still present; never block the first call.
        if attempts < 3 then
            C_Timer.After(attempts == 1 and 0.12 or 0.3, TryAccept)
        end
    end

    TryAccept()
end

local function CompleteCurrentQuest(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After then return end

    local questID = CurrentQuestID()
    local checks = 0
    local attempts = 0

    local function TryComplete()
        if generation ~= dialogGeneration or ShouldBypass() then return end

        checks = checks + 1
        local currentID = CurrentQuestID()
        if not questID then questID = currentID end
        if currentID and questID and currentID ~= questID then return end

        local shown = QuestFrameProgressPanel
            and QuestFrameProgressPanel:IsShown()
        if not questID or (checks > 1 and not shown) then
            if checks < 10 then
                C_Timer.After(0.05, TryComplete)
            end
            return
        end

        local completable = IsQuestCompletable and IsQuestCompletable()
        if UI:CanAccessValue(completable) and completable
            and CompleteQuest and attempts < 3 then
            attempts = attempts + 1
            CompleteQuest()
            if attempts < 3 then
                C_Timer.After(0.15, TryComplete)
            end
        elseif checks < 10 then
            -- Waiting for server-side quest state or missing objectives.
            C_Timer.After(checks <= 4 and 0.05 or 0.12, TryComplete)
        end
    end

    TryComplete()
end

local function ClaimCurrentQuestReward(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After
        or not GetQuestReward or not GetNumQuestChoices then
        return
    end

    local questID = CurrentQuestID()
    local startTime = GetTime()
    local lastChoices
    local stableChecks = 0
    local rewardAttempts = 0

    local function CheckReward()
        if generation ~= dialogGeneration or ShouldBypass() then return end

        local currentID = CurrentQuestID()
        if not questID then questID = currentID end
        if not questID or currentID ~= questID then
            -- Reward panel and quest ID can be late; never claim a
            -- reward after the dialog changed to another quest.
            if not questID and GetTime() - startTime < 0.6 then
                C_Timer.After(0.05, CheckReward)
            end
            return
        end

        if QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown() then
            local choices = GetNumQuestChoices()
            local logChoices
            if GetNumQuestLogChoices then
                local ok, count = pcall(GetNumQuestLogChoices, questID, true)
                if ok and UI:CanAccessValue(count)
                    and type(count) == "number" and count >= 0 then
                    logChoices = count
                end
            end

            if UI:CanAccessValue(choices)
                and type(choices) == "number" and choices >= 0 then
                if choices > 1 or (logChoices and logChoices > 1) then
                    -- Preserve manual selection for multiple rewards.
                    return
                end

                if choices == lastChoices then
                    stableChecks = stableChecks + 1
                else
                    lastChoices = choices
                    stableChecks = 1
                end

                local elapsed = GetTime() - startTime
                local ready
                if choices == 1 then
                    -- One real choice item is positive evidence the
                    -- reward list exists. Don't wait an arbitrary 350 ms.
                    local itemName = GetQuestItemInfo
                        and GetQuestItemInfo("choice", 1)
                    ready = itemName ~= nil
                        and UI:CanAccessValue(itemName)
                else
                    -- Forever can report zero while TWO choice items
                    -- are still loading. Keep the proven 0.7s guard.
                    ready = elapsed >= 0.7 and stableChecks >= 3
                end

                if ready then
                    local money = GetQuestMoneyToGet
                        and GetQuestMoneyToGet() or 0
                    if UI:CanAccessValue(money)
                        and type(money) == "number" and money <= 0 then
                        rewardAttempts = rewardAttempts + 1
                        GetQuestReward(choices == 1 and 1 or 0)

                        -- If the server ignored an early claim, recheck
                        -- only while this exact reward panel survives.
                        if rewardAttempts < 3 then
                            C_Timer.After(0.18, CheckReward)
                        end
                        return
                    end
                    -- Quests charging money keep native confirmation.
                    if UI:CanAccessValue(money)
                        and type(money) == "number" and money > 0 then
                        return
                    end
                end
            end
        end

        if GetTime() - startTime < 1.6 then
            C_Timer.After(0.05, CheckReward)
        end
    end

    -- First check immediately; only defer when the server/UI is not ready.
    CheckReward()
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
        if activeAccept and (id == activeAccept.questID
            or alternateID == activeAccept.questID) then
            activeAccept.accepted = true
        end
    end)

end

Module:Initialize()
