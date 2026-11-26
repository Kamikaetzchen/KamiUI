local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
local Module = UI:NewModule("Account", "KamiUI_Account")

local INSET = Styles.Metrics.windowContentInset
local CONTENT_TOP = 32 + 1 + Styles.Metrics.windowContentGap
local WIDTH = 540
local HEIGHT = 530
local SLOT_SIZE = 36
local SLOT_GAP = 3
local GRID_COLUMNS = 12
local GRID_ROWS = 9
local ROW_HEIGHT = 39
local CHARACTER_ROWS = 10
local MAX_LEVEL = 60
local XP_BAR_HEIGHT = 3
local XP_BAR_BOTTOM = 2
local PROFESSION_VERTICAL_GAP = 2

local function GetDatabase()
    return UI:GetDatabase("account", {})
end

local function GetBagCharacters()
    local bags = KamiUIDB and KamiUIDB.bags
    return bags and bags.characters or {}
end

local function GetCharacterEntries()
    local byKey = {}
    local characters = UI:GetCharactersModule()
    if characters and characters.GetSortedCharacters then
        for _, entry in ipairs(characters:GetSortedCharacters()) do
            byKey[entry.key] = entry.character
        end
    end
    for key, data in pairs(GetBagCharacters()) do
        if not byKey[key] then
            byKey[key] = UI:GetCharacterProfile(key, data)
        end
    end

    local entries = {}
    for key, profile in pairs(byKey) do
        entries[#entries + 1] = {
            key = key,
            character = profile or {},
        }
    end
    return UI:SortCharacterEntries(entries)
end

local function ItemID(data)
    if not data then return nil end
    if data.itemID then return tonumber(data.itemID) end
    if type(data.link) == "string" then
        return tonumber(string.match(data.link, "item:(%d+)"))
    end
    return nil
end

-- Inventory and equipped bags use separate caches. Equipment is read
-- directly from the Characters module to avoid duplicating its snapshots.
local function BuildItems()
    local items = {}
    local bagCharacters = GetBagCharacters()
    local profiles = GetCharacterEntries()

    local function Add(slot, location)
        local id = ItemID(slot)
        if not id then return end

        local item = items[id]
        if not item then
            item = {
                id = id,
                link = slot.link,
                name = slot.name,
                icon = slot.icon,
                quality = slot.quality,
                count = 0,
                bags = 0,
                bank = 0,
                equipped = 0,
            }
            items[id] = item
        end

        if slot.link and not item.link then item.link = slot.link end
        if slot.icon and not item.icon then item.icon = slot.icon end
        if slot.name and not item.name then item.name = slot.name end
        if slot.quality and not item.quality then item.quality = slot.quality end

        local count = slot.count or 1
        if count <= 0 then return end
        item.count = item.count + count
        item[location] = item[location] + count
    end

    for _, entry in ipairs(profiles) do
        local cached = bagCharacters[entry.key] or {}
        local profile = entry.character or {}

        for _, bag in ipairs(cached.bags or {}) do
            for _, slot in pairs(bag.slots or {}) do
                Add(slot, "bags")
            end
        end

        for _, tab in ipairs(cached.bank and cached.bank.tabs or {}) do
            for _, slot in pairs(tab.slots or {}) do
                Add(slot, "bank")
            end
        end

        for _, slot in ipairs(cached.equippedBags or {}) do
            Add(slot, "equipped")
        end

        for _, slot in ipairs(
            cached.bank and cached.bank.equippedBags or {}
        ) do
            Add(slot, "bank")
        end

        for _, slot in pairs(profile.equipment or {}) do
            Add(slot, "equipped")
        end
    end

    local result = {}
    for id, item in pairs(items) do
        if GetItemInfo then
            local name, _, quality, _, _, _, _, _, _, icon =
                GetItemInfo(item.link or id)
            if name then item.name = name end
            if quality ~= nil then item.quality = quality end
            if icon then item.icon = icon end
        end
        if not item.icon then
            if C_Item and C_Item.GetItemIconByID then
                item.icon = C_Item.GetItemIconByID(id)
            elseif GetItemIcon then
                item.icon = GetItemIcon(id)
            end
        end
        -- GetItemInfo is not guaranteed to have cached every alt's item
        -- yet. Saved hyperlinks still contain the display name, which must
        -- remain searchable while the item cache populates.
        local linkName = type(item.link) == "string"
            and string.match(item.link, "|h%[([^%]]+)%]|h")
        item.name = item.name or linkName or tostring(id)
        result[#result + 1] = item
    end

    table.sort(result, function(a, b)
        local an, bn = string.lower(a.name), string.lower(b.name)
        if an == bn then return a.id < b.id end
        return an < bn
    end)
    return result
end

local function MatchesSearch(item, search)
    search = string.lower(string.match(search or "", "^%s*(.-)%s*$"))
    if search == "" then return true end

    -- Location searches are intentionally distinct from the item's
    -- class/subclass name search. 'bag' still finds bag-type items.
    if search == "equipped" or search == "location:equipped" then
        return item.equipped > 0
    elseif search == "location:bank" then
        return item.bank > 0
    elseif search == "location:bags" then
        return item.bags > 0
    end

    return Components:ItemMatchesSearch(
        item.name,
        item.link or item.id,
        search
    )
end

local function CreateLabel(parent, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "OUTLINE")
    local c = color or Palette.text
    label:SetTextColor(c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1)
    return label
end

local function SetClassColor(text, classFile)
    local c = classFile and Palette:GetClassColor(classFile)
    if c then
        text:SetTextColor(c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1)
    else
        text:SetTextColor(0.93, 0.93, 0.93)
    end
end

local PROFESSION_X = 293
local PROFESSION_WIDTH = 112
-- Row height excludes the one-pixel gap between adjacent rows.
local PROFESSION_ICON_SIZE = ROW_HEIGHT - 1 - XP_BAR_BOTTOM
    - XP_BAR_HEIGHT - 2 * PROFESSION_VERTICAL_GAP
local CHARACTER_COLUMNS = {
    { key = "name", label = "Character", x = 3, width = 174 },
    { key = "level", label = "Level", x = 180, width = 53 },
    { key = "xp", label = "XP", x = 236, width = 54 },
    { key = "professions", label = "Professions", x = PROFESSION_X,
        width = PROFESSION_WIDTH, sortable = false },
    { key = "gold", label = "Gold", x = 409,
        width = WIDTH - 2 * INSET - 409 - 3 },
}

local function IsPrimaryProfession(profession, id)
    if id == 129 or id == 185 or id == 356 or id == 794 then
        return false
    end
    if profession.professionSlot then
        return profession.professionSlot <= 2
    end
    return profession.isPrimaryProfession == true
end

-- Use the existing character snapshot. A base skill and its recipe-bearing
-- child skill are one profession, not two icons.
local function GetRowProfessions(character)
    local saved = character.professions or {}
    local groups = {}
    local professions = UI:GetModule("Professions")
    for key, profession in pairs(saved) do
        local id = profession.parentProfessionID or profession.professionID
            or key
        local display = saved[id] or profession
        if display.professionName and
            (id == 185 or IsPrimaryProfession(display, id)) then
            local group = groups[id]
            if not group then
                group = { id = id, display = display, target = display }
                groups[id] = group
            end

            local complete = professions and professions.IsRecipeCacheComplete
                and professions:IsRecipeCacheComplete(profession)
                or profession.recipesCached == true
            local targetComplete = professions
                and professions.IsRecipeCacheComplete
                and professions:IsRecipeCacheComplete(group.target)
                or group.target.recipesCached == true
            if complete and (not targetComplete
                or (profession.updated or 0) > (group.target.updated or 0)) then
                group.target = profession
            end
            if not saved[id] and (profession.updated or 0)
                > (group.display.updated or 0) then
                group.display = profession
            end
        end
    end

    local primary = {}
    for id, group in pairs(groups) do
        if id ~= 185 then primary[#primary + 1] = group end
    end
    table.sort(primary, function(a, b)
        local left = a.display.professionSlot or 99
        local right = b.display.professionSlot or 99
        if left ~= right then return left < right end
        if a.display.professionName ~= b.display.professionName then
            return a.display.professionName < b.display.professionName
        end
        return tostring(a.id) < tostring(b.id)
    end)
    return { [1] = primary[1], [2] = primary[2], [3] = groups[185] }
end

local function RenderRowProfessions(row, character)
    local entries = GetRowProfessions(character)
    for index, button in ipairs(row.professionButtons) do
        local entry = entries[index]
        button.profession = entry
        if entry then
            local profession = entry.display
            button.icon:SetTexture(profession.icon or entry.target.icon
                or "Interface\\Icons\\INV_Misc_QuestionMark")
            local rank = button.rank
            rank:SetText(string.format("%s/%s",
                tostring(profession.skillLevel or "?"),
                tostring(profession.maxSkillLevel or "?")))
            -- Start at eight pixels and fit wider values such as 300/300.
            local font = "Fonts\\FRIZQT__.TTF"
            for size = 8, 6, -1 do
                rank:SetFont(font, size, "OUTLINE")
                if rank:GetStringWidth() <= PROFESSION_ICON_SIZE - 4 then
                    break
                end
            end
            button:Show()
        else
            if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
            button:Hide()
        end
    end
end

local function CreateProfessionButton(row, index)
    local button = Components:CreateItemSlot(row, {
        size = PROFESSION_ICON_SIZE,
        metallic = true,
        rarityGlow = false,
        count = false,
        highlight = true,
    })
    local cellWidth = PROFESSION_WIDTH / 3
    button:SetPoint("TOPLEFT", row, "TOPLEFT",
        PROFESSION_X + (index - 1) * cellWidth
            + (cellWidth - PROFESSION_ICON_SIZE) / 2,
        -PROFESSION_VERTICAL_GAP)
    button:SetFrameLevel(row:GetFrameLevel() + 2)
    button:RegisterForClicks("LeftButtonUp")

    -- Place the skill label over the icon, like an item stack count.
    local rank = CreateLabel(button, 8)
    rank:SetDrawLayer("OVERLAY", 7)
    rank:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
    rank:SetJustifyH("CENTER")
    rank:SetTextColor(1, 1, 1)
    button.rank = rank

    button:SetScript("OnEnter", function(self)
        local entry = self.profession
        if not entry then return end
        local profession = entry.display
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText(profession.professionName)
        GameTooltip:AddLine(string.format("Skill: %s / %s",
            tostring(profession.skillLevel or "?"),
            tostring(profession.maxSkillLevel or "?")), 1, 1, 1)
        local module = UI:GetModule("Professions")
        if module and module.OpenProfession then
            GameTooltip:AddLine("Click to open profession", 0.7, 0.85, 0.7)
        else
            GameTooltip:AddLine("Professions addon unavailable", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button:SetScript("OnHide", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button:SetScript("OnClick", function(self)
        local entry = self.profession
        local module = UI:GetModule("Professions")
        if not entry or not row.entryKey or not module
            or not module.SetViewedCharacter or not module.ShowFrame
            or not module.OpenProfession then return end
        GameTooltip:Hide()
        module:SetViewedCharacter(row.entryKey)
        module:ShowFrame()
        module:OpenProfession(entry.target)
        if module.frame and module.frame.Raise then
            module.frame:Raise()
        end
    end)
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", function(_, delta)
        local pane = row:GetParent()
        local scroll = pane:GetScript("OnMouseWheel")
        if scroll then scroll(pane, delta) end
    end)
    button:Hide()
    return button
end

local function GetXPPercent(profile)
    local level = tonumber(profile.level)
    local xp = tonumber(profile.xp)
    local xpMax = tonumber(profile.xpMax)
    if not level or level <= 0 or level >= MAX_LEVEL
        or not xp or not xpMax or xpMax <= 0 then
        return nil
    end
    return math.max(0, math.min(100, xp / xpMax * 100))
end

local function GetRestedPercent(key, profile)
    local level = tonumber(profile.level)
    local maxXP = tonumber(profile.xpMax)
    if not level or level >= MAX_LEVEL or not maxXP or maxXP <= 0 then
        return nil
    end

    -- InfoPanel owns the offline rested-XP model and snapshots.
    if UI.RestedXP and UI.RestedXP.GetCharacterPercent then
        return UI.RestedXP:GetCharacterPercent(key, level, maxXP)
    end

    -- Keep live XP functional if the optional InfoPanel is disabled.
    if key == UI:GetCurrentCharacterKey() and GetXPExhaustion then
        local rested = UI:SafeCall(GetXPExhaustion)
        if UI:CanAccessValue(rested) then
            if rested == nil then rested = 0 end
            if type(rested) == "number" then
                return math.max(0, rested) / maxXP * 100, false
            end
        end
    end
    return nil
end

local function ShowXPTooltip(row)
    if not row.xpBar:IsShown() or not row.xpCurrent
        or not row.xpMaximum then
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:SetText("Experience", 1, 0.82, 0)
    local text = string.format(
        "%s/%s (%.1f%%)",
        UI:FormatNumber(row.xpCurrent),
        UI:FormatNumber(row.xpMaximum),
        row.xpCurrent / row.xpMaximum * 100
    )
    if row.restedPercent and row.restedPercent > 0 then
        text = string.format("%s (+%.1f%% rested, %s XP)", text,
            row.restedPercent,
            UI:FormatNumber(math.floor(
                row.xpMaximum * row.restedPercent / 100 + 0.5)))
    end
    GameTooltip:AddLine(text, 1, 1, 1)
    if row.restedEstimated then
        GameTooltip:AddLine("Rested XP is estimated while offline.",
            0.65, 0.69, 0.76)
    elseif row.restedPercent == nil then
        GameTooltip:AddLine("Rested XP unavailable.", 0.65, 0.69, 0.76)
    end
    GameTooltip:Show()
end

local function HideXPTooltip(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function SortCharacterEntries(entries, pane)
    local key = pane.sortKey or "level"
    local ascending = pane.sortAscending == true
    local currentKey = UI:GetCurrentCharacterKey()

    table.sort(entries, function(left, right)
        local a = left.character or {}
        local b = right.character or {}
        local aBank = UI:IsBankCharacter(a, left.key)
        local bBank = UI:IsBankCharacter(b, right.key)

        -- Keep bank alts below regular characters for every sort column.
        if aBank ~= bBank then
            return not aBank
        end

        local av, bv

        if key == "name" then
            av = string.lower(a.name or select(2, UI:ParseCharacterKey(left.key)))
            bv = string.lower(b.name or select(2, UI:ParseCharacterKey(right.key)))
        elseif key == "xp" then
            av = GetXPPercent(a) or -1
            bv = GetXPPercent(b) or -1
        elseif key == "gold" then
            av = tonumber(a.money) or 0
            bv = tonumber(b.money) or 0
        else
            av = tonumber(a.level) or 0
            bv = tonumber(b.level) or 0
        end

        if av ~= bv then
            if ascending then return av < bv end
            return av > bv
        end

        -- Deterministic ordering for equal values.
        if left.key == currentKey then return true end
        if right.key == currentKey then return false end
        return left.key < right.key
    end)
end

local function RenderCharacters()
    local frame = Module.frame
    if not frame then return end

    local pane = frame.charactersPane
    local entries = GetCharacterEntries()
    SortCharacterEntries(entries, pane)

    local maxOffset = math.max(0, #entries - CHARACTER_ROWS)
    pane.offset = math.min(maxOffset, math.max(0, pane.offset or 0))
    local totalGold = 0
    for _, entry in ipairs(entries) do
        totalGold = totalGold + (tonumber(entry.character
            and entry.character.money) or 0)
    end
    pane.count:SetText(
        #entries .. " characters  |  Total: "
        .. UI:FormatMoney(totalGold, { iconSize = 11 })
    )

    for _, heading in ipairs(pane.headings) do
        local active = heading.sortKey == pane.sortKey
        local arrow = active and (pane.sortAscending and " ^" or " v") or ""
        heading:SetText(heading.label .. arrow)
    end

    for index, row in ipairs(pane.rows) do
        local entry = entries[pane.offset + index]
        if entry then
            local profile = entry.character or {}
            row.entryKey = entry.key
            row.name:SetText(
                profile.name or select(2, UI:ParseCharacterKey(entry.key))
            )
            SetClassColor(row.name, profile.classFile)
            RenderRowProfessions(row, profile)

            local level = tonumber(profile.level)
            row.level:SetText(
                level and level > 0 and tostring(level) or "-"
            )
            local xpPercent = GetXPPercent(profile)
            row.xp:SetText(
                xpPercent and string.format("%.0f%%", xpPercent) or "-"
            )
            -- Offline characters use their last recorded XP snapshot.
            -- A missing snapshot is unknown, not zero progress.
            row.xpBar:SetShown(xpPercent ~= nil)
            row.xpBar:SetValue(xpPercent or 0)
            row.xpCurrent = xpPercent and tonumber(profile.xp) or nil
            row.xpMaximum = xpPercent and tonumber(profile.xpMax) or nil
            row.restedPercent, row.restedEstimated = nil, nil
            if xpPercent ~= nil then
                row.restedPercent, row.restedEstimated =
                    GetRestedPercent(entry.key, profile)
            end
            row.restedBar:SetShown(xpPercent ~= nil)
            row.restedBar:SetValue(math.min(100,
                (xpPercent or 0) + (row.restedPercent or 0)))
            row.money:SetText(
                UI:FormatMoney(profile.money or 0, { iconSize = 12 })
            )
            row:Show()
            if GameTooltip:IsOwned(row) then ShowXPTooltip(row) end
        else
            row.entryKey = nil
            row.xpCurrent, row.xpMaximum = nil, nil
            row.restedPercent, row.restedEstimated = nil, nil
            HideXPTooltip(row)
            row.xpBar:Hide()
            row.restedBar:Hide()
            RenderRowProfessions(row, {})
            row:Hide()
        end
    end

    pane.pageLabel:SetText(
        #entries == 0 and "No characters recorded"
        or (math.min(#entries, pane.offset + 1)
            .. "-" .. math.min(#entries, pane.offset + CHARACTER_ROWS)
            .. " of " .. #entries)
    )
end

local function RenderItems()
    local frame = Module.frame
    if not frame then return end
    local pane = frame.itemsPane
    local matches = {}

    for _, item in ipairs(Module.allItems or {}) do
        if MatchesSearch(item, pane.search:GetText()) then
            matches[#matches + 1] = item
        end
    end

    local maxRow = math.max(0, math.ceil(#matches / GRID_COLUMNS) - GRID_ROWS)
    pane.firstRow = math.min(maxRow, math.max(0, pane.firstRow or 0))
    local start = pane.firstRow * GRID_COLUMNS

    for index, button in ipairs(pane.buttons) do
        local item = matches[start + index]
        if item then
            Components:SetItemSlotData(button, {
                itemID = item.id,
                link = item.link,
                icon = item.icon,
                quality = item.quality,
                count = item.count,
            })
            button:Show()
        else
            button:Hide()
        end
    end

    pane.matchCount:SetText(#matches .. " / " .. #(Module.allItems or {}) .. " items")
    if #matches == 0 then
        pane.pageLabel:SetText("No matching items")
    else
        pane.pageLabel:SetText(
            (start + 1) .. "-" .. math.min(#matches, start + #pane.buttons)
            .. " of " .. #matches
        )
    end
end

function Module:Refresh()
    if not self.frame then return end
    self.allItems = BuildItems()
    RenderCharacters()
    RenderItems()
end

function Module:SetPage(page)
    if not self.frame then return end
    if page ~= "characters" and page ~= "items" then return end

    self.frame.page = page
    self.frame.charactersPane:SetShown(page == "characters")
    self.frame.itemsPane:SetShown(page == "items")
    for _, tab in ipairs(self.frame.tabs) do
        Components:SetTabState(tab, tab.page == page, true)
    end
    if page == "characters" then
        RenderCharacters()
    else
        RenderItems()
    end
end

function Module:Show()
    if not self.frame then return end
    local bags = UI:GetModule("Bags")
    if bags and bags.SaveCurrentCharacter then
        bags:SaveCurrentCharacter()
    end
    local characters = UI:GetCharactersModule()
    if characters and characters.Refresh then
        characters:Refresh()
    end
    local professions = UI:GetModule("Professions")
    if professions and professions.SnapshotProfessionSkills then
        professions:SnapshotProfessionSkills()
    end
    self:Refresh()
    self.frame:Show()
end

function Module:Hide()
    if self.frame then self.frame:Hide() end
end

function Module:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self:Hide() else self:Show() end
end

local function CreateCharactersPane(frame)
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, -CONTENT_TOP)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, 35)
    pane.rows = {}
    pane.headings = {}
    pane.offset = 0
    pane.sortKey = "level"
    pane.sortAscending = false
    frame.charactersPane = pane

    local count = CreateLabel(pane, 10, Palette.muted)
    count:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -3, -1)
    pane.count = count

    -- A proper sortable table: click a column to sort ascending or
    -- descending. No row data is duplicated; only the view order changes.
    for _, column in ipairs(CHARACTER_COLUMNS) do
        local heading = CreateFrame("Button", nil, pane)
        heading:SetSize(column.width, 23)
        heading:SetPoint("TOPLEFT", pane, "TOPLEFT", column.x, -15)
        heading.label = column.label
        heading.sortKey = column.sortable ~= false and column.key or nil
        heading:SetNormalFontObject("GameFontNormalSmall")
        heading:SetHighlightFontObject("GameFontHighlightSmall")
        local headingText = heading:GetFontString()
        if headingText then
            headingText:SetJustifyH(
                column.key == "gold" and "RIGHT"
                    or column.key == "professions" and "CENTER" or "LEFT"
            )
        end

        local h = heading:CreateTexture(nil, "HIGHLIGHT")
        h:SetAllPoints()
        h:SetColorTexture(1, 1, 1, 0.08)
        heading:SetScript("OnClick", function(self)
            if pane.sortKey == self.sortKey then
                pane.sortAscending = not pane.sortAscending
            else
                pane.sortKey = self.sortKey
                pane.sortAscending = self.sortKey == "name"
            end
            pane.offset = 0
            RenderCharacters()
        end)
        if column.sortable == false then
            heading:EnableMouse(false)
        end
        pane.headings[#pane.headings + 1] = heading
    end

    local separator = pane:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.35, 0.35, 0.6)
    separator:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -40)
    separator:SetPoint("TOPRIGHT", pane, "TOPRIGHT", 0, -40)
    separator:SetHeight(1)

    for i = 1, CHARACTER_ROWS do
        local row = CreateFrame("Button", nil, pane)
        row:SetPoint("TOPLEFT", pane, "TOPLEFT",
            0, -43 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", pane, "TOPRIGHT",
            0, -43 - (i - 1) * ROW_HEIGHT)
        row:SetHeight(ROW_HEIGHT - 1)

        row.name = CreateLabel(row, 11)
        row.level = CreateLabel(row, 10)
        row.xp = CreateLabel(row, 10)
        row.money = CreateLabel(row, 10)

        for _, column in ipairs(CHARACTER_COLUMNS) do
            local field = column.key == "gold"
                and row.money or row[column.key]
            if field then
                field:SetPoint(
                    column.key == "gold" and "RIGHT" or "LEFT",
                    row, "LEFT",
                    column.x + (column.key == "gold" and column.width or 0),
                    (XP_BAR_BOTTOM + XP_BAR_HEIGHT) / 2
                )
                field:SetWidth(column.width - 4)
                field:SetJustifyH(
                    column.key == "gold" and "RIGHT" or "LEFT"
                )
                if field.SetMaxLines then field:SetMaxLines(1) end
            end
        end

        row.professionButtons = {}
        for index = 1, 3 do
            row.professionButtons[index] = CreateProfessionButton(row, index)
        end

        -- Use the XPBar module's colors without requiring that addon.
        -- Full-width bar below the icons and the overlaid skill labels.
        local restedBar = CreateFrame("StatusBar", nil, row)
        restedBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, XP_BAR_BOTTOM)
        restedBar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT",
            -3, XP_BAR_BOTTOM)
        restedBar:SetHeight(XP_BAR_HEIGHT)
        restedBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        restedBar:SetStatusBarColor(unpack(Palette.xpBar.rested))
        restedBar:SetMinMaxValues(0, 100)
        restedBar:SetValue(0)
        restedBar:EnableMouse(false)

        local background = restedBar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(unpack(Palette.xpBar.background))

        local xpBar = CreateFrame("StatusBar", nil, row)
        xpBar:SetAllPoints(restedBar)
        xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        xpBar:SetStatusBarColor(unpack(Palette.xpBar.experience))
        xpBar:SetFrameLevel(restedBar:GetFrameLevel() + 1)
        xpBar:SetMinMaxValues(0, 100)
        xpBar:SetValue(0)
        xpBar:EnableMouse(false)
        xpBar:Hide()
        restedBar:Hide()
        row.xpBar = xpBar
        row.restedBar = restedBar

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetColorTexture(1, 1, 1, 0.06)

        -- The bar is non-interactive so the entire row stays clickable.
        -- Hovering the row, including its XP bar, shows exact XP values.
        row:SetScript("OnEnter", ShowXPTooltip)
        row:SetScript("OnLeave", HideXPTooltip)
        row:SetScript("OnHide", HideXPTooltip)
        row:SetScript("OnClick", function(self)
            if not self.entryKey then return end
            local characters = UI:GetCharactersModule()
            if characters and characters.Show then
                characters:Show()
                characters:SetViewedCharacter(self.entryKey)
            end
        end)
        pane.rows[i] = row
    end

    pane:EnableMouseWheel(true)
    pane:SetScript("OnMouseWheel", function(_, delta)
        pane.offset = math.max(0, pane.offset - delta * 2)
        RenderCharacters()
    end)

    local pageLabel = CreateLabel(pane, 10, Palette.muted)
    pageLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)
    pane.pageLabel = pageLabel
    return pane
end

local function CreateItemsPane(frame)
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetAllPoints(frame)
    pane.buttons = {}
    pane.firstRow = 0
    frame.itemsPane = pane

    local search = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", pane, "TOPLEFT", INSET, -CONTENT_TOP)
    search:SetSize(370, 23)
    search:SetAutoFocus(false)
    search:SetTextInsets(7, 7, 0, 0)
    if search.SetPropagateKeyboardInput then
        search:SetPropagateKeyboardInput(false)
    end
    Components:StyleInput(search)
    pane.search = search

    local hint = CreateLabel(pane, 10, Palette.muted)
    hint:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0,
        -Styles.Metrics.windowContentGap)
    hint:SetText("Search by name, type, subclass or 'equipped'")

    local matchCount = CreateLabel(pane, 10, Palette.muted)
    matchCount:SetPoint("RIGHT", pane, "TOPRIGHT", -INSET,
        -CONTENT_TOP - 12)
    pane.matchCount = matchCount

    for row = 1, GRID_ROWS do
        for column = 1, GRID_COLUMNS do
            local button = Components:CreateItemDisplayButton(pane, {
                size = SLOT_SIZE,
                metallic = true,
            })
            button:SetPoint(
                "TOPLEFT", pane, "TOPLEFT",
                INSET + (column - 1) * (SLOT_SIZE + SLOT_GAP),
                -CONTENT_TOP - 60 - (row - 1) * (SLOT_SIZE + SLOT_GAP)
            )
            button:Hide()
            pane.buttons[#pane.buttons + 1] = button
        end
    end

    search:SetScript("OnTextChanged", function()
        pane.firstRow = 0
        RenderItems()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        RenderItems()
    end)

    pane:EnableMouseWheel(true)
    pane:SetScript("OnMouseWheel", function(_, delta)
        pane.firstRow = math.max(0, pane.firstRow - delta * 2)
        RenderItems()
    end)

    local pageLabel = CreateLabel(pane, 10, Palette.muted)
    pageLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)
    pane.pageLabel = pageLabel
    return pane
end

local function CreateAccountFrame()
    local frame, header = Components:CreateWindow("KamiUIAccountFrame", {
        metallic = true,
        width = WIDTH,
        height = HEIGHT,
        backgroundColor = Palette.window.neutral,
        borderColor = Palette.border,
        header = {
            height = 32,
            title = "Account",
        },
        onDragStop = function(target)
            UI:SaveFramePosition(target, GetDatabase())
        end,
    })
    Module.frame = frame
    local close = Components:CreateHeaderCloseButton(header, {
        metallic = true,
        clicks = { "LeftButtonUp" },
        onClick = function() Module:Hide() end,
    })
    frame.close = close

    CreateCharactersPane(frame)
    CreateItemsPane(frame)

    frame.tabs = {}
    for index, definition in ipairs({
        { label = "Characters", page = "characters" },
        { label = "Items", page = "items" },
    }) do
        local tab = Components:CreateTab(frame, {
            metallic = true,
            width = 100,
            height = 22,
            text = definition.label,
            orientation = "bottom",
            joinLeft = index > 1,
        })
        tab:SetPoint(
            "TOPLEFT", frame, "BOTTOMLEFT",
            INSET + (index - 1) * 100, 1
        )
        tab.page = definition.page
        tab:SetScript("OnClick", function(self)
            Module:SetPage(self.page)
        end)
        frame.tabs[#frame.tabs + 1] = tab
    end

    frame:SetScript("OnShow", function()
        Module:Refresh()
    end)
    Components:RegisterEscapeClose(frame)
    UI:ApplyFramePosition(frame, GetDatabase(), "position", 0, 0)
    Module:SetPage("characters")
    return frame
end

local function QueueRefresh()
    if not Module.frame or not Module.frame:IsShown() then return end
    if Module.refreshQueued then return end
    Module.refreshQueued = true
    C_Timer.After(0.25, function()
        Module.refreshQueued = false
        if Module.frame and Module.frame:IsShown() then
            Module:Refresh()
        end
    end)
end

-- Forever's XML loader does not accept the attributes from Bindings.xml.
-- Bind a normal click action instead: the button is a plain, named UI
-- button, and the saved key can be changed without a binding XML file.
local ACCOUNT_CLICK_ACTION = "CLICK KamiUIAccountHotkeyButton:LeftButton"
local LEGACY_BINDING_ACTION = "KAMIUIACCOUNTTOGGLE"

-- The saved initialization flag is not reliable: key bindings may be
-- reset independently of SavedVariables. Check the actual binding on every
-- login/reload and only restore it when the desired key is available.
local function EnsureAccountHotkey()
    if not GetBindingKey or not GetBindingAction or not SetBinding then
        return
    end

    -- Preserve an existing custom binding instead of forcing backslash.
    if GetBindingKey(ACCOUNT_CLICK_ACTION) then
        return
    end

    -- Preserve keys previously assigned to the old XML binding, when any.
    local oldKey = GetBindingKey(LEGACY_BINDING_ACTION)
    local key = oldKey or "\\"
    local action = GetBindingAction(key)

    if action ~= nil and action ~= ""
        and action ~= LEGACY_BINDING_ACTION
        and action ~= ACCOUNT_CLICK_ACTION
    then
        -- Never replace another action assigned to the key.
        return
    end

    local success
    if SetBindingClick then
        success = SetBindingClick(
            key, "KamiUIAccountHotkeyButton", "LeftButton"
        )
    else
        success = SetBinding(key, ACCOUNT_CLICK_ACTION)
    end

    if success and SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end
end


function Module:Initialize()
    GetDatabase()
    CreateAccountFrame()
    self:Refresh()

    local hotkeyButton = CreateFrame(
        "Button", "KamiUIAccountHotkeyButton", UIParent
    )
    hotkeyButton:RegisterForClicks("LeftButtonUp")
    hotkeyButton:SetScript("OnClick", function()
        Module:Toggle()
    end)
    self.hotkeyButton = hotkeyButton

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", EnsureAccountHotkey)

    UI:RegisterEvent("BAG_UPDATE_DELAYED", QueueRefresh)
    UI:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", QueueRefresh)
    UI:RegisterEvent("PLAYER_MONEY", QueueRefresh)
    UI:RegisterEvent("PLAYER_LEVEL_UP", QueueRefresh)
    UI:RegisterEvent("UPDATE_EXHAUSTION", QueueRefresh)
    UI:RegisterEvent("SKILL_LINES_CHANGED", QueueRefresh)
    UI:RegisterEvent("TRADE_SKILL_LIST_UPDATE", QueueRefresh)
    UI:RegisterEvent("NEW_RECIPE_LEARNED", QueueRefresh)
    UI:RegisterEvent("PLAYER_XP_UPDATE", function(_, unit)
        if unit == "player" then QueueRefresh() end
    end)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", QueueRefresh)
    UI:RegisterEvent("BANKFRAME_OPENED", QueueRefresh)
    UI:RegisterEvent("BANKFRAME_CLOSED", QueueRefresh)
    UI:RegisterEvent("GET_ITEM_INFO_RECEIVED", QueueRefresh)

    UI:RegisterCommand("account", "toggle", function()
        Module:Toggle()
    end, "Toggle account overview")
    UI:RegisterCommand("account", "reset", function()
        GetDatabase().position = nil
        UI:ApplyFramePosition(Module.frame, GetDatabase(), "position", 0, 0)
    end, "Reset account window position")
end

Module:Initialize()
