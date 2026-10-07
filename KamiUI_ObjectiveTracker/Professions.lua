local UI = KamiUI
local Module = UI:GetModule("ObjectiveTracker")

if not Module then
    return
end

local Provider = {
    order = 20,
}

local function GetItemCount(itemID)
    if not itemID then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(
            itemID,
            false,
            false,
            true
        ) or 0
    end

    if _G.GetItemCount then
        return _G.GetItemCount(
            itemID,
            false,
            false,
            true
        ) or 0
    end

    return 0
end

local function GetCurrencyCount(currencyID)
    if not currencyID
        or not C_CurrencyInfo
        or not C_CurrencyInfo.GetCurrencyInfo
    then
        return 0
    end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    return info and info.quantity or 0
end

local function GetReagentName(reagent, slot)
    local itemID = reagent and reagent.itemID

    if itemID then
        if GetItemInfo then
            local name = GetItemInfo(itemID)

            if name then
                return name
            end
        end

        if C_Item and C_Item.GetItemNameByID then
            local name = C_Item.GetItemNameByID(itemID)

            if name then
                return name
            end
        end

        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end

        return "Item " .. tostring(itemID)
    end

    if reagent
        and reagent.currencyID
        and C_CurrencyInfo
        and C_CurrencyInfo.GetCurrencyInfo
    then
        local info =
            C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)

        if info and info.name then
            return info.name
        end
    end

    return slot
        and slot.slotInfo
        and slot.slotInfo.slotText
        or "Reagent"
end

local function GetRequiredQuantity(slot, reagent)
    if slot
        and slot.GetQuantityRequired
    then
        local ok, quantity = pcall(
            slot.GetQuantityRequired,
            slot,
            reagent
        )

        if ok and quantity then
            return tonumber(quantity) or 0
        end
    end

    return tonumber(
        slot and slot.quantityRequired
        or reagent and reagent.quantityRequired
        or 0
    ) or 0
end

local function GetOwnedQuantity(slot)
    local reagents = slot and slot.reagents or {}

    if ProfessionsUtil
        and ProfessionsUtil.AccumulateReagentsInPossession
    then
        local quantity = UI:SafeCall(
            ProfessionsUtil.AccumulateReagentsInPossession,
            reagents
        )

        if quantity ~= nil then
            return tonumber(quantity) or 0
        end
    end

    local quantity = 0

    for _, reagent in ipairs(reagents) do
        if reagent.itemID then
            quantity = quantity + GetItemCount(reagent.itemID)
        elseif reagent.currencyID then
            quantity = quantity
                + GetCurrencyCount(reagent.currencyID)
        end
    end

    return quantity
end

local function FormatReagentText(owned, required, name)
    local countText

    if PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT then
        countText =
            PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(
                owned,
                required
            )
    else
        countText = string.format("%d/%d", owned, required)
    end

    if PROFESSIONS_TRACKER_REAGENT_FORMAT then
        return PROFESSIONS_TRACKER_REAGENT_FORMAT:format(
            countText,
            name
        )
    end

    return countText .. " " .. name
end

local function GetRecipeData(recipeID, isRecraft)
    local schematic =
        C_TradeSkillUI
        and C_TradeSkillUI.GetRecipeSchematic
        and UI:SafeCall(
            C_TradeSkillUI.GetRecipeSchematic,
            recipeID,
            isRecraft
        )
        or nil

    local info =
        C_TradeSkillUI
        and C_TradeSkillUI.GetRecipeInfo
        and UI:SafeCall(
            C_TradeSkillUI.GetRecipeInfo,
            recipeID
        )
        or nil

    local name =
        schematic and schematic.name
        or info and info.name
        or ("Recipe " .. tostring(recipeID))

    if isRecraft then
        if PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER then
            name =
                PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(
                    name
                )
        else
            name = name .. " (Recraft)"
        end
    end

    local objectives = {}

    for _, slot in ipairs(
        schematic and schematic.reagentSlotSchematics or {}
    ) do
        if slot.required ~= false
            and not slot.hiddenInCraftingForm
            and slot.reagents
            and #slot.reagents > 0
        then
            local reagent = slot.reagents[1]
            local required =
                GetRequiredQuantity(slot, reagent)
            local owned = GetOwnedQuantity(slot)
            local reagentName =
                GetReagentName(reagent, slot)

            if required > 0 then
                objectives[#objectives + 1] = {
                    text = FormatReagentText(
                        owned,
                        required,
                        reagentName
                    ),
                    finished = owned >= required,
                }
            end
        end
    end

    return {
        title = name,
        objectives = objectives,
        showQuestControls = false,
        objectiveIndent = 14,
        recipeID = recipeID,
        isRecraft = isRecraft,
    }
end

local function AppendTrackedRecipes(items, isRecraft)
    if not C_TradeSkillUI
        or not C_TradeSkillUI.GetRecipesTracked
    then
        return
    end

    local recipeIDs = UI:SafeCall(
        C_TradeSkillUI.GetRecipesTracked,
        isRecraft
    ) or {}

    for _, recipeID in ipairs(recipeIDs) do
        items[#items + 1] =
            GetRecipeData(recipeID, isRecraft)
    end
end

function Provider:GetSection()
    local items = {}

    AppendTrackedRecipes(items, false)
    AppendTrackedRecipes(items, true)

    table.sort(items, function(left, right)
        return (left.title or "") < (right.title or "")
    end)

    return {
        title =
            PROFESSIONS_TRACKER_HEADER_PROFESSION
            or PROFESSIONS
            or "Professions",
        items = items,
    }
end

Module:RegisterProvider("professions", Provider)

if C_TradeSkillUI
    and C_TradeSkillUI.GetRecipesTracked
then
    local refreshPending = false

    local function ScheduleRefresh()
        if refreshPending then
            return
        end

        refreshPending = true

        C_Timer.After(0, function()
            refreshPending = false
            Module:Refresh()
        end)
    end

    for _, event in ipairs({
        "TRACKED_RECIPE_UPDATE",
        "BAG_UPDATE_DELAYED",
        "CURRENCY_DISPLAY_UPDATE",
        "GET_ITEM_INFO_RECEIVED",
    }) do
        UI:RegisterEvent(event, ScheduleRefresh)
    end
end
