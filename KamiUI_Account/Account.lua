local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
local Module = UI:NewModule("Account", "KamiUI_Account")

BINDING_HEADER_KAMIUIACCOUNT = "KamiUI"
BINDING_NAME_KAMIUIACCOUNTTOGGLE = "Toggle Account Overview"

local WIDTH = 540
local HEIGHT = 530
local SLOT_SIZE = 36
local SLOT_GAP = 3
local GRID_COLUMNS = 12
local GRID_ROWS = 9
local ROW_HEIGHT = 39
local CHARACTER_ROWS = 10

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
        item.name = item.name or tostring(id)
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

local CHARACTER_COLUMNS = {
    { key = "name", label = "Character", x = 3, width = 174 },
    { key = "class", label = "Class", x = 180, width = 91 },
    { key = "level", label = "Level", x = 274, width = 53 },
    { key = "xp", label = "XP", x = 332, width = 54 },
    { key = "gold", label = "Gold", x = 389, width = 116 },
}

local function GetXPPercent(profile)
    local xp = tonumber(profile.xp)
    local xpMax = tonumber(profile.xpMax)
    if not xp or not xpMax or xpMax <= 0 then
        return nil
    end
    return math.max(0, math.min(100, xp / xpMax * 100))
end

local function SortCharacterEntries(entries, pane)
    local key = pane.sortKey or "level"
    local ascending = pane.sortAscending == true
    local currentKey = UI:GetCurrentCharacterKey()

    table.sort(entries, function(left, right)
        local a = left.character or {}
        local b = right.character or {}
        local av, bv

        if key == "name" then
            av = string.lower(a.name or select(2, UI:ParseCharacterKey(left.key)))
            bv = string.lower(b.name or select(2, UI:ParseCharacterKey(right.key)))
        elseif key == "class" then
            av = string.lower(a.className or a.classFile or "")
            bv = string.lower(b.className or b.classFile or "")
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
    pane.count:SetText(#entries .. " characters")

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
            row.class:SetText(
                profile.className or profile.classFile or "-"
            )
            SetClassColor(row.class, profile.classFile)

            local level = tonumber(profile.level)
            row.level:SetText(
                level and level > 0 and tostring(level) or "-"
            )
            local xpPercent = GetXPPercent(profile)
            row.xp:SetText(
                xpPercent and string.format("%.0f%%", xpPercent) or "-"
            )
            row.money:SetText(
                UI:FormatMoney(profile.money or 0, { iconSize = 12 })
            )
            row:Show()
        else
            row.entryKey = nil
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
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -47)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 35)
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
        heading.sortKey = column.key
        heading:SetNormalFontObject("GameFontNormalSmall")
        heading:SetHighlightFontObject("GameFontHighlightSmall")
        heading:GetFontString():SetJustifyH(
            column.key == "gold" and "RIGHT" or "LEFT"
        )

        local h = heading:CreateTexture(nil, "HIGHLIGHT")
        h:SetAllPoints()
        h:SetColorTexture(1, 1, 1, 0.08)
        heading:SetScript("OnClick", function(self)
            if pane.sortKey == self.sortKey then
                pane.sortAscending = not pane.sortAscending
            else
                pane.sortKey = self.sortKey
                pane.sortAscending = self.sortKey == "name"
                    or self.sortKey == "class"
            end
            pane.offset = 0
            RenderCharacters()
        end)
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
        row.class = CreateLabel(row, 10)
        row.level = CreateLabel(row, 10)
        row.xp = CreateLabel(row, 10)
        row.money = CreateLabel(row, 10)

        for _, column in ipairs(CHARACTER_COLUMNS) do
            local field = column.key == "gold"
                and row.money or row[column.key]
            field:SetPoint(
                column.key == "gold" and "RIGHT" or "LEFT",
                row, "LEFT",
                column.x + (column.key == "gold" and column.width or 0),
                0
            )
            field:SetWidth(column.width - 4)
            field:SetJustifyH(
                column.key == "gold" and "RIGHT" or "LEFT"
            )
            field:SetMaxLines(1)
        end

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetColorTexture(1, 1, 1, 0.06)

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
    pageLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 13)
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
    search:SetPoint("TOPLEFT", pane, "TOPLEFT", 16, -47)
    search:SetSize(370, 23)
    search:SetAutoFocus(false)
    search:SetTextInsets(7, 7, 0, 0)
    if search.SetPropagateKeyboardInput then
        search:SetPropagateKeyboardInput(false)
    end
    Components:StyleInput(search)
    pane.search = search

    local hint = CreateLabel(pane, 10, Palette.muted)
    hint:SetPoint("TOPLEFT", pane, "TOPLEFT", 19, -76)
    hint:SetText("Search by name, type, subclass or 'equipped'")

    local matchCount = CreateLabel(pane, 10, Palette.muted)
    matchCount:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -17, -54)
    pane.matchCount = matchCount

    for row = 1, GRID_ROWS do
        for column = 1, GRID_COLUMNS do
            local button = Components:CreateItemDisplayButton(pane, {
                size = SLOT_SIZE,
                corners = true,
            })
            button:SetPoint(
                "TOPLEFT", pane, "TOPLEFT",
                17 + (column - 1) * (SLOT_SIZE + SLOT_GAP),
                -107 - (row - 1) * (SLOT_SIZE + SLOT_GAP)
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
    pageLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 13)
    pane.pageLabel = pageLabel
    return pane
end

local function CreateAccountFrame()
    local frame, header = Components:CreateWindow("KamiUIAccountFrame", {
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
    local close = Components:CreateWindowCloseButton(header, {
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
            width = 100,
            height = 22,
            text = definition.label,
            orientation = "bottom",
            joinLeft = index > 1,
        })
        tab:SetPoint(
            "TOPLEFT", frame, "BOTTOMLEFT",
            16 + (index - 1) * 100, 1
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

-- XML bindings support a command and header but not a "default"
-- attribute. Assign the requested backslash once, only when that key is
-- free and the account action has no binding already. Never steal a key.
local function BindDefaultKeyOnce()
    local db = GetDatabase()
    if db.defaultKeyChecked then return end
    if not GetBindingKey or not GetBindingAction or not SetBinding then
        return
    end

    db.defaultKeyChecked = true
    if GetBindingKey("KAMIUIACCOUNTTOGGLE") then return end

    local key = "\\"
    local action = GetBindingAction(key)
    if action == nil or action == "" then
        if SetBinding(key, "KAMIUIACCOUNTTOGGLE") then
            if GetCurrentBindingSet and SaveBindings then
                SaveBindings(GetCurrentBindingSet())
            end
        end
    end
end

function Module:Initialize()
    GetDatabase()
    CreateAccountFrame()
    self:Refresh()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", BindDefaultKeyOnce)

    UI:RegisterEvent("BAG_UPDATE_DELAYED", QueueRefresh)
    UI:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", QueueRefresh)
    UI:RegisterEvent("PLAYER_MONEY", QueueRefresh)
    UI:RegisterEvent("PLAYER_LEVEL_UP", QueueRefresh)
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
