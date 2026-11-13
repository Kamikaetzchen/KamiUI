local UI = KamiUI

local Module = UI:NewModule("Quests", "KamiUI_Quests")


local function ShouldBypass()
    return IsShiftKeyDown and IsShiftKeyDown()
end

-- Quest events can precede the server/UI finishing a dialog transition.
-- Keep every delayed action tied to its original quest and dialog stage.
local dialogGeneration = 0
local activeAccept
local activeReward

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

-- The first reward claim must not wait for Forever's sometimes-late
-- quest-choice metadata. An early GetQuestReward(0) for an actual choice
-- quest is rejected by the game; if the panel survives, re-read the data
-- and retry. Never guess an item index when multiple choices are known.
local function ClaimCurrentQuestReward(generation)
    if ShouldBypass() or not C_Timer or not C_Timer.After
        or not GetQuestReward or not GetNumQuestChoices then
        return
    end

    local state = { questID = CurrentQuestID(), claimed = false }
    activeReward = state
    local startTime = GetTime()
    local attempts = 0
    local nextDelay = { 0.12, 0.25, 0.45 }
    local MAX_WAIT = 1.6

    local function TryReward()
        if generation ~= dialogGeneration or ShouldBypass()
            or activeReward ~= state or state.claimed then
            return
        end

        local currentID = CurrentQuestID()
        if not state.questID then state.questID = currentID end
        if currentID and state.questID and currentID ~= state.questID then
            return
        end

        if not state.questID or not QuestFrameRewardPanel
            or not QuestFrameRewardPanel:IsShown() then
            if GetTime() - startTime < MAX_WAIT then
                C_Timer.After(0.05, TryReward)
            end
            return
        end

        local choices = GetNumQuestChoices()
        if not UI:CanAccessValue(choices)
            or type(choices) ~= "number" or choices < 0 then
            if GetTime() - startTime < MAX_WAIT then
                C_Timer.After(0.05, TryReward)
            end
            return
        end

        local logChoices
        if GetNumQuestLogChoices then
            local ok, count = pcall(GetNumQuestLogChoices,
                state.questID, true)
            if ok and UI:CanAccessValue(count)
                and type(count) == "number" and count >= 0 then
                logChoices = count
            end
        end

        if choices > 1 or (logChoices and logChoices > 1) then
            -- Never auto-select among multiple reward items.
            return
        end

        local money = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
        if not UI:CanAccessValue(money) or type(money) ~= "number" then
            if GetTime() - startTime < MAX_WAIT then
                C_Timer.After(0.05, TryReward)
            end
            return
        end
        if money > 0 then return end

        if attempts >= 4 then return end
        attempts = attempts + 1
        GetQuestReward(choices == 1 and 1 or 0)

        -- An immediate claim can precede server-side reward readiness.
        -- Retry only while this exact dialog and quest remain active.
        local delay = nextDelay[attempts]
        if delay then
            C_Timer.After(delay, TryReward)
        end
    end

    -- Fast path: attempt right in QUEST_COMPLETE, like QuickQuest.
    TryReward()
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
        activeReward = nil
    end)

    UI:RegisterEvent("QUEST_TURNED_IN", function(_, id)
        if activeReward and id == activeReward.questID then
            activeReward.claimed = true
        end
    end)

    UI:RegisterEvent("QUEST_ACCEPTED", function(_, id, alternateID)
        if activeAccept and (id == activeAccept.questID
            or alternateID == activeAccept.questID) then
            activeAccept.accepted = true
        end
    end)

end

Module:Initialize()
