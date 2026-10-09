local UI = KamiUI
local Module = UI:NewModule("RadialMenu", "KamiUI_RadialMenu")
local L = UI.Layout.RadialMenu
local VARIANTS = 12

local CONFIG = {
    Q = {
        {"hearthstone", "Hearthstone", "INV_Misc_Rune_01"},
        {"mount", "Mounts", "Ability_Mount_RidingHorse"},
        {"food", "Food", "INV_Misc_Food_15"},
        {"drink", "Drink", "INV_Drink_07"},
        {"bufffood", "Buff Food", "INV_Misc_Food_64"},
        {"elixir", "Elixirs", "INV_Potion_20"},
    },
    E = {
        {"health", "Healing Potions", "INV_Potion_54"},
        {"mana", "Mana Potions", "INV_Potion_76"},
        {"rage", "Rage Potions", "INV_Potion_24"},
        {"utility", "Utility Potions", "INV_Potion_52"},
        {"bandage", "Bandages", "INV_Misc_Bandage_15"},
    },
}

local function Locked()
    return InCombatLockdown and InCombatLockdown()
end

local function Has(text, ...)
    for i = 1, select("#", ...) do
        if string.find(text, select(i, ...), 1, true) then
            return true
        end
    end
    return false
end

local function GetDB()
    if Module.db then return Module.db end
    local db = UI:GetDatabase("radialMenu", { characters = {} })
    local key = UI:GetCurrentCharacterKey()
    db.characters[key] = db.characters[key] or { favorites = {} }
    Module.db = db.characters[key]
    Module.db.favorites = Module.db.favorites or {}
    return Module.db
end

local scanner
local function TooltipText(bag, slot)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "KamiUIRadialScanner",
            UIParent, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    local text = {}
    for i = 2, scanner:NumLines() do
        local font = _G["KamiUIRadialScannerTextLeft" .. i]
        local value = font and font:GetText()
        if type(value) == "string" and UI:CanAccessValue(value) then
            text[#text + 1] = string.lower(value)
        end
    end
    return table.concat(text, " ")
end

local function Add(catalog, category, id, name, icon, score, quantity, kind)
    catalog[category] = catalog[category] or {}
    kind = kind or "item"
    local key = kind .. ":" .. id
    local exists = catalog[category][key]
    if exists then
        exists.quantity = exists.quantity + (quantity or 1)
        return
    end
    catalog[category][key] = {
        id = id, key = key, kind = kind, name = name, icon = icon,
        score = score or 0, quantity = quantity or 1,
    }
end

local function ScanItem(catalog, bag, slot, id, count)
    local name, _, _, itemLevel, requiredLevel, _, subtype, _, _, icon,
        _, classID, subclassID = GetItemInfo(id)
    if not name then return end
    -- Some client builds do not expose numeric subclasses via GetItemInfo.
    if (classID == nil or subclassID == nil) and GetItemInfoInstant then
        local _, _, _, _, _, instantClass, instantSubclass =
            GetItemInfoInstant(id)
        classID = classID or instantClass
        subclassID = subclassID or instantSubclass
    end
    if requiredLevel and UnitLevel and requiredLevel > UnitLevel("player") then
        return
    end
    local n, sub = string.lower(name), string.lower(subtype or "")
    local score = (requiredLevel or 0) * 1000 + (itemLevel or 0)
    icon = icon or (GetItemIcon and GetItemIcon(id))

    if id == 6948 or Has(n, "hearthstone", "ruhestein") then
        Add(catalog, "hearthstone", id, name, icon, score, count)
        return
    end
    if (classID == 15 and subclassID == 5)
        or Has(n, "reins of", "zügel", "zuegel", "mechanostrider",
            "riding kodo", "riding ram", "raptor whistle", "horn of the")
    then
        if GetItemSpell and GetItemSpell(id) then
            Add(catalog, "mount", id, name, icon, score, count)
            return
        end
    end
    if classID ~= 0 then return end

    local food = subclassID == 5 or Has(sub, "food", "drink", "nahrung")
    local potion = subclassID == 1 or Has(sub, "potion", "trank")
    local elixir = subclassID == 2 or subclassID == 3
        or Has(n, "elixir", "elixier", "flask", "fläschchen")
    local bandage = subclassID == 7 or Has(n, "bandage", "verband")
    if bandage then
        Add(catalog, "bandage", id, name, icon, score, count)
    elseif elixir then
        Add(catalog, "elixir", id, name, icon, score, count)
    elseif food or potion then
        local t = TooltipText(bag, slot)
        local health = Has(t, "health", "gesundheit", "hit points")
            or Has(n, "healing", "heiltrank")
        local mana = Has(t, "mana", "magiepunkte")
            or Has(n, "mana", "manatrank")
        local rage = Has(n, "rage", "wuttrank")
            or Has(t, "rage", "wut erzeugt", "wut wieder")
        if food then
            if Has(t, "well fed", "well-fed", "satt", "gut genährt") then
                Add(catalog, "bufffood", id, name, icon, score, count)
            elseif mana and not health then
                Add(catalog, "drink", id, name, icon, score, count)
            elseif health then
                Add(catalog, "food", id, name, icon, score, count)
            end
        elseif rage then
            Add(catalog, "rage", id, name, icon, score, count)
        elseif health or mana then
            if health then Add(catalog, "health", id, name, icon, score, count) end
            if mana then Add(catalog, "mana", id, name, icon, score, count) end
        else
            Add(catalog, "utility", id, name, icon, score, count)
        end
    end
end

local function ScanMounts(catalog)
    if C_MountJournal and C_MountJournal.GetMountIDs
        and C_MountJournal.GetMountInfoByID then
        for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
            local name, spell, icon, _, usable, _, favorite,
                _, _, _, collected = C_MountJournal.GetMountInfoByID(id)
            if name and spell and collected ~= false then
                Add(catalog, "mount", spell, name, icon,
                    (usable and 100000 or 0) + (favorite and 20000 or 0),
                    1, "spell")
            end
        end
    elseif GetNumCompanions and GetCompanionInfo then
        for i = 1, (GetNumCompanions("MOUNT") or 0) do
            local _, name, spell, icon = GetCompanionInfo("MOUNT", i)
            if name and spell then
                Add(catalog, "mount", spell, name, icon, 100000, 1, "spell")
            end
        end
    end
end

local function ScanInventory()
    local catalog = {}
    for bag = 0, 4 do
        for slot = 1, UI:GetContainerNumSlots(bag) do
            local info = UI:GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
                or (GetContainerItemID and GetContainerItemID(bag, slot))
            if id then
                ScanItem(catalog, bag, slot, id, info and info.stackCount or 1)
            end
        end
    end
    ScanMounts(catalog)
    local lists = {}
    for key, entries in pairs(catalog) do
        local list = {}
        for _, entry in pairs(entries) do list[#list + 1] = entry end
        table.sort(list, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            if a.quantity ~= b.quantity then return a.quantity > b.quantity end
            return a.name < b.name
        end)
        lists[key] = list
    end
    return lists
end

local function Choose(category, list)
    local favorite = GetDB().favorites[category]
    if favorite then
        for _, entry in ipairs(list) do
            if entry.key == favorite then return entry end
        end
    end
    return list[1]
end

local function Action(button, entry)
    -- Secure action attributes may only change out of combat.
    button:SetAttribute("type1", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("spell1", nil)
    if entry then
        button:SetAttribute("type1", entry.kind)
        if entry.kind == "item" then
            button:SetAttribute("item1", "item:" .. entry.id)
        else
            button:SetAttribute("spell1", entry.id)
        end
    end
    button.entry = entry
end

local function IconButton(button, size)
    button:SetSize(size, size)
    button:RegisterForClicks("AnyUp")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.035, .04, .05, .94)
    local image = button:CreateTexture(nil, "ARTWORK")
    image:SetPoint("TOPLEFT", 3, -3)
    image:SetPoint("BOTTOMRIGHT", -3, 3)
    image:SetTexCoord(.08, .92, .08, .92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetAllPoints()
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", -2, 3)
    local star = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    star:SetPoint("TOPRIGHT", -2, -2)
    star:SetText("*")
    star:Hide()
    button.icon, button.count, button.star = image, count, star
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.entry then
            if self.entry.kind == "item" then
                GameTooltip:SetHyperlink("item:" .. self.entry.id)
            elseif GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(self.entry.id)
            else
                GameTooltip:SetText(self.entry.name)
            end
        else
            GameTooltip:SetText(self.categoryName or "Unavailable")
            GameTooltip:AddLine("No matching item available", .7, .7, .7)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Display(button, entry, placeholder, favorite)
    button.icon:SetTexture(entry and entry.icon
        or ("Interface\\Icons\\" .. placeholder))
    button.icon:SetDesaturated(not entry)
    button.icon:SetAlpha(entry and 1 or .3)
    button.count:SetText(entry and entry.kind == "item"
        and entry.quantity > 1 and entry.quantity or "")
    button.star:SetShown(favorite == true)
    button.entry = entry
end

local function CreateWheel(key, categories)
    local root = CreateFrame("Frame", "KamiUIRadial" .. key, UIParent,
        "SecureHandlerBaseTemplate")
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("DIALOG")
    root:Hide()
    root:SetFrameRef("root", root)
    root.buttons, root.submenus = {}, {}

    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(120, 120)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetAlpha(.72)
    local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER")
    title:SetText(key)

    -- Full-screen secure catcher: clicking outside the wheel closes it.
    local catcher = CreateFrame("Button", nil, root, "SecureHandlerClickTemplate")
    catcher:SetAllPoints(root)
    catcher:SetFrameLevel(root:GetFrameLevel() + 1)
    catcher:RegisterForClicks("AnyUp")
    catcher:SetFrameRef("root", root)
    catcher:SetAttribute("_onclick", [[self:GetFrameRef("root"):Hide()]])

    for index, category in ipairs(categories) do
        local theta = math.rad(90 - (index - 1) * 360 / #categories)
        local x, y = math.cos(theta) * L.RADIUS, math.sin(theta) * L.RADIUS
        local main = CreateFrame("Button", nil, root, "SecureActionButtonTemplate")
        main:SetFrameLevel(root:GetFrameLevel() + 3)
        main:SetPoint("CENTER", root, "CENTER", x, y)
        main.categoryName = category[2]
        IconButton(main, L.ICON_SIZE)

        local sub = CreateFrame("Frame", nil, root, "SecureHandlerBaseTemplate")
        sub:SetSize(L.SUB_RADIUS * 2 + L.SUB_ICON_SIZE,
            L.SUB_RADIUS * 2 + L.SUB_ICON_SIZE)
        sub:SetFrameLevel(root:GetFrameLevel() + 4)
        sub:SetPoint("CENTER", main, "CENTER",
            (x >= 0 and 1 or -1) * L.SUB_OFFSET, 0)
        sub:Hide()
        sub.buttons = {}
        local label = sub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetText(category[2])

        for variant = 1, VARIANTS do
            local a = math.rad(90 - (variant - 1) * 360 / VARIANTS)
            local item = CreateFrame("Button", nil, sub, "SecureActionButtonTemplate")
            item:SetFrameLevel(root:GetFrameLevel() + 5)
            item:SetPoint("CENTER", sub, "CENTER",
                math.cos(a) * L.SUB_RADIUS, math.sin(a) * L.SUB_RADIUS)
            item.categoryName = category[2]
            item.category = category[1]
            IconButton(item, L.SUB_ICON_SIZE)
            item:Hide()
            -- Return a non-nil message so secure postBody runs in combat.
            root:WrapScript(item, "OnClick", [[return nil, "clicked"]], [[
                if button == "LeftButton" then
                    self:GetFrameRef("root"):Hide()
                end
            ]])
            item:HookScript("PostClick", function(self, button)
                if button ~= "RightButton" or not self.entry then return end
                if Locked() then
                    UI:Print("Choose favorites outside combat.")
                    return
                end
                GetDB().favorites[self.category] = self.entry.key
                Module:Refresh()
            end)
            sub.buttons[variant] = item
        end

        root:SetFrameRef("sub" .. index, sub)
        root:WrapScript(main, "OnClick", [[return nil, "clicked"]],
            string.format([[
                if button == "RightButton" then
                    local target = self:GetFrameRef("sub%d")
                    local i, other = 1, self:GetFrameRef("sub1")
                    while other do
                        if other ~= target then other:Hide() end
                        i = i + 1
                        other = self:GetFrameRef("sub" .. i)
                    end
                    if target:IsShown() then target:Hide()
                    else target:Show() end
                else
                    self:GetFrameRef("root"):Hide()
                end
            ]], index))
        root.buttons[index], root.submenus[index] = main, sub
    end
    return root
end

function Module:Refresh()
    if Locked() then self.refreshPending = true return end
    self.refreshPending = false
    local catalog = ScanInventory()
    for key, categories in pairs(CONFIG) do
        local wheel = self.wheels[key]
        for index, category in ipairs(categories) do
            local entries = catalog[category[1]] or {}
            local selected = Choose(category[1], entries)
            local main = wheel.buttons[index]
            Action(main, selected)
            Display(main, selected, category[3],
                selected and GetDB().favorites[category[1]] == selected.key)
            for slot, button in ipairs(wheel.submenus[index].buttons) do
                local entry = entries[slot]
                Action(button, entry)
                if entry then
                    Display(button, entry, category[3],
                        GetDB().favorites[category[1]] == entry.key)
                    button:Show()
                else
                    button:Hide()
                end
            end
        end
    end
end

local function BindKeys()
    if Locked() then Module.bindingsPending = true return end
    Module.bindingsPending = false
    ClearOverrideBindings(Module.bindingOwner)
    for key in pairs(CONFIG) do
        SetOverrideBindingClick(Module.bindingOwner, true, key,
            "KamiUIRadialToggle" .. key, "LeftButton")
    end
end

function Module:Initialize()
    self.wheels = {}
    GetDB()
    for key, categories in pairs(CONFIG) do
        self.wheels[key] = CreateWheel(key, categories)
    end
    for key in pairs(CONFIG) do
        local button = CreateFrame("Button", "KamiUIRadialToggle" .. key,
            UIParent, "SecureHandlerClickTemplate")
        button:RegisterForClicks("AnyUp")
        button:SetFrameRef("menu", self.wheels[key])
        button:SetFrameRef("other", self.wheels[key == "Q" and "E" or "Q"])
        button:SetAttribute("_onclick", [[
            local menu = self:GetFrameRef("menu")
            self:GetFrameRef("other"):Hide()
            if menu:IsShown() then menu:Hide() else menu:Show() end
        ]])
    end
    self.bindingOwner = CreateFrame("Frame", nil, UIParent)
    BindKeys()
    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:Refresh()
        BindKeys()
    end)
    UI:RegisterEvent("BAG_UPDATE_DELAYED", function() Module:Refresh() end)
    UI:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
        if not Locked() then Module:Refresh() end
    end)
    UI:RegisterEvent("UPDATE_BINDINGS", BindKeys)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.refreshPending then Module:Refresh() end
        if Module.bindingsPending then BindKeys() end
    end)
    UI:RegisterCommand("radial", "refresh", function()
        Module:Refresh()
        UI:Print("Radial inventory refreshed.")
    end, "Refresh consumable wheels")
    UI:RegisterCommand("radial", "reset", function()
        if Locked() then return end
        GetDB().favorites = {}
        Module:Refresh()
        UI:Print("Radial favorites reset.")
    end, "Reset radial favorites")
    self:Refresh()
end

Module:Initialize()
