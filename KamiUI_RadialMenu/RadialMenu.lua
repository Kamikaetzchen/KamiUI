local UI = KamiUI
local Module = UI:NewModule("RadialMenu", "KamiUI_RadialMenu")
local L = UI.Layout.RadialMenu

-- The number of icons is determined by inventory. A ring is limited to
-- 16 visible items to prevent hundreds of mounts covering the screen.
local MAX_VISIBLE = 16

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
    if not pcall(scanner.SetBagItem, scanner, bag, slot) then
        return ""
    end
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
    -- Forever exposes item APIs through C_Item; the legacy globals may be nil.
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local instant = (C_Item and C_Item.GetItemInfoInstant)
        or GetItemInfoInstant
    local name, _, _, itemLevel, requiredLevel, _, subtype, _, _, icon,
        _, classID, subclassID
    if info then
        name, _, _, itemLevel, requiredLevel, _, subtype, _, _, icon,
            _, classID, subclassID = info(id)
    end
    if (classID == nil or subclassID == nil or not icon) and instant then
        local _, _, instantSub, _, instantIcon, instantClass, instantSubclass =
            instant(id)
        classID = classID or instantClass
        subclassID = subclassID or instantSubclass
        subtype = subtype or instantSub
        icon = icon or instantIcon
    end
    if not name then
        -- The Hearthstone is known even when its item cache isn't populated.
        if id == 6948 then
            Add(catalog, "hearthstone", id, "Hearthstone",
                icon or "Interface\\Icons\\INV_Misc_Rune_01", 0, count)
        elseif C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(id)
        end
        return
    end
    if requiredLevel and UnitLevel and requiredLevel > UnitLevel("player") then
        return
    end
    local n, sub = string.lower(name), string.lower(subtype or "")
    local score = (requiredLevel or 0) * 1000 + (itemLevel or 0)
    icon = icon
        or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
        or (GetItemIcon and GetItemIcon(id))

    if id == 6948 or Has(n, "hearthstone", "ruhestein") then
        Add(catalog, "hearthstone", id, name, icon, score, count)
        return
    end
    if (classID == 15 and subclassID == 5)
        or Has(n, "reins of", "zügel", "zuegel", "mechanostrider",
            "riding kodo", "riding ram", "raptor whistle", "horn of the")
    then
        local spell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
        if spell and spell(id) then
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
                or (C_Container and C_Container.GetContainerItemID
                    and C_Container.GetContainerItemID(bag, slot))
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
    button:RegisterForClicks("AnyUp", "AnyDown")
    -- Consumables should fire on mouse release, regardless of global
    -- ActionButtonUseKeyDown. The secure use action remains hardware-driven.
    button:SetAttribute("useOnKeyDown", false)
    local media = "Interface\\AddOns\\KamiUI_RadialMenu\\Media\\"
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(media .. "RadialFrame.tga")
    local image = button:CreateTexture(nil, "ARTWORK")
    image:SetPoint("TOPLEFT", 6, -6)
    image:SetPoint("BOTTOMRIGHT", -6, 6)
    image:SetTexCoord(.04, .96, .04, .96)
    -- Round item icons with a real alpha mask, not a square atlas border.
    if button.CreateMaskTexture and image.AddMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetAllPoints(image)
        mask:SetTexture(media .. "RadialMask.tga")
        image:AddMaskTexture(mask)
        button.iconMask = mask
    end
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture(media .. "RadialOutline.tga")
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

local function CreateVariantButton(root, submenu, category)
    local item = CreateFrame("Button", nil, submenu, "SecureActionButtonTemplate")
    item:SetFrameLevel(root:GetFrameLevel() + 5)
    item.categoryName = category[2]
    item.category = category[1]
    IconButton(item, L.SUB_ICON_SIZE)
    item:Hide()

    root:WrapScript(item, "OnClick", [[return nil, "clicked"]], [[
        if button == "LeftButton" and not down then
            control:Hide()
        end
    ]])
    item:HookScript("PostClick", function(self, mouseButton, down)
        if mouseButton ~= "RightButton" or down or not self.entry then
            return
        end
        if Locked() then
            UI:Print("Favorites can only be changed out of combat.")
            return
        end
        GetDB().favorites[self.category] = self.entry.key
        Module:Refresh()
    end)
    return item
end

local function VariantRadius(count)
    if count <= 1 then return 0 end
    if count == 2 then return L.SUB_ICON_SIZE / 2 + 12 end
    local minimumSeparation = L.SUB_ICON_SIZE + (L.SUB_GAP or 7)
    return math.max(L.SUB_MIN_RADIUS,
        math.ceil(minimumSeparation / (2 * math.sin(math.pi / count))))
end

-- Give crowded variant rings enough room to stay clear of their parent icon.
local function SubmenuOffset(radius)
    return math.max(L.SUB_OFFSET,
        radius + (L.SUB_ICON_SIZE + L.ICON_SIZE) / 2 + (L.SUB_GAP or 7))
end

local function CreateWheel(key, categories)
    local root = CreateFrame("Frame", "KamiUIRadial" .. key, UIParent,
        "SecureHandlerBaseTemplate")
    -- Keep the secure root small. The click catcher covers only the wheel,
    -- allowing normal world mouse input everywhere else.
    root:SetSize(1, 1)
    root:SetPoint("CENTER", UIParent, "CENTER")
    root:SetFrameStrata("DIALOG")
    root:Hide()
    root:SetFrameRef("root", root)
    root.buttons, root.submenus = {}, {}
    -- Protected cleanup works even if the menu is hidden during combat.
    root:WrapScript(root, "OnHide", string.format([[
        for i = 1, %d do
            local submenu = control:GetFrameRef("sub" .. i)
            if submenu then submenu:Hide() end
        end
    ]], #categories))

    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(L.CENTER_SIZE, L.CENTER_SIZE)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetAlpha(.72)
    local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER")
    title:SetText(key)

    -- Only intercept clicks in the primary wheel's bounding square.
    -- Full-screen catching prevented mouse-look and world interactions.
    -- Q/E still close the wheel from anywhere, including during combat.
    local catcher = CreateFrame("Button", nil, root, "SecureHandlerClickTemplate")
    local hitSize = L.RADIUS * 2 + L.ICON_SIZE + 12
    catcher:SetSize(hitSize, hitSize)
    catcher:SetPoint("CENTER", root, "CENTER")
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
        -- Wrapped snippets use 'control' for the secure root handler.

        local sub = CreateFrame("Frame", nil, root, "SecureHandlerBaseTemplate")
        sub:SetSize(L.SUB_ICON_SIZE, L.SUB_ICON_SIZE)
        sub:SetFrameLevel(root:GetFrameLevel() + 4)
        sub:SetPoint("CENTER", main, "CENTER",
            math.cos(theta) * L.SUB_OFFSET,
            math.sin(theta) * L.SUB_OFFSET)
        sub:Hide()
        sub.buttons = {}
        local label = sub:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetText(category[2])
        sub.label = label
        root:SetFrameRef("sub" .. index, sub)
        root:WrapScript(main, "OnClick", [[return nil, "clicked"]],
            string.format([[
                if button == "RightButton" and not down then
                    local target = control:GetFrameRef("sub%d")
                    if not target or not target:GetAttribute("hasVariants") then
                        return
                    end
                    for i = 1, %d do
                        local other = control:GetFrameRef("sub" .. i)
                        if other and other ~= target then other:Hide() end
                    end
                    if target:IsShown() then
                        target:Hide()
                    else
                        target:Show()
                    end
                elseif button == "LeftButton" and not down then
                    control:Hide()
                end
            ]], index, #categories))
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
            local sub = wheel.submenus[index]
            local count = math.min(#entries, MAX_VISIBLE)
            local radius = VariantRadius(count)
            local theta = math.rad(90 - (index - 1) * 360 / #categories)
            local offset = SubmenuOffset(radius)
            sub:ClearAllPoints()
            sub:SetPoint("CENTER", main, "CENTER",
                math.cos(theta) * offset, math.sin(theta) * offset)
            sub:SetAttribute("hasVariants", count > 0)
            sub:SetSize(radius * 2 + L.SUB_ICON_SIZE + 12,
                radius * 2 + L.SUB_ICON_SIZE + 12)
            sub.label:SetShown(count == 0)

            -- Create protected variants only when required, out of combat.
            -- The visible buttons are spread evenly over the actual count.
            for slot = 1, count do
                if not sub.buttons[slot] then
                    sub.buttons[slot] = CreateVariantButton(wheel, sub, category)
                end
                local button = sub.buttons[slot]
                local angle = math.rad(90 - (slot - 1) * 360 / count)
                button:ClearAllPoints()
                button:SetPoint("CENTER", sub, "CENTER",
                    math.cos(angle) * radius, math.sin(angle) * radius)
                local entry = entries[slot]
                Action(button, entry)
                Display(button, entry, category[3],
                    GetDB().favorites[category[1]] == entry.key)
                button:Show()
            end
            for slot = count + 1, #sub.buttons do
                local button = sub.buttons[slot]
                Action(button, nil)
                button:Hide()
            end
        end
    end
end

-- Q and E are deliberately overridden without adding separate entries to
-- WoW's Key Bindings menu.
local function BindKeys()
    if Locked() then
        Module.bindingsPending = true
        return
    end
    Module.bindingsPending = false
    if not ClearOverrideBindings or not SetOverrideBindingClick then
        return
    end
    ClearOverrideBindings(Module.bindingOwner)
    for key in pairs(CONFIG) do
        SetOverrideBindingClick(Module.bindingOwner, true, key,
            "KamiUIRadialToggle" .. key, "LeftButton")
    end
end

-- Q/E sit at 35% and 65% of the screen width. Protected frames
-- are never repositioned by insecure Lua in combat.
function Module:PositionWheels()
    if Locked() then
        self.positionsPending = true
        return
    end

    self.positionsPending = nil
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        return
    end

    -- Account for secondary wheels now extending along each icon's angle.
    local maxRadius = VariantRadius(MAX_VISIBLE)
    local maxExtent = L.RADIUS + SubmenuOffset(maxRadius)
        + maxRadius + L.SUB_ICON_SIZE / 2
    local minX = math.min(maxExtent, width / 2)
    local minY = math.min(maxExtent, height / 2)
    for key, wheel in pairs(self.wheels) do
        local fractionX = key == "Q" and L.Q_SCREEN_X or L.E_SCREEN_X
        local x = math.max(minX, math.min(width - minX, width * fractionX))
        local y = math.max(minY, math.min(height - minY,
            height * L.SCREEN_Y))
        wheel:ClearAllPoints()
        wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end
end

function Module:Initialize()
    self.wheels = {}
    GetDB()
    for key, categories in pairs(CONFIG) do
        self.wheels[key] = CreateWheel(key, categories)
    end
    self:PositionWheels()
    -- Both menus use exactly the same hardware-driven secure toggle,
    -- whether the player is in combat or not. A single key release produces
    -- one click; no keyboard listener, polling or combat-specific modes.
    for key in pairs(CONFIG) do
        local button = CreateFrame("Button", "KamiUIRadialToggle" .. key,
            UIParent, "SecureHandlerClickTemplate")
        button:RegisterForClicks("AnyUp")
        button:SetFrameRef("menu", self.wheels[key])
        button:SetFrameRef("other", self.wheels[key == "Q" and "E" or "Q"])
        button:SetAttribute("_onclick", [[
            local menu = self:GetFrameRef("menu")
            local other = self:GetFrameRef("other")
            if not menu or not other then return end
            other:Hide()
            if menu:IsShown() then
                menu:Hide()
            else
                menu:Show()
            end
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
    UI:RegisterEvent("DISPLAY_SIZE_CHANGED", function()
        Module:PositionWheels()
    end)
    UI:RegisterEvent("UI_SCALE_CHANGED", function()
        Module:PositionWheels()
    end)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.positionsPending then Module:PositionWheels() end
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
