local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Auras", "KamiUI_Auras")

local Layout = UI.Layout.Auras

-- Kami Facet: soft light facets in the top/bottom 25% of each bar,
-- with a flat center from 25-75%. Its alpha stays completely uniform:
-- only RGB brightness changes, so the bars remain full-height beside icons.
local BAR_FACET_TEXTURE =
    "Interface\\AddOns\\KamiUI_Auras\\Textures\\KamiFacet"


local container
local weaponEnchantBars = {}
local weaponEnchantTimers = {}
local weaponEnchantCount = 0
local pendingEnchantLayout = false
local nativeEnchantButtons = {}
local nativeEnchantSlots = {}
-- Test mode is intentionally session-only. /reload restores the working
-- Forever-specific imbue bars if the native API does not support them.
Module.nativeEnchantTest = false

-- Forever exposes Shaman imbues separately from the temporary enchants
-- consumed by Blizzard's AuraContainer. Keep this reader separate: only
-- effects NOT already represented by the native container are drawn here.
local function IsReadable(value)
    return UI:CanAccessValue(value)
end

local function IsReadableNumber(value)
    return IsReadable(value) and type(value) == "number"
end

local function IsReadableTable(value)
    return IsReadable(value)
        and not (issecrettable and issecrettable(value))
        and type(value) == "table"
end

local function GetWeaponEnchantSources()
    if not C_Item or not C_Item.GetWeaponEnchantInfo
        or not Enum or not Enum.WeaponSlot
    then
        return {}
    end

    local slots = Enum.WeaponSlot
    return {
        { weapon = slots.MainHand, inventory = INVSLOT_MAINHAND or 16,
            name = "Main Hand" },
        { weapon = slots.OffHand, inventory = INVSLOT_OFFHAND or 17,
            name = "Off Hand" },
        { weapon = slots.Ranged, inventory = INVSLOT_RANGED or 18,
            name = "Ranged" },
    }
end

local function ReadWeaponEnchantList()
    local entries = {}
    -- In test mode, let Blizzard's AuraContainer be the sole owner of
    -- weapon-enchant display and combat-safe layout. Do not destroy the
    -- working fallback or change the registration of protected frames.
    if Module.nativeEnchantTest then
        return entries
    end
    local hasNativeSlots = container and container.AddItemEnchantment
    local permanent = Enum and Enum.ItemEnchantType
        and Enum.ItemEnchantType.Permanent or 1
    local imbueType = Enum and Enum.ItemEnchantType
        and Enum.ItemEnchantType.Imbue or 3

    for _, source in ipairs(GetWeaponEnchantSources()) do
        if source.weapon ~= nil then
            local nativeEnchantID
            local nativeHasEnchant = false
            if hasNativeSlots and source.weapon ~= (Enum.WeaponSlot.Ranged)
                and C_PaperDollInfo
                and C_PaperDollInfo.GetTemporaryEnchantmentInfo
            then
                local info = UI:SafeCall(
                    C_PaperDollInfo.GetTemporaryEnchantmentInfo,
                    source.inventory
                )
                if IsReadableTable(info) then
                    nativeHasEnchant = true
                    if IsReadableNumber(info.enchantID) then
                        nativeEnchantID = info.enchantID
                    end
                end
            end

            local list = UI:SafeCall(
                C_Item.GetWeaponEnchantInfo, source.weapon
            )
            if IsReadableTable(list) then
                for _, enchant in ipairs(list) do
                    if IsReadableTable(enchant)
                        and IsReadable(enchant.hasEnchant)
                        and enchant.hasEnchant == true
                        and IsReadableNumber(enchant.enchantType)
                        and enchant.enchantType ~= permanent
                        and IsReadableNumber(enchant.enchantID)
                        and IsReadableNumber(enchant.timeLeft)
                        and enchant.timeLeft > 0
                        -- The native bar is responsible for its own enchant.
                        and enchant.enchantID ~= nativeEnchantID
                        and (not nativeHasEnchant
                            or enchant.enchantType == imbueType)
                    then
                        local icon = IsReadableNumber(enchant.enchantIconID)
                            and enchant.enchantIconID or nil
                        local charges = IsReadableNumber(enchant.charges)
                            and enchant.charges or 0
                        entries[#entries + 1] = {
                            id = enchant.enchantID,
                            inventorySlot = source.inventory,
                            slotName = source.name,
                            icon = icon,
                            charges = charges,
                            remaining = enchant.timeLeft / 1000,
                        }
                    end
                end
            end
        end
    end

    return entries
end

local function FormatEnchantTime(seconds)
    if seconds >= 3600 then
        return string.format("%dh %dm", math.floor(seconds / 3600),
            math.floor(seconds % 3600 / 60))
    elseif seconds >= 60 then
        return string.format("%dm %ds", math.floor(seconds / 60),
            math.floor(seconds % 60))
    end
    return string.format("%ds", math.ceil(seconds))
end

local weaponEnchantNames = {}

local function GetEnchantName(entry)
    if weaponEnchantNames[entry.id] then
        return weaponEnchantNames[entry.id]
    end

    if C_Item and C_Item.GetEnchantInfo then
        local info = UI:SafeCall(C_Item.GetEnchantInfo, entry.id)
        if IsReadableTable(info) and IsReadable(info.name)
            and type(info.name) == "string" and info.name ~= ""
        then
            weaponEnchantNames[entry.id] = info.name
            return info.name
        end
    end

    -- The weapon tooltip normally contains a green line such as
    -- "Rockbiter 3 (28 min)". Only inspect readable tooltip text outside
    -- combat, and never rely on this optional name for enchant tracking.
    if not (InCombatLockdown and InCombatLockdown())
        and C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    then
        local tooltip = UI:SafeCall(
            C_TooltipInfo.GetInventoryItem, "player", entry.inventorySlot
        )
        if IsReadableTable(tooltip) and IsReadableTable(tooltip.lines) then
            for _, line in ipairs(tooltip.lines) do
                if IsReadableTable(line) and IsReadable(line.leftText)
                    and type(line.leftText) == "string"
                    and IsReadableTable(line.leftColor)
                then
                    local color = line.leftColor
                    local r, g, b = color.r, color.g, color.b
                    if IsReadableNumber(r) and IsReadableNumber(g)
                        and IsReadableNumber(b)
                        and r < 0.45 and g > 0.65 and b < 0.45
                    then
                        local name = string.match(
                            line.leftText, "^%s*(.-)%s*%(%d+[^%)]*%)%s*$"
                        )
                        if name and name ~= "" then
                            weaponEnchantNames[entry.id] = name
                            return name
                        end
                    end
                end
            end
        end
    end

    return entry.slotName .. " Imbue"
end

local function CreateWeaponEnchantBar()
    local button = CreateFrame("Button", nil, UIParent)
    button:SetSize(Layout.WIDTH, Layout.HEIGHT)
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.ICON_SIZE, Layout.ICON_SIZE)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    background:SetPoint("BOTTOMRIGHT")
    background:SetTexture(BAR_FACET_TEXTURE)
    background:SetVertexColor(
        Palette.auras.background[1],
        Palette.auras.background[2],
        Palette.auras.background[3],
        Styles.State.aurasBackgroundAlpha
    )

    local barContainer = CreateFrame("Frame", nil, button)
    barContainer:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    barContainer:SetPoint("BOTTOMRIGHT")
    barContainer:SetAlpha(Styles.State.aurasBarAlpha)

    local bar = CreateFrame("StatusBar", nil, barContainer)
    bar:SetAllPoints()
    bar:SetStatusBarTexture(BAR_FACET_TEXTURE)
    local color = Palette.auras.weaponEnchant
    bar:SetStatusBarColor(color[1], color[2], color[3], 1)
    button.bar = bar

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    overlay:EnableMouse(false)

    local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()
    local name = overlay:CreateFontString(nil, "OVERLAY")
    name:SetFont(fontPath, Styles.FontSize.Auras, fontFlags)
    name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    name:SetPoint("RIGHT", bar, "RIGHT", -55, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetTextColor(1, 1, 1)
    name:SetShadowColor(0, 0, 0, 1)
    name:SetShadowOffset(1, -1)
    button.nameText = name

    local timeText = overlay:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(fontPath, Styles.FontSize.Auras, fontFlags)
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetTextColor(1, 1, 1)
    timeText:SetShadowColor(0, 0, 0, 1)
    timeText:SetShadowOffset(1, -1)
    button.timeText = timeText

    local countText = overlay:CreateFontString(nil, "OVERLAY")
    countText:SetFont(fontPath, Styles.FontSize.Auras, "OUTLINE")
    countText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    countText:SetTextColor(1, 1, 1)
    button.countText = countText

    button:SetScript("OnEnter", function(self)
        if not self.inventorySlot then return end
        -- Anchoring the tooltip to a restricted aura layout can taint it.
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        GameTooltip:SetInventoryItem("player", self.inventorySlot)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnUpdate", function(self)
        if not self.expiration or not self.duration then return end
        local remaining = math.max(0, self.expiration - GetTime())
        self.bar:SetValue(remaining)
        self.timeText:SetText(FormatEnchantTime(remaining))
    end)

    button:Hide()
    return button
end

-- AuraContainer uses a protected flow layout. Moving its anchor while
-- combat-locked would taint it, even though Forever imbues are ordinary data.
-- Keep that anchor fixed, and expand the *unprotected* imbue rows below it.
-- This maintains a gap-free visual stack without any combat-only reflow.
local function PositionWeaponEnchantBars()
    local bottom = Layout.Y + UI:GetBottomInset()
        - Layout.GROUP_GAP

    for index, button in ipairs(weaponEnchantBars) do
        if index <= weaponEnchantCount and button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint(
                "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
                Layout.X,
                bottom - (weaponEnchantCount - index + 1) * Layout.HEIGHT
            )
        end
    end
end

local function UpdatePosition()
    if not container then return end

    if InCombatLockdown and InCombatLockdown() then
        -- Only an external bottom-inset change needs a later secure update.
        pendingEnchantLayout = true
        PositionWeaponEnchantBars()
        return
    end

    pendingEnchantLayout = false
    container:ClearAllPoints()
    container:SetPoint(
        "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
        Layout.X, Layout.Y + UI:GetBottomInset()
    )
    PositionWeaponEnchantBars()
end

local function RefreshWeaponEnchants()
    if not container then return end
    local entries = ReadWeaponEnchantList()
    local now = GetTime()
    local seen = {}

    for index, entry in ipairs(entries) do
        local button = weaponEnchantBars[index]
        if not button then
            button = CreateWeaponEnchantBar()
            weaponEnchantBars[index] = button
        end

        local key = tostring(entry.inventorySlot) .. ":" .. entry.id
        local expiration = now + entry.remaining
        local timer = weaponEnchantTimers[key]
        if not timer or expiration > timer.expiration + 1 then
            timer = { duration = entry.remaining }
            weaponEnchantTimers[key] = timer
        end
        timer.expiration = expiration
        seen[key] = true

        button.inventorySlot = entry.inventorySlot
        button.expiration = expiration
        button.duration = timer.duration
        button.icon:SetTexture(entry.icon
            or (GetInventoryItemTexture
                and GetInventoryItemTexture("player", entry.inventorySlot)))
        button.nameText:SetText(GetEnchantName(entry))
        button.countText:SetText(entry.charges > 1
            and tostring(entry.charges) or "")
        button.bar:SetMinMaxValues(0, math.max(1, timer.duration))
        button.bar:SetValue(entry.remaining)
        button:Show()
    end

    for key in pairs(weaponEnchantTimers) do
        if not seen[key] then
            weaponEnchantTimers[key] = nil
        end
    end
    for index = #entries + 1, #weaponEnchantBars do
        local button = weaponEnchantBars[index]
        button.inventorySlot = nil
        button.expiration = nil
        button:Hide()
    end

    weaponEnchantCount = #entries
    -- Unlike protected AuraContainer reanchoring, these unprotected rows can
    -- be positioned as soon as an imbue appears/disappears, even in combat.
    PositionWeaponEnchantBars()
end

local function HideBlizzardAuras()
    UI:KeepFrameHidden(BuffFrame)
    UI:KeepFrameHidden(DebuffFrame)
end

local function InitializeAuraButton(button, color, useDispelColor)
    button:SetSize(Layout.WIDTH, Layout.HEIGHT)
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.ICON_SIZE, Layout.ICON_SIZE)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Put the duration bar in its own alpha container. The AuraContainer's
    -- dispel-type binding recolors the status texture with SetVertexColor(),
    -- including an opaque alpha value, so applying alpha directly to the
    -- texture is not stable. Parent alpha survives those secure color updates.
    local barContainer = CreateFrame("Frame", nil, button)
    barContainer:SetSize(Layout.WIDTH - Layout.ICON_SIZE, Layout.HEIGHT)
    barContainer:SetPoint("LEFT", icon, "RIGHT", 0, 0)
    barContainer:SetAlpha(Styles.State.aurasBarAlpha)

    local bar = CreateFrame("StatusBar", nil, barContainer)
    bar:SetAllPoints()
    bar:SetStatusBarTexture(BAR_FACET_TEXTURE)
    bar:SetStatusBarColor(color[1], color[2], color[3], 1)

    local statusTexture = bar:GetStatusBarTexture()

    -- Keep the dark row background outside the alpha container so only the
    -- colored duration fill gets the same transparency as normal buff bars.
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", barContainer, "TOPLEFT")
    background:SetPoint("BOTTOMRIGHT", barContainer, "BOTTOMRIGHT")
    background:SetTexture(BAR_FACET_TEXTURE)
    background:SetVertexColor(
        Palette.auras.background[1],
        Palette.auras.background[2],
        Palette.auras.background[3],
        Styles.State.aurasBackgroundAlpha
    )

    -- Keep text regions outside the duration StatusBar. Once a region is
    -- registered with the AuraContainer API it receives secret/forbidden
    -- aspects, so all visual children must exist before those bindings.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    overlay:EnableMouse(false)

    local nameText = overlay:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameText:SetPoint("RIGHT", bar, "RIGHT", -42, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    local timeText = overlay:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(1, 1, 1)
    timeText:SetShadowColor(0, 0, 0, 1)
    timeText:SetShadowOffset(1, -1)

    local stackText = overlay:CreateFontString(nil, "OVERLAY")
    stackText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    stackText:SetJustifyH("RIGHT")
    stackText:SetTextColor(1, 1, 1)
    stackText:SetShadowColor(0, 0, 0, 1)
    stackText:SetShadowOffset(1, -1)

    local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()
    nameText:SetFont(fontPath, Styles.FontSize.Auras, fontFlags)
    timeText:SetFont(fontPath, Styles.FontSize.Auras, fontFlags)
    stackText:SetFont(fontPath, Styles.FontSize.Auras, "OUTLINE")

    -- Bind only after the complete visual tree exists. Blizzard applies
    -- access restrictions to these objects as part of the binding calls.
    button:SetIcon(icon)
    button:SetDurationBar(bar, {
        direction = Enum.StatusBarTimerDirection.RemainingTime,
        interpolation = Enum.StatusBarInterpolation.Immediate,
    })

    if useDispelColor then
        -- Let Blizzard color the existing duration-bar texture from the aura's
        -- dispel type. This works with secret aura data in combat and gives us
        -- the standard Magic/Curse/Disease/Poison/Bleed/None colors.
        button:AddDispelTypeTexture(statusTexture, {
            showAlways = true,
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        })
    end

    button:SetSpellName(nameText)
    button:SetDurationText(timeText)
    button:SetApplicationCount(stackText)
    button:SetCancelAuraButtons("RightButtonUp")
end

local function CreateAuraContainer()
    local auraContainer = CreateFrame(
        "AuraContainer",
        "KamiUIAuraContainer",
        UIParent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    auraContainer:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        Layout.X,
        Layout.Y + UI:GetBottomInset()
    )

    auraContainer:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
    auraContainer:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
    auraContainer:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Left,
        AnchorUtil.FlowDirection.Up
    )
    auraContainer:SetFlowLayoutMaximumLineSize(math.huge)

    -- Temporary weapon imbues (Rockbiter, Windfury Weapon, rogue poisons,
    -- weapon oils, etc.) are not regular HELPFUL unit auras. Let Blizzard's
    -- AuraContainer own their duration, icon, tooltip and secure cancellation.
    -- This avoids polling secret enchant data ourselves during combat.
    --
    -- The layout grows up from BOTTOMRIGHT: enchantments placed before the
    -- aura groups therefore occupy the first (bottommost) rows.
    if auraContainer.AddItemEnchantment
        and auraContainer.SetItemEnchantmentLayout
    then
        local enchantLayout = {
            layoutIndex = 0,
            elementWidth = Layout.WIDTH,
            elementHeight = Layout.HEIGHT,
            groupSpacing = Layout.GROUP_GAP,
        }

        -- Blizzard defaults to BeforeAuraGroups; pass the explicit placement
        -- when the client exposes its enum.
        if CustomAuraContainerItemEnchantmentPlacement then
            enchantLayout.placement =
                CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups
        end

        auraContainer:SetItemEnchantmentLayout(enchantLayout)

        local slots = AuraContainerItemEnchantmentSlot or {
            MainHand = 0,
            OffHand = 1,
        }

        local function InitializeWeaponEnchant(button)
            InitializeAuraButton(
                button,
                Palette.auras.weaponEnchant,
                false
            )
        end

        -- Register native slots once at creation time, never during combat.
        -- Use the client's official slot enum, including Ranged if present.
        local nativeSlots = {
            { name = "Main Hand", slot = slots.MainHand },
            { name = "Off Hand", slot = slots.OffHand },
            { name = "Ranged", slot = slots.Ranged },
        }
        for _, definition in ipairs(nativeSlots) do
            if definition.slot ~= nil then
                local button = auraContainer:AddItemEnchantment(
                    definition.slot,
                    {
                        initializeFrame = InitializeWeaponEnchant,
                        hidePermanent = false,
                    }
                )
                nativeEnchantButtons[definition.name] = button
                nativeEnchantSlots[definition.name] = definition.slot
            end
        end
    end

    auraContainer:AddAuraGroup("helpful", "HELPFUL", {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, Palette.auras.helpful, false)
        end,
        layout = {
            elementWidth = Layout.WIDTH,
            elementHeight = Layout.HEIGHT,
            layoutIndex = 1,
        },
    })

    auraContainer:AddAuraGroup("harmful", "HARMFUL", {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, Palette.auras.harmful, true)
        end,
        layout = {
            elementWidth = Layout.WIDTH,
            elementHeight = Layout.HEIGHT,
            groupSpacing = Layout.GROUP_GAP,
            layoutIndex = 2,
        },
    })

    -- Match the initialization order used by working 12.1 AuraContainer
    -- implementations: configure groups first, then enable and assign unit.
    auraContainer:SetEnabled(true)
    auraContainer:SetUnit("player")
    auraContainer:UpdateAllAuras()

    return auraContainer
end

function Module:Initialize()
    -- Compare native and Forever-specific weapon enchant sources. When
    -- Blizzard recognizes the enchant, its own AuraContainer should be able
    -- to place it without our independent bars or protected repositioning.
    UI:RegisterCommand("auras", "enchants", function()
        UI:Print("Weapon enchant diagnostics (native test: "
            .. (Module.nativeEnchantTest and "ON" or "OFF") .. "):")
        local sources = GetWeaponEnchantSources()
        if #sources == 0 then
            UI:Print("C_Item.GetWeaponEnchantInfo unavailable")
        end

        for _, source in ipairs(sources) do
            if source.weapon ~= nil then
                local status = {}
                local nativeSlot = nativeEnchantSlots[source.name]
                local nativeButton = nativeEnchantButtons[source.name]

                if nativeSlot ~= nil then
                    status[#status + 1] = "registered"
                    if nativeButton then
                        local ok, shown = pcall(
                            nativeButton.IsShown, nativeButton
                        )
                        if ok and IsReadable(shown)
                            and type(shown) == "boolean"
                        then
                            status[#status + 1] = shown and "shown" or "hidden"
                        else
                            status[#status + 1] = "visibility unknown"
                        end
                    end
                else
                    status[#status + 1] = "not registered"
                end

                if C_PaperDollInfo
                    and C_PaperDollInfo.GetTemporaryEnchantmentInfo
                then
                    local info = UI:SafeCall(
                        C_PaperDollInfo.GetTemporaryEnchantmentInfo,
                        source.inventory
                    )
                    if IsReadableTable(info) then
                        local function Field(key)
                            local v = info[key]
                            if not IsReadable(v) then return "secret" end
                            if v == nil then return "-" end
                            if type(v) == "number"
                                or type(v) == "boolean"
                            then
                                return tostring(v)
                            end
                            return "unknown"
                        end
                        status[#status + 1] = string.format(
                            "native ID=%s time=%sms expires=%s",
                            Field("enchantID"),
                            Field("remainingTimeMs"),
                            Field("hasExpirationTime")
                        )
                    else
                        status[#status + 1] = "native: none/secret"
                    end
                else
                    status[#status + 1] = "native API unavailable"
                end

                local list = C_Item and C_Item.GetWeaponEnchantInfo
                    and UI:SafeCall(
                        C_Item.GetWeaponEnchantInfo, source.weapon
                    )
                local descriptions = {}
                if IsReadableTable(list) then
                    for _, enchant in ipairs(list) do
                        if IsReadableTable(enchant)
                            and IsReadableNumber(enchant.enchantType)
                            and IsReadableNumber(enchant.enchantID)
                            and IsReadableNumber(enchant.timeLeft)
                        then
                            descriptions[#descriptions + 1] = string.format(
                                "type=%d id=%d time=%ds",
                                enchant.enchantType, enchant.enchantID,
                                math.floor(enchant.timeLeft / 1000)
                            )
                        end
                    end
                end
                status[#status + 1] = "Forever: "
                    .. (#descriptions > 0
                        and table.concat(descriptions, ", ")
                        or "none/secret")
                UI:Print(source.name .. ": " .. table.concat(status, " | "))
            end
        end
        UI:Print("KamiUI separate bars: " .. weaponEnchantCount)
    end, "Compare native and Forever weapon enchant APIs")

    UI:RegisterCommand("auras", "native", function()
        if InCombatLockdown and InCombatLockdown() then
            UI:Print("Enable the native enchant test before combat.")
            return
        end
        Module.nativeEnchantTest = true
        RefreshWeaponEnchants()
        UI:Print("Native-only enchant test enabled. Cast Rockbiter and"
            .. " check whether Blizzard shows and reorders it in combat."
            .. " /kami auras auto restores the fallback.")
    end, "Test Blizzard-only weapon enchant rendering")

    UI:RegisterCommand("auras", "auto", function()
        if InCombatLockdown and InCombatLockdown() then
            UI:Print("Restore the normal mode after combat.")
            return
        end
        Module.nativeEnchantTest = false
        RefreshWeaponEnchants()
        UI:Print("Normal weapon enchant fallback restored.")
    end, "Restore standard weapon enchant rendering")

    HideBlizzardAuras()
    container = CreateAuraContainer()
    RefreshWeaponEnchants()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        HideBlizzardAuras()
        RefreshWeaponEnchants()
        UpdatePosition()
    end)

    UI:RegisterEvent("WEAPON_ENCHANT_CHANGED", RefreshWeaponEnchants)
    UI:RegisterEvent("WEAPON_SLOT_CHANGED", RefreshWeaponEnchants)
    UI:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
        if unit == "player" then RefreshWeaponEnchants() end
    end)
    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        RefreshWeaponEnchants()
        if pendingEnchantLayout then UpdatePosition() end
    end)

    UI:RegisterBottomInsetCallback(UpdatePosition)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_BuffFrame" then
            HideBlizzardAuras()
        end
    end)
end

Module:Initialize()
