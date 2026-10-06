local UI = KamiUI

local Module = UI:NewModule("Professions", "KamiUI_Professions")


local RECIPE_CACHE_VERSION = 3

local function GetDatabase()
    return UI:GetDatabase("professions")
end

local function GetCharactersModule()
    local characters = UI:GetModule("Characters")

    if characters
        and characters.GetCurrentCharacterKey
        and characters.GetCharacter
        and characters.GetSortedCharacters
    then
        return characters
    end
end

local function GetCurrentCharacterData()
    local characters = GetCharactersModule()

    if not characters then
        return nil, nil
    end

    if characters.UpdateCurrentCharacter then
        characters:UpdateCurrentCharacter()
    end

    local key = characters:GetCurrentCharacterKey()
    return key, characters:GetCharacter(key)
end

local function GetViewedCharacter()
    local characters = GetCharactersModule()

    if not characters then
        return nil, nil, true
    end

    local currentKey = characters:GetCurrentCharacterKey()
    local key = Module.viewCharacterKey or currentKey

    return key, characters:GetCharacter(key), key == currentKey
end

local function EnsureCharacterProfessions(character)
    if not character then
        return nil
    end

    character.professions = character.professions or {}
    return character.professions
end

local FOREVER_PROFESSION_OPENER_SPELLS = {
    [2656] = true, -- Smelting
    [1278062] = true, -- Gardening
    [1278067] = true, -- Bait and Tackle
    [1278068] = true, -- Tanning
}

local function GetProfessionAbilities(numSpells, spellOffset)
    local abilities = {}

    if not C_SpellBook
        or not C_SpellBook.GetSpellBookItemInfo
        or not Enum
        or not Enum.SpellBookSpellBank
    then
        return abilities
    end

    local spellBank = Enum.SpellBookSpellBank.Player

    for index = 1, numSpells or 0 do
        local spellBookIndex = (spellOffset or 0) + index
        local info = UI:SafeCall(
            C_SpellBook.GetSpellBookItemInfo,
            spellBookIndex,
            spellBank
        )

        if info then
            local tradeSkillLink =
                C_SpellBook.GetSpellBookItemTradeSkillLink
                and UI:SafeCall(
                    C_SpellBook.GetSpellBookItemTradeSkillLink,
                    spellBookIndex,
                    spellBank
                )
                or nil

            local isProfessionOpener =
                tradeSkillLink ~= nil
                or FOREVER_PROFESSION_OPENER_SPELLS[
                    info.spellID
                ] == true

            if not isProfessionOpener then
                abilities[#abilities + 1] = {
                    name = info.name,
                    icon = info.iconID,
                    spellID = info.spellID,
                    spellBookIndex = spellBookIndex,
                    itemType = info.itemType,
                    isPassive = info.isPassive == true,
                }
            end
        end
    end

    return abilities
end

function Module:SnapshotProfessionSkills()
    local _, character = GetCurrentCharacterData()
    local professions = EnsureCharacterProfessions(character)

    if not professions
        or not GetProfessions
        or not GetProfessionInfo
    then
        return
    end

    local professionIndexes = { GetProfessions() }

    for slot = 1, 6 do
        local professionIndex = professionIndexes[slot]

        if professionIndex then
            local name,
                icon,
                rank,
                maxRank,
                numSpells,
                spellOffset,
                skillLineID,
                rankModifier,
                _specializationIndex,
                _specializationOffset,
                skillLineName =
                GetProfessionInfo(professionIndex)

            if skillLineID then
                local saved = professions[skillLineID] or {}

                saved.professionID = skillLineID
                saved.professionSlot = slot

                local professionInfo =
                    C_TradeSkillUI
                    and C_TradeSkillUI.GetProfessionInfoBySkillLineID
                    and UI:SafeCall(
                        C_TradeSkillUI.GetProfessionInfoBySkillLineID,
                        skillLineID
                    )
                    or nil

                if professionInfo then
                    saved.professionEnum =
                        professionInfo.profession
                    saved.isPrimaryProfession =
                        professionInfo.isPrimaryProfession
                elseif saved.isPrimaryProfession == nil then
                    saved.isPrimaryProfession = slot <= 2
                end

                saved.professionName =
                    name or skillLineName or saved.professionName
                saved.icon = icon or saved.icon
                saved.skillLevel = rank or saved.skillLevel or 0
                saved.maxSkillLevel =
                    maxRank or saved.maxSkillLevel or 0
                saved.skillModifier =
                    rankModifier or saved.skillModifier or 0
                saved.abilities = GetProfessionAbilities(
                    numSpells,
                    spellOffset
                )
                if saved.recipeCacheVersion ~= RECIPE_CACHE_VERSION then
                    saved.recipes = {}
                    saved.recipesCached = false
                    saved.recipeCacheVersion = nil
                else
                    saved.recipes = saved.recipes or {}
                end

                saved.updated = time and time() or 0

                professions[skillLineID] = saved
            end
        end
    end
end

function Module:SnapshotCurrentProfession()
    self:SnapshotProfessionSkills()

    if not C_TradeSkillUI
        or not C_TradeSkillUI.GetBaseProfessionInfo
        or not C_TradeSkillUI.GetChildProfessionInfo
        or not C_TradeSkillUI.GetAllRecipeIDs
        or not C_TradeSkillUI.GetRecipeInfo
    then
        return
    end

    local _, character = GetCurrentCharacterData()
    local professions = EnsureCharacterProfessions(character)

    if not professions then
        return
    end

    local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    local childInfo = C_TradeSkillUI.GetChildProfessionInfo()

    if not baseInfo
        or not baseInfo.professionID
        or baseInfo.professionID == 0
    then
        return
    end

    local professionInfo = childInfo
    if not professionInfo
        or not professionInfo.professionID
        or professionInfo.professionID == 0
    then
        professionInfo = baseInfo
    end

    local professionID = professionInfo.professionID
    local saved = professions[professionID] or {}

    saved.professionID = professionID
    saved.professionEnum =
        professionInfo.profession
        or baseInfo.profession
        or saved.professionEnum

    if professionInfo.isPrimaryProfession ~= nil then
        saved.isPrimaryProfession =
            professionInfo.isPrimaryProfession
    elseif baseInfo.isPrimaryProfession ~= nil then
        saved.isPrimaryProfession =
            baseInfo.isPrimaryProfession
    end

    saved.parentProfessionID =
        professionInfo.parentProfessionID
        or (
            baseInfo.professionID ~= professionID
            and baseInfo.professionID
            or nil
        )
    saved.professionName =
        professionInfo.professionName
        or baseInfo.professionName
        or saved.professionName
    saved.skillLevel =
        professionInfo.skillLevel or saved.skillLevel or 0
    saved.maxSkillLevel =
        professionInfo.maxSkillLevel or saved.maxSkillLevel or 0
    saved.skillModifier =
        professionInfo.skillModifier or saved.skillModifier or 0
    saved.updated = time and time() or 0

    local ok, recipeIDs = pcall(
        C_TradeSkillUI.GetAllRecipeIDs
    )

    if not ok or type(recipeIDs) ~= "table" then
        professions[professionID] = saved
        return
    end

    local discoveredRecipes = {}

    for _, recipeID in ipairs(recipeIDs) do
        local belongsToSkillLine = true

        if C_TradeSkillUI.IsRecipeInSkillLine then
            belongsToSkillLine =
                C_TradeSkillUI.IsRecipeInSkillLine(
                    recipeID,
                    professionID
                )
        end

        if belongsToSkillLine then
            local recipeInfo =
                C_TradeSkillUI.GetRecipeInfo(recipeID)

            if recipeInfo
                and Professions
                and Professions.GetFirstRecipe
            then
                recipeInfo =
                    Professions.GetFirstRecipe(recipeInfo)
            end

            if recipeInfo and recipeInfo.learned then
                local learnedRecipeID =
                    recipeInfo.recipeID or recipeID

                discoveredRecipes[learnedRecipeID] = {
                    name = recipeInfo.name,
                    icon = recipeInfo.icon,
                }
            end
        end
    end

    saved.recipes = discoveredRecipes
    saved.recipesCached = true
    saved.recipeCacheVersion = RECIPE_CACHE_VERSION

    professions[professionID] = saved
end

local function HasCompleteRecipeCache(profession)
    return profession
        and profession.recipesCached == true
        and profession.recipeCacheVersion == RECIPE_CACHE_VERSION
end

local function FindCachedProfession(character, professionInfo)
    if not character or not professionInfo then
        return nil
    end

    local professions = character.professions or {}
    local exact = professions[professionInfo.professionID]

    if exact then
        return exact
    end

    local parentProfessionID = professionInfo.parentProfessionID
    if not parentProfessionID then
        return nil
    end

    local parent = professions[parentProfessionID]
    if parent then
        return parent
    end

    local bestMatch

    for _, profession in pairs(professions) do
        if profession.parentProfessionID == parentProfessionID then
            if not bestMatch
                or (profession.skillLevel or 0)
                    > (bestMatch.skillLevel or 0)
            then
                bestMatch = profession
            end
        end
    end

    return bestMatch
end

local function NormalizeRecipeName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    return string.lower(name)
end

local function GetRecipeNameFromItem(itemID)
    if not itemID
        or not C_Item
        or not C_Item.GetItemNameByID
    then
        return nil
    end

    local itemName = C_Item.GetItemNameByID(itemID)

    if not itemName then
        return nil
    end

    local recipeName = string.match(
        itemName,
        "^[^:]+:%s*(.+)$"
    )

    return recipeName
end

local function IsRecipeLearningItem(itemID)
    if not itemID
        or not TooltipUtil
        or not TooltipUtil.FindLinesFromGetter
        or not Enum.TooltipDataLineType
        or not Enum.TooltipDataLineType.ItemSpellTriggerLearn
    then
        return false
    end

    local lines = TooltipUtil.FindLinesFromGetter(
        { Enum.TooltipDataLineType.ItemSpellTriggerLearn },
        "GetItemByID",
        itemID
    )

    return lines and #lines > 0 or false
end

local function GetRecipeItemInfo(itemID)
    if not itemID
        or not IsRecipeLearningItem(itemID)
    then
        return nil
    end

    return GetRecipeNameFromItem(itemID)
end

local function GetRecipeRequirementInfo(itemID)
    if not TooltipUtil
        or not TooltipUtil.FindLinesFromGetter
        or not Enum.TooltipDataLineType
        or not Enum.TooltipDataUsageRequirementType
    then
        return nil
    end

    local lines = TooltipUtil.FindLinesFromGetter(
        { Enum.TooltipDataLineType.UsageRequirement },
        "GetItemByID",
        itemID
    )

    for _, line in ipairs(lines or {}) do
        if line.requirementType
                == Enum.TooltipDataUsageRequirementType.Skill
            and line.leftText
        then
            local required = string.match(
                line.leftText,
                "(%d+)%D*$"
            )

            return required and tonumber(required) or nil,
                line.leftText
        end
    end
end

local function FindCachedProfessionByRequirement(
    character,
    requirementText
)
    if not character or type(requirementText) ~= "string" then
        return nil
    end

    local requirement =
        string.lower(requirementText)

    for _, profession in pairs(character.professions or {}) do
        local professionName = profession.professionName

        if professionName
            and string.find(
                requirement,
                string.lower(professionName),
                1,
                true
            )
        then
            return profession
        end
    end
end

local function FindCachedRecipeByName(profession, recipeName)
    local normalizedName = NormalizeRecipeName(recipeName)

    if not profession or not normalizedName then
        return nil
    end

    for _, recipe in pairs(profession.recipes or {}) do
        if type(recipe) == "table"
            and NormalizeRecipeName(recipe.name)
                == normalizedName
        then
            return recipe
        end
    end
end

local function JoinCharacterNames(entries)
    local names = {}

    for _, entry in ipairs(entries) do
        names[#names + 1] = entry
    end

    return table.concat(names, ", ")
end

function Module:AddRecipeCharacterTooltip(tooltip, tooltipData)
    local itemID = tooltipData and tooltipData.id

    if not itemID and tooltip and tooltip.GetItem then
        local _, itemLink = tooltip:GetItem()

        if itemLink then
            itemID = C_Item.GetItemInfoInstant(itemLink)
        end
    end

    local recipeName = GetRecipeItemInfo(itemID)

    if not recipeName then
        return
    end

    local characters = GetCharactersModule()
    if not characters then
        return
    end

    local requiredSkill, requirementText =
        GetRecipeRequirementInfo(itemID)
    local known = {}
    local canLearn = {}
    local needsSkill = {}

    for _, entry in ipairs(characters:GetSortedCharacters()) do
        local character = entry.character
        local profession

        if requirementText then
            profession =
                FindCachedProfessionByRequirement(
                    character,
                    requirementText
                )
        end

        if HasCompleteRecipeCache(profession) then
            local name = character.name or "Unknown"
            local skill = profession.skillLevel or 0
            local nameWithSkill = string.format(
                "%s (%d)",
                name,
                skill
            )
            local recipe =
                FindCachedRecipeByName(
                    profession,
                    recipeName
                )

            if recipe then
                known[#known + 1] = nameWithSkill
            else
                if requiredSkill and skill < requiredSkill then
                    needsSkill[#needsSkill + 1] = nameWithSkill
                else
                    canLearn[#canLearn + 1] = nameWithSkill
                end
            end
        end
    end

    if #known == 0
        and #canLearn == 0
        and #needsSkill == 0
    then
        return
    end

    tooltip:AddLine(" ")

    if #known > 0 then
        tooltip:AddLine(
            "Known: " .. JoinCharacterNames(known),
            0.35,
            0.90,
            0.45,
            true
        )
    end

    if #canLearn > 0 then
        tooltip:AddLine(
            "Can learn: " .. JoinCharacterNames(canLearn),
            1.00,
            0.82,
            0.00,
            true
        )
    end

    if #needsSkill > 0 then
        tooltip:AddLine(
            "Higher skill: " .. JoinCharacterNames(needsSkill),
            1.00,
            0.20,
            0.20,
            true
        )
    end
end

function Module:InstallRecipeTooltipHook()
    if self.recipeTooltipHookInstalled
        or not TooltipDataProcessor
        or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum.TooltipDataType
    then
        return
    end

    self.recipeTooltipHookInstalled = true

    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Item,
        function(tooltip, tooltipData)
            Module:AddRecipeCharacterTooltip(
                tooltip,
                tooltipData
            )
        end
    )
end


function Module:GetDatabase()
    return GetDatabase()
end

function Module:GetCharactersModule()
    return GetCharactersModule()
end

function Module:GetCurrentCharacterData()
    return GetCurrentCharacterData()
end

function Module:GetViewedCharacter()
    return GetViewedCharacter()
end

function Module:IsRecipeCacheComplete(profession)
    return HasCompleteRecipeCache(profession)
end

function Module:InitializeData()
    if self.dataInitialized then
        return
    end

    self.dataInitialized = true

    self:InstallRecipeTooltipHook()
    self:SnapshotProfessionSkills()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:InstallRecipeTooltipHook()
        Module:SnapshotProfessionSkills()
    end)

    UI:RegisterEvent("SKILL_LINES_CHANGED", function()
        Module:SnapshotProfessionSkills()

        if Module.RefreshFrame then
            Module:RefreshFrame()
        end
    end)

    for _, event in ipairs({
        "TRADE_SKILL_SHOW",
        "TRADE_SKILL_LIST_UPDATE",
        "NEW_RECIPE_LEARNED",
        "SPELLS_CHANGED",
    }) do
        UI:RegisterEvent(event, function()
            C_Timer.After(0, function()
                Module:SnapshotCurrentProfession()

                if Module.RefreshFrame then
                    Module:RefreshFrame()
                end
            end)
        end)
    end
end

Module:InitializeData()
