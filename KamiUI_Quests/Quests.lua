local UI = KamiUI

local Module = UI:NewModule("Quests", "KamiUI_Quests")


local function ShouldBypass()
    return IsShiftKeyDown and IsShiftKeyDown()
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
                return
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
                return
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
                return
            end
        end
    end

    if GetNumAvailableQuests and SelectAvailableQuest then
        local availableCount = GetNumAvailableQuests() or 0

        if availableCount > 0 then
            SelectAvailableQuest(1)
        end
    end
end

local function AcceptCurrentQuest()
    if ShouldBypass() then
        return
    end

    -- Blizzard normally requires a confirmation for PvP quests.
    if QuestFlagsPVP and QuestFlagsPVP() then
        return
    end

    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if AcknowledgeAutoAcceptQuest then
            AcknowledgeAutoAcceptQuest()
        end

        return
    end

    if AcceptQuest then
        AcceptQuest()
    end
end

local function CompleteCurrentQuest()
    if ShouldBypass() then
        return
    end

    if IsQuestCompletable
        and IsQuestCompletable()
        and CompleteQuest
    then
        CompleteQuest()
    end
end

local function ClaimCurrentQuestReward()
    if ShouldBypass() or not GetQuestReward then
        return
    end

    local choiceCount = GetNumQuestChoices
        and GetNumQuestChoices()
        or 0

    -- Never guess when the player has to choose between rewards.
    if choiceCount > 1 then
        return
    end

    -- Blizzard asks for confirmation before quests that cost money.
    local moneyRequired = GetQuestMoneyToGet
        and GetQuestMoneyToGet()
        or 0

    if moneyRequired > 0 then
        return
    end

    GetQuestReward(choiceCount == 1 and 1 or 0)
end

function Module:Initialize()
    UI:RegisterEvent("GOSSIP_SHOW", function()
        SelectGossipQuest()
    end)

    UI:RegisterEvent("QUEST_GREETING", function()
        SelectGreetingQuest()
    end)

    UI:RegisterEvent("QUEST_DETAIL", function()
        AcceptCurrentQuest()
    end)

    UI:RegisterEvent("QUEST_PROGRESS", function()
        CompleteCurrentQuest()
    end)

    UI:RegisterEvent("QUEST_COMPLETE", function()
        ClaimCurrentQuestReward()
    end)
end

Module:Initialize()
