local UI = KamiUI
local Module = UI:GetModule("Quests")

if not Module then
    return
end

-- Blizzard resets quest category headers based on the current map zone.
-- Keep manual choices per character, and restore them after those resets.
-- Unseen headers start expanded.
local HEADER_DEFAULTS = {
    questLogHeaders = {},
}

local hooks = {}
local restoring = false
local queuedRestores = {}

local function GetHeaderStates()
    local db = UI:GetDatabase("quests", HEADER_DEFAULTS)
    local key = UI:GetCurrentCharacterKey()
    local states = db.questLogHeaders[key]

    if type(states) ~= "table" then
        states = {}
        db.questLogHeaders[key] = states
    end

    return states
end

local function GetHeaderCount()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        return 0
    end

    local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)

    if not ok or not UI:CanAccessValue(count)
        or type(count) ~= "number" then
        return 0
    end

    return count
end

local function GetHeader(index)
    if not C_QuestLog or not C_QuestLog.GetInfo then
        return nil
    end

    local ok, info = pcall(C_QuestLog.GetInfo, index)

    if not ok or not info or not UI:CanAccessValue(info) then
        return nil
    end

    local title = info.title
    local isHeader = info.isHeader
    local collapsed = info.isCollapsed

    if not UI:CanAccessValue(title)
        or not UI:CanAccessValue(isHeader)
        or not UI:CanAccessValue(collapsed)
        or isHeader ~= true
        or type(title) ~= "string"
        or title == "" then
        return nil
    end

    return title, collapsed == true
end

-- The native APIs distinguish user actions from automatic resets with
-- isAuto. Record only user actions, never Blizzard's zone-based choices
-- or the restore operations below.
local function RememberHeader(index, isAuto)
    if isAuto == true or restoring then return end

    local states = GetHeaderStates()

    if type(index) == "number" and index > 0 then
        local title, collapsed = GetHeader(index)

        if title then
            states[title] = collapsed
        end

        return
    end

    -- Index 0 means all headers (e.g. a user expand-all action).
    for i = 1, GetHeaderCount() do
        local title, collapsed = GetHeader(i)

        if title then
            states[title] = collapsed
        end
    end
end

local function RestoreHeaders()
    if restoring or not QuestMapFrame or not QuestMapFrame:IsShown()
        or not ExpandQuestHeader or not CollapseQuestHeader then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        UI:RunOutOfCombat("quests.questlog.headers", RestoreHeaders)
        return
    end

    local states = GetHeaderStates()
    local changes = {}

    -- Work backwards so collapsing a header cannot affect an index
    -- we still need to visit.
    for index = GetHeaderCount(), 1, -1 do
        local title, collapsed = GetHeader(index)

        if title then
            local wantCollapsed = states[title] == true

            if collapsed ~= wantCollapsed then
                changes[#changes + 1] = {
                    index = index,
                    collapsed = wantCollapsed,
                }
            end
        end
    end

    if #changes == 0 then return end

    restoring = true

    local ok, err = pcall(function()
        for _, change in ipairs(changes) do
            if change.collapsed then
                CollapseQuestHeader(change.index)
            else
                ExpandQuestHeader(change.index)
            end
        end
    end)

    restoring = false

    if not ok then
        UI:Print("Could not restore quest log headers:", err)
    end
end

local function QueueRestore(delay)
    if not C_Timer or not C_Timer.After
        or queuedRestores[delay] then
        return
    end

    queuedRestores[delay] = true

    C_Timer.After(delay, function()
        queuedRestores[delay] = nil
        RestoreHeaders()
    end)
end

local function HookQuestLog()
    if hooksecurefunc and not hooks.collapse
        and type(CollapseQuestHeader) == "function" then
        hooks.collapse = true
        hooksecurefunc("CollapseQuestHeader", RememberHeader)
    end

    if hooksecurefunc and not hooks.expand
        and type(ExpandQuestHeader) == "function" then
        hooks.expand = true
        hooksecurefunc("ExpandQuestHeader", RememberHeader)
    end

    if hooksecurefunc and not hooks.reset
        and type(QuestMapFrame_ResetFilters) == "function" then
        hooks.reset = true
        hooksecurefunc("QuestMapFrame_ResetFilters", function()
            QueueRestore(0)
        end)
    end

    if QuestMapFrame and not hooks.map then
        hooks.map = true

        QuestMapFrame:HookScript("OnShow", function()
            QueueRestore(0)
            -- Forever may reset the quest list again after opening it.
            QueueRestore(0.6)
        end)

        if QuestMapFrame:IsShown() then
            QueueRestore(0)
        end
    end
end

-- The map UI can load on demand, after KamiUI_Quests.
HookQuestLog()
UI:RegisterEvent("ADDON_LOADED", HookQuestLog)
