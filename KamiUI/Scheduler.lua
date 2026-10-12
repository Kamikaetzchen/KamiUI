local UI = KamiUI

-- A keyed, last-write-wins queue for operations that their OWNER has
-- classified as unsafe in combat. This service never guesses whether an
-- arbitrary WoW API or frame operation is protected.
local pending = {}
local order = {}

function UI:CancelOutOfCombat(key)
    pending[key] = nil
end

function UI:RunOutOfCombat(key, callback)
    assert(type(key) == "string" and key ~= "", "A deferred task needs a key")
    assert(type(callback) == "function", "A deferred task needs a callback")

    if not InCombatLockdown or not InCombatLockdown() then
        -- An explicit immediate update supersedes an older deferred one.
        self:CancelOutOfCombat(key)
        return callback()
    end

    -- Coalesce repeated events: retain one task per key, replacing its
    -- callback so it will read the latest state when combat ends.
    if pending[key] == nil then
        order[#order + 1] = key
    end
    pending[key] = callback
    return false
end

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    -- Detach the current batch before invoking it: callbacks may add tasks.
    local tasks = pending
    local keys = order
    pending = {}
    order = {}

    for _, key in ipairs(keys) do
        local callback = tasks[key]
        if callback then
            if InCombatLockdown and InCombatLockdown() then
                UI:RunOutOfCombat(key, callback)
            else
                -- One module's error must not prevent unrelated tasks
                -- from being replayed.
                local ok, err = pcall(callback)
                if not ok then
                    UI:Print("Deferred task " .. key .. " failed: " .. tostring(err))
                end
            end
        end
    end
end)
