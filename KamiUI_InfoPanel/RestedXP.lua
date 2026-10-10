local UI = KamiUI

-- Offline rested XP is an estimate, not a live Blizzard API value.
-- Store snapshots per character; never overwrite XP with 0 because a
-- max-level helper returned an incorrect value in the Forever client.
local RestedXP = {}
UI.RestedXP = RestedXP

local BASE_CAP_PERCENT = 150
local LEGACY_BONUS_PER_RANK = 4
local INN_RATE_SECONDS = 8 * 60 * 60
local WORLD_RATE_SECONDS = 32 * 60 * 60
local RESTED_RATE_PERCENT = 5
local MAX_LEVEL = 60
local SCAN_RETRY_SECONDS = 30

local function GetDB()
    return UI:GetDatabase("restedXP", { characters = {} })
end

local function Now()
    return time and time() or 0
end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    return UI:SafeCall(fn, ...)
end

local function SafeNumber(value)
    return type(value) == "number" and UI:CanAccessValue(value)
end

local function ClampRank(rank)
    if not SafeNumber(rank) then return nil end
    return math.max(0, math.min(5, math.floor(rank)))
end

local function GetCurrentValues()
    if not UnitXPMax then return nil end

    local level = UnitLevel and UnitLevel("player")
    local maxXP = UnitXPMax("player")
    if not SafeNumber(maxXP) or not SafeNumber(level) then
        return nil
    end

    -- Forever's level cap is 60. IsPlayerAtMaxLevel() has been observed
    -- to report true on leveling characters, so it is not used here.
    if level >= MAX_LEVEL then
        return nil, true, maxXP
    end
    if maxXP <= 0 then
        return nil, false, maxXP
    end

    local rested = GetXPExhaustion and GetXPExhaustion()
    if rested == nil then rested = 0 end
    if not SafeNumber(rested) then return nil end

    -- Do not clamp the server's live rested amount to the old 150% cap.
    rested = math.max(0, rested)
    return rested / maxXP * 100, false, maxXP, rested
end

local function GetSpellNameFromDefinition(definition)
    local name = definition.overrideName
    if type(name) == "string" and UI:CanAccessValue(name)
        and name ~= "" then
        return name
    end

    local spellID = definition.spellID
    if not SafeNumber(spellID) then return nil end

    if C_Spell and C_Spell.GetSpellName then
        name = Safe(C_Spell.GetSpellName, spellID)
    end
    if not name and C_Spell and C_Spell.GetSpellInfo then
        local info = Safe(C_Spell.GetSpellInfo, spellID)
        if type(info) == "table" and UI:CanAccessValue(info) then
            name = info.name
        end
    end
    return type(name) == "string" and UI:CanAccessValue(name)
        and name or nil
end

-- Generic (non-class) trait configs contain Forever's Legacy tree.
-- Locate the Well Rested node by its actual spell/override name rather
-- than guessing a build-dependent tree, node or entry ID.
local function ScanLegacyRank()
    local traits = C_Traits
    if not traits or not traits.GetConfigsByType
        or not traits.GetConfigInfo or not traits.GetTreeNodes
        or not traits.GetNodeInfo or not traits.GetEntryInfo
        or not traits.GetDefinitionInfo then
        return nil
    end

    local genericType = Enum and Enum.TraitConfigType
        and Enum.TraitConfigType.Generic or 3
    local configIDs = Safe(traits.GetConfigsByType, genericType)
    if type(configIDs) ~= "table" or not UI:CanAccessValue(configIDs) then
        return nil
    end

    for _, configID in ipairs(configIDs) do
        local config = Safe(traits.GetConfigInfo, configID)
        if type(config) == "table" and UI:CanAccessValue(config)
            and type(config.treeIDs) == "table"
            and UI:CanAccessValue(config.treeIDs) then
            for _, treeID in ipairs(config.treeIDs) do
                local nodes = Safe(traits.GetTreeNodes, treeID)
                if type(nodes) == "table" and UI:CanAccessValue(nodes) then
                    for _, nodeID in ipairs(nodes) do
                        local node = Safe(traits.GetNodeInfo, configID, nodeID)
                        if type(node) == "table"
                            and UI:CanAccessValue(node)
                            and type(node.entryIDs) == "table"
                            and UI:CanAccessValue(node.entryIDs) then
                            for _, entryID in ipairs(node.entryIDs) do
                                local entry = Safe(traits.GetEntryInfo,
                                    configID, entryID)
                                local definition = entry
                                    and entry.definitionID
                                    and Safe(traits.GetDefinitionInfo,
                                        entry.definitionID)
                                if type(definition) == "table"
                                    and UI:CanAccessValue(definition) then
                                    local name =
                                        GetSpellNameFromDefinition(definition)
                                    if name and string.find(
                                        string.lower(name),
                                        "well rested", 1, true
                                    ) then
                                        -- currentRank corresponds to the
                                        -- current committed node state when
                                        -- the player has no staged changes.
                                        return ClampRank(
                                            node.ranksPurchased
                                            or node.currentRank
                                            or node.activeRank
                                        ) or 0
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

function RestedXP:InvalidateLegacyRank()
    self.scanAt = nil
    self.scannedRank = nil
end

function RestedXP:GetCurrentLegacyRank()
    local key = UI:GetCurrentCharacterKey()
    local saved = GetDB().characters[key]
    if saved and saved.manualLegacyRank ~= nil then
        return ClampRank(saved.manualLegacyRank), true
    end

    local now = GetTime and GetTime() or 0
    if self.scanAt == nil or now - self.scanAt >= SCAN_RETRY_SECONDS then
        self.scannedRank = ScanLegacyRank()
        self.scanAt = now
    end
    return self.scannedRank, false
end

function RestedXP:SetManualLegacyRank(rank)
    local key = UI:GetCurrentCharacterKey()
    local chars = GetDB().characters
    local saved = chars[key] or {}
    saved.manualLegacyRank = ClampRank(rank)
    chars[key] = saved
    self:InvalidateLegacyRank()
    self:CaptureCurrent()
end

-- The Legacy talent extends the normal 150%-of-level-XP cap by four
-- percentage points per purchased rank (154% at 1/5, 170% at 5/5).
-- Keep unknown ranks distinct from 0/5: their true cap is not known.
function RestedXP:GetCapPercent(rank)
    local validRank = ClampRank(rank)
    if validRank == nil then return nil end
    return BASE_CAP_PERCENT + validRank * LEGACY_BONUS_PER_RANK
end

function RestedXP:GetCurrentPercent()
    local percent, maxLevel = GetCurrentValues()
    return percent, maxLevel
end

function RestedXP:CaptureCurrent()
    local percent, maxLevel, maxXP, restedXP = GetCurrentValues()
    if percent == nil and not maxLevel then
        return
    end

    local key = UI:GetCurrentCharacterKey()
    local saved = GetDB().characters
    local _, _, name = UI:GetCurrentCharacterNames()
    local _, classFile = UnitClass("player")
    local rank = self:GetCurrentLegacyRank()
    local snapshot = saved[key] or {}

    snapshot.name = name
    snapshot.realm = GetRealmName and GetRealmName() or ""
    snapshot.classFile = classFile
    snapshot.level = UnitLevel("player")
    snapshot.maxLevel = maxLevel == true
    snapshot.maxXP = maxXP or 0

    if maxLevel then
        snapshot.restedXP = 0
    else
        snapshot.restedXP = restedXP
    end

    if rank ~= nil then
        snapshot.legacyRank = rank
    end

    snapshot.resting = IsResting and IsResting() == true or false
    snapshot.updated = Now()
    saved[key] = snapshot
end

local function GetEstimatedPercent(snapshot, isCurrent)
    local maxXP = snapshot.maxXP
    local restedXP = snapshot.restedXP
    local level = snapshot.level
    local rank = ClampRank(snapshot.manualLegacyRank)
        or ClampRank(snapshot.legacyRank)

    -- Old snapshots wrongly marked some low-level characters as max-level.
    -- They also discarded their actual restedXP. Never interpret that
    -- artificial zero as real data: mark unknown until next login.
    if snapshot.maxLevel and SafeNumber(level) and level < MAX_LEVEL then
        return nil, false, false, rank
    end

    if SafeNumber(level) and level >= MAX_LEVEL then
        return nil, false, true, rank
    end

    if not SafeNumber(maxXP) or maxXP <= 0
        or not SafeNumber(restedXP) then
        return nil, false, false, rank
    end

    -- The per-rank 4% cap increase is treated as four percentage points,
    -- making a rank-5 character's projection limit 170%. The game's
    -- exact additive-vs-multiplicative cap semantics are unverified.
    local cap = RestedXP:GetCapPercent(rank) or BASE_CAP_PERCENT

    -- Never suppress an actual observed value above the estimate cap.
    local percent = math.max(0, restedXP / maxXP * 100)
    if isCurrent then
        return percent, false, false, rank
    end

    local timestamp = SafeNumber(snapshot.updated)
        and snapshot.updated or Now()
    local elapsed = math.max(0, Now() - timestamp)
    local rateSeconds = snapshot.resting and INN_RATE_SECONDS
        or WORLD_RATE_SECONDS
    local gain = elapsed / rateSeconds * RESTED_RATE_PERCENT
    gain = gain * (1 + (rank or 0) * LEGACY_BONUS_PER_RANK / 100)

    return math.min(math.max(cap, percent), percent + gain),
        elapsed > 0, false, rank
end

function RestedXP:GetCharacterEntries()
    self:CaptureCurrent()
    local snapshots = GetDB().characters
    local records, seen = {}, {}
    local characters = UI:GetCharactersModule()

    if characters and characters.GetSortedCharacters then
        for _, entry in ipairs(characters:GetSortedCharacters()) do
            if not seen[entry.key] then
                records[#records + 1] = {
                    key = entry.key,
                    character = entry.character,
                }
                seen[entry.key] = true
            end
        end
    end

    for key, snapshot in pairs(snapshots) do
        if not seen[key] then
            records[#records + 1] = {
                key = key,
                character = UI:GetCharacterProfile(key, snapshot),
            }
            seen[key] = true
        end
    end

    local currentKey = UI:GetCurrentCharacterKey()
    if not seen[currentKey] then
        records[#records + 1] = {
            key = currentKey,
            character = UI:GetCharacterProfile(currentKey),
        }
    end
    UI:SortCharacterEntries(records)

    for _, entry in ipairs(records) do
        entry.isCurrent = entry.key == currentKey
        local snapshot = snapshots[entry.key]
        if snapshot then
            entry.percent, entry.estimated, entry.maxLevel,
                entry.legacyRank =
                GetEstimatedPercent(snapshot, entry.isCurrent)
            -- This is the state captured on logout/last snapshot; do not
            -- confuse it with whether the viewed character rests now.
            entry.restingOnLogout = snapshot.resting
        end
    end

    return records
end

UI:RegisterCommand("rested", "rank", function(value)
    if value ~= "auto" then
        local rank = tonumber(value)
        if not rank or rank < 0 or rank > 5
            or rank ~= math.floor(rank) then
            UI:Print("Usage: /kami rested rank 0-5 (or auto)")
            return
        end
        RestedXP:SetManualLegacyRank(rank)
        UI:Print("Well Rested rank set to", rank)
    else
        RestedXP:SetManualLegacyRank(nil)
        UI:Print("Well Rested: automatic talent detection enabled")
    end
end, "Set this character's Well Rested rank (0-5, auto)")

-- Re-scan when a Legacy allocation changes. This event is present on
-- current Forever builds; guarded registration tolerates early beta builds.
for _, event in ipairs({
    "TRAIT_CONFIG_UPDATED",
    "TRAIT_NODE_CHANGED",
}) do
    pcall(function()
        UI:RegisterEvent(event, function()
            RestedXP:InvalidateLegacyRank()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    RestedXP:CaptureCurrent()
                end)
            end
        end)
    end)
end
