local UI = KamiUI
local Styles = UI.Styles
local LAB = LibStub("LibActionButton-1.0")

local Module = UI:NewModule("ActionBars", "KamiUI_ActionBars")

local Layout = UI.Layout.ActionBars

Module.bottomInset = UI:GetBottomInset()
Module.bars = {}
Module.layoutPending = false
Module.bindingsPending = false
Module.blizzardHiddenFrames = setmetatable({}, { __mode = "k" })
local _, playerClass = UnitClass("player")

local cooldownFont = CreateFont("KamiUIActionBarCooldownFont")
local cooldownFontSmall = CreateFont("KamiUIActionBarCooldownFontSmall")
local cooldownFontPath, _, cooldownFontFlags = GameFontNormalLarge:GetFont()

cooldownFont:SetFont(cooldownFontPath, Styles.FontSize.ActionBars.cooldown, "THICKOUTLINE")
cooldownFont:SetTextColor(1, 1, 1, 1)
cooldownFont:SetShadowColor(0, 0, 0, 1)
cooldownFont:SetShadowOffset(1, -1)

cooldownFontSmall:SetFont(cooldownFontPath, Styles.FontSize.ActionBars.cooldownSmall, "THICKOUTLINE")
cooldownFontSmall:SetTextColor(1, 1, 1, 1)
cooldownFontSmall:SetShadowColor(0, 0, 0, 1)
cooldownFontSmall:SetShadowOffset(1, -1)

local BAR_DEFS = {
    {
        id = 1,
        page = 1,
        count = 12,
        binding = "ACTIONBUTTON%d",
        layout = "primary",
        row = 1,
        paged = true,
    },
    {
        id = 2,
        page = 6,
        count = 12,
        binding = "MULTIACTIONBAR1BUTTON%d",
        layout = "primary",
        row = 2,
    },
    {
        id = 3,
        page = 5,
        count = 12,
        binding = "MULTIACTIONBAR2BUTTON%d",
        layout = "primary",
        row = 3,
    },
    {
        id = 4,
        page = 3,
        count = 12,
        binding = "MULTIACTIONBAR3BUTTON%d",
        layout = "primary",
        row = 4,
    },
    {
        id = 5,
        page = 4,
        count = 12,
        binding = "MULTIACTIONBAR4BUTTON%d",
        layout = "secondaryGrid",
    },
    {
        id = 6,
        page = 13,
        count = 8,
        binding = "MULTIACTIONBAR5BUTTON%d",
        layout = "secondaryRow",
    },
}

local function HideTexture(texture)
    if texture then
        texture:SetAlpha(0)
    end
end

local function CreateButtonChrome(button)
    if button.KamiBackground then
        return
    end

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetDrawLayer("BACKGROUND", -8)
    background:SetAllPoints()
    background:SetColorTexture(0.025, 0.025, 0.025, 0.30)
    button.KamiBackground = background

    Styles:CreateBorder(button, {
        key = "KamiBorder",
        color = { 0, 0, 0, 1 },
    })
end

local function GetButtonIcon(button)
    return button.icon
        or button.Icon
        or _G[button:GetName() .. "Icon"]
end

local function StyleIcon(button)
    local icon = GetButtonIcon(button)
    if not icon then
        return
    end

    if button.IconMask and icon.RemoveMaskTexture then
        icon:RemoveMaskTexture(button.IconMask)
    end

    icon:SetDrawLayer("ARTWORK", 0)
    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    icon:SetTexCoord(
        Layout.ICON_ZOOM,
        1 - Layout.ICON_ZOOM,
        Layout.ICON_ZOOM,
        1 - Layout.ICON_ZOOM
    )
end

local function StyleCooldown(cooldown, button)
    if not cooldown then
        return
    end

    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(button)
    cooldown:SetHideCountdownNumbers(false)

    if cooldown.SetCountdownFont then
        cooldown:SetCountdownFont(
            button:GetWidth() <= Layout.SECONDARY_BUTTON_SIZE
                and "KamiUIActionBarCooldownFontSmall"
                or "KamiUIActionBarCooldownFont"
        )
    end
end

-- Display the GCD above the normal action cooldown. Forever does not
-- provide the GCD through spell 61304, so real action slots are the fallback.
-- Never perform arithmetic on protected cooldown timestamps.
local GCD_SPELL_ID = 61304

local function SetupGCDSwipe(button)
    if button.KamiGCDSwipe then return end

    local swipe = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    swipe:SetAllPoints(button)
    swipe:SetFrameLevel(button:GetFrameLevel() + 5)
    swipe:SetDrawSwipe(true)
    swipe:SetDrawEdge(false)
    swipe:SetDrawBling(false)
    swipe:SetSwipeColor(0, 0, 0, 0.65)
    swipe:SetHideCountdownNumbers(true)
    swipe:EnableMouse(false)
    swipe:Hide()
    button.KamiGCDSwipe = swipe

    -- Spell Metrics draws only font strings at +20, so it remains readable.
    if button.cooldown then
        button.cooldown:SetFrameLevel(button:GetFrameLevel() + 3)
    end
end

-- Only use an actual GCD. Other spells may have much longer
-- cooldowns, which must not be drawn over the entire action bar.
local function ReadGCDCooldown(info, durationObject)
    if not info or info.isActive == false then
        return nil
    end

    local start, seconds
    if UI:CanAccessValue(info.startTime)
        and UI:CanAccessValue(info.duration)
    then
        start, seconds = info.startTime, info.duration
    end

    local shortCooldown = type(start) == "number" and start > 0
        and type(seconds) == "number" and seconds > 0
        and seconds <= 2.5

    if info.isOnGCD == false
        or (info.isOnGCD ~= true and not shortCooldown)
        or (type(seconds) == "number" and seconds > 2.5)
    then
        return nil
    end

    if not durationObject and not shortCooldown then
        return nil
    end

    return true, durationObject, start, seconds
end

local lastCastSpellID

local function GetGCDState()
    -- Blizzard's GCD dummy spell 61304 returns nil on this Forever build.
    -- Keep it for clients where it is implemented, then try real actions.
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        local durationObject = C_Spell.GetSpellCooldownDuration
            and C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID)
        if info and info.isActive == true then
            local start, seconds
            if UI:CanAccessValue(info.startTime)
                and UI:CanAccessValue(info.duration)
            then
                start, seconds = info.startTime, info.duration
            end
            return true, durationObject, start, seconds
        end
    end

    -- A real action's cooldown includes the GCD by default. Prefer the
    -- engine-provided DurationObject, so secret timestamps are never used
    -- for addon-side arithmetic.
    if C_ActionBar and C_ActionBar.GetActionCooldown then
        for _, bar in pairs(Module.bars) do
            for _, button in ipairs(bar.buttons) do
                local slot = button._state_action
                if type(slot) == "number" and UI:CanAccessValue(slot)
                    and slot > 0
                then
                    local info = C_ActionBar.GetActionCooldown(slot)
                    local durationObject
                    if info and C_ActionBar.GetActionCooldownDuration then
                        durationObject =
                            C_ActionBar.GetActionCooldownDuration(slot)
                    end
                    local active, object, start, seconds =
                        ReadGCDCooldown(info, durationObject)
                    if active then
                        return true, object, start, seconds
                    end
                end
            end
        end
    end

    -- A cast need not occupy an action bar slot (e.g. spellbook casting).
    if lastCastSpellID and C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(lastCastSpellID)
        local durationObject = info and C_Spell.GetSpellCooldownDuration
            and C_Spell.GetSpellCooldownDuration(lastCastSpellID)
        local active, object, start, seconds =
            ReadGCDCooldown(info, durationObject)
        if active then
            return true, object, start, seconds
        end
    end

    return false
end

local function UpdateGCDSwipes()
    local active, durationObject, start, seconds = GetGCDState()
    for _, bar in pairs(Module.bars) do
        for _, button in ipairs(bar.buttons) do
            local swipe = button.KamiGCDSwipe
            if swipe then
                if active and durationObject then
                    swipe:SetCooldownFromDurationObject(durationObject, true)
                    swipe:Show()
                elseif active and type(start) == "number"
                    and type(seconds) == "number"
                then
                    -- The cooldown values have already passed access checks.
                    swipe:SetCooldown(start, seconds)
                    swipe:Show()
                else
                    swipe:Clear()
                    swipe:Hide()
                end
            end
        end
    end
end

local function FitStateTexture(texture, button)
    if not texture then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
end

-- Four atlas cells: left end, inner segment, right end, standalone.
-- Only outer corners are chamfered; hotkey/charge corners remain square
-- inside the strip and the strip has no additional surrounding frame.
local function StyleCombatSegment(button, index, count)
    local slot = index == 1 and 0
        or index == count and 2
        or 1

    if button.KamiBorder then
        for _, edge in ipairs(button.KamiBorder) do
            edge:SetAlpha(0)
        end
    end
    if button.KamiBackground then
        button.KamiBackground:SetAlpha(0)
    end

    local icon = GetButtonIcon(button)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end

    local chrome = button:CreateTexture(nil, "OVERLAY", nil, 3)
    chrome:SetAllPoints(button)
    chrome:SetTexture(UI.Media.CombatButtonFrames)
    chrome:SetTexCoord(slot / 4, (slot + 1) / 4, 0, 1)
    button.KamiCombatChrome = chrome

    local font = "Fonts\\FRIZQT__.TTF"
    local hotkey = button.HotKey
    if hotkey then
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        hotkey:SetJustifyH("RIGHT")
        hotkey:SetFont(font, 8, "OUTLINE")
        hotkey:SetShadowColor(0, 0, 0, 1)
        hotkey:SetShadowOffset(1, -1)
    end

    local countText = button.Count
    if countText then
        countText:ClearAllPoints()
        countText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        countText:SetJustifyH("RIGHT")
        countText:SetFont(font, 9, "OUTLINE")
        countText:SetShadowColor(0, 0, 0, 1)
        countText:SetShadowOffset(1, -1)
    end
end

local function StyleButton(button, size, segmentIndex, segmentCount)
    button:SetSize(size, size)

    CreateButtonChrome(button)

    HideTexture(button.NormalTexture or button:GetNormalTexture())
    HideTexture(button.SlotBackground)
    HideTexture(button.SlotArt)
    HideTexture(button.Border)
    HideTexture(button.IconBorder)
    HideTexture(button.NewActionTexture)
    HideTexture(button.SpellHighlightTexture)

    FitStateTexture(
        button.HighlightTexture or button:GetHighlightTexture(),
        button
    )
    local pushed = button.PushedTexture or button:GetPushedTexture()
    FitStateTexture(pushed, button)

    if pushed and pushed.SetAtlas then
        pushed:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", false)
        pushed:SetVertexColor(1, 0.82, 0.20, 1)
    end

    FitStateTexture(
        button.CheckedTexture or button:GetCheckedTexture(),
        button
    )

    StyleIcon(button)
    StyleCooldown(button.cooldown, button)
    -- Preserve the clock-like GCD / spell cooldown animation.
    if button.cooldown then
        button.cooldown:SetDrawSwipe(true)
        button.cooldown:SetSwipeColor(0, 0, 0, 0.65)
    end
    StyleCooldown(button.lossOfControlCooldown, button)
    StyleCooldown(button.chargeCooldown, button)

    if segmentIndex then
        StyleCombatSegment(button, segmentIndex, segmentCount)
    end
end

local function NewLABConfig(binding, isVisible)
    return {
        showGrid = isVisible,
        tooltip = "enabled",
        flyoutDirection = "UP",
        -- These buttons always represent real action slots, including
        -- paged druid/rogue/warrior bars. Register them with Blizzard so
        -- the native cooldown/GCD swipe is driven for every visible action.
        actionButtonUI = true,
        spellCastVFX = false,
        cooldownCount = true,
        keyBoundTarget = binding,
        keyBoundClickButton = "Keybind",
        hideElements = {
            macro = false,
            hotkey = false,
            equipped = true,
            border = true,
            borderIfEmpty = true,
        },
    }
end

local function BuildMainPageDriver()
    local _, class = UnitClass("player")
    local states = {
        "[overridebar][possessbar][shapeshift]possess",
        "[bar:2]2",
        "[bar:3]3",
        "[bar:4]4",
        "[bar:5]5",
        "[bar:6]6",
    }

    if class == "DRUID" then
        table.insert(states, "[bonusbar:1]7")
        table.insert(states, "[bonusbar:3]9")
    elseif class == "ROGUE" then
        table.insert(states, "[bonusbar:1]7")
    elseif class == "WARRIOR" then
        table.insert(states, "[bonusbar:1]7")
        table.insert(states, "[bonusbar:2]8")
        table.insert(states, "[bonusbar:3]9")
    end

    table.insert(states, "1")
    return table.concat(states, ";")
end

local function ConfigurePagedHeader(header)
    header:SetAttribute("_onstate-page", [[
        if newstate == "possess" then
            if HasVehicleActionBar() then
                newstate = GetVehicleBarIndex()
            elseif HasOverrideActionBar() then
                newstate = GetOverrideBarIndex()
            elseif HasTempShapeshiftActionBar() then
                newstate = GetTempShapeshiftBarIndex()
            elseif HasBonusActionBar() then
                newstate = GetBonusBarIndex()
            else
                newstate = 1
            end
        end

        self:SetAttribute("state", newstate)
        control:ChildUpdate("state", newstate)
    ]])

    RegisterStateDriver(header, "page", BuildMainPageDriver())
end

local function CreateActionBar(def)
    local header = CreateFrame(
        "Frame",
        "KamiUIActionBar" .. def.id,
        UIParent,
        "SecureHandlerStateTemplate"
    )
    header:SetSize(1, 1)

    -- Parent alpha leaves secure buttons shown and keyboard-bound while
    -- removing obsolete rows from the visible combat HUD.
    if def.id > Layout.VISIBLE_PRIMARY_BARS then
        header:SetAlpha(0)
    end

    local bar = {
        def = def,
        frame = header,
        buttons = {},
    }

    for index = 1, def.count do
        local name = string.format("KamiUIActionBar%dButton%d", def.id, index)
        local button = LAB:CreateButton(
            def.id * 100 + index,
            name,
            header,
            NewLABConfig(
                string.format(def.binding, index),
                def.id <= Layout.VISIBLE_PRIMARY_BARS
            )
        )

        if def.paged then
            button:SetState(0, "action", index)

            for page = 1, 18 do
                button:SetState(
                    page,
                    "action",
                    (page - 1) * 12 + index
                )
            end
        else
            button:SetState(
                0,
                "action",
                (def.page - 1) * 12 + index
            )
        end

        button:SetAttribute("buttonlock", false)
        button:SetAttribute("unlockedpreventdrag", true)

        local size = def.id == 1 and Layout.BUTTON_SIZE
            or def.id == 2 and Layout.SECOND_ROW_BUTTON_SIZE
            or def.layout == "primary" and Layout.BUTTON_SIZE
            or Layout.SECONDARY_BUTTON_SIZE
        StyleButton(
            button,
            size,
            def.id <= Layout.VISIBLE_PRIMARY_BARS and index or nil,
            def.count
        )
        if def.id > Layout.VISIBLE_PRIMARY_BARS then
            button:EnableMouse(false)
        end
        SetupGCDSwipe(button)

        -- StyleButton must not force empty LAB buttons visible.
        button:UpdateAction(true)

        bar.buttons[index] = button
    end

    if def.paged then
        ConfigurePagedHeader(header)
    end

    Module.bars[def.id] = bar
    return bar
end

local function LayoutPrimaryBar(bar)
    local nextButton
    local isMain = bar.def.id == 1
    local isSecond = bar.def.id == 2
    local y = Layout.OFFSET_Y + Module.bottomInset
    if isMain then
        y = y + Layout.SECOND_ROW_BUTTON_SIZE + Layout.BAR_GAP
    elseif not isSecond then
        y = y + ((bar.def.row - 1) * Layout.BUTTON_SIZE)
    end

    for index = #bar.buttons, 1, -1 do
        local button = bar.buttons[index]
        button:ClearAllPoints()

        if nextButton then
            button:SetPoint(
                "RIGHT",
                nextButton,
                "LEFT",
                -Layout.BUTTON_SPACING,
                0
            )
        elseif isMain or isSecond then
            local width = #bar.buttons * button:GetWidth()
                + (#bar.buttons - 1) * Layout.BUTTON_SPACING
            button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM",
                width / 2, y)
        else
            button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
                Layout.OFFSET_X, y)
        end

        nextButton = button
    end
end

local function LayoutBar5(bar)
    local bar4 = Module.bars[4]
    if not bar4 then
        return
    end

    local bar4Right = bar4.buttons[12]

    for row = 1, 2 do
        local rightIndex = row * 6
        local nextButton

        for index = rightIndex, rightIndex - 5, -1 do
            local button = bar.buttons[index]
            button:ClearAllPoints()

            if nextButton then
                button:SetPoint("RIGHT", nextButton, "LEFT", 0, 0)
            elseif row == 1 then
                button:SetPoint(
                    "BOTTOMRIGHT",
                    bar4Right,
                    "TOPRIGHT",
                    0,
                    0
                )
            else
                button:SetPoint(
                    "BOTTOMRIGHT",
                    bar.buttons[6],
                    "TOPRIGHT",
                    0,
                    0
                )
            end

            nextButton = button
        end
    end
end

local function LayoutBar6(bar)
    local bar4 = Module.bars[4]
    if not bar4 then
        return
    end

    local previous
    local bar4Left = bar4.buttons[1]

    for index, button in ipairs(bar.buttons) do
        button:ClearAllPoints()

        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            button:SetPoint(
                "BOTTOMLEFT",
                bar4Left,
                "TOPLEFT",
                0,
                0
            )
        end

        previous = button
    end
end

local function CreatePetBar()
    if Module.petBar or not PetActionButtonMixin then
        return
    end

    local frame = CreateFrame(
        "Frame",
        "KamiUIPetActionBar",
        UIParent,
        "SecureHandlerStateTemplate"
    )
    frame:SetSize(Layout.SECONDARY_BUTTON_SIZE * 10, Layout.SECONDARY_BUTTON_SIZE)

    local buttons = {}

    for index = 1, 10 do
        local button = CreateFrame(
            "CheckButton",
            "KamiUIPetActionButton" .. index,
            frame,
            "PetActionButtonTemplate"
        )
        button:SetID(index)
        button.index = index
        button:SetSize(Layout.SECONDARY_BUTTON_SIZE, Layout.SECONDARY_BUTTON_SIZE)

        button:SetScript("OnDragStart", function(self)
            if InCombatLockdown and InCombatLockdown() then
                return
            end

            if not Settings.GetValue("lockActionBars")
                or IsModifiedClick("PICKUPACTION")
            then
                self:SetChecked(false)
                PickupPetAction(self:GetID())
            end
        end)

        button:SetScript("OnReceiveDrag", function(self)
            if InCombatLockdown and InCombatLockdown() then
                return
            end

            if GetCursorInfo() == "petaction" then
                self:SetChecked(false)
                PickupPetAction(self:GetID())
            end
        end)

        if button.AutoCastOverlay then
            local autoCast = button.AutoCastOverlay
            autoCast:ClearAllPoints()
            autoCast:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            autoCast:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            autoCast:SetFrameLevel(button:GetFrameLevel() + 5)

            if autoCast.Shine then
                autoCast.Shine:ClearAllPoints()
                autoCast.Shine:SetPoint(
                    "TOPLEFT",
                    autoCast,
                    "TOPLEFT",
                    -4,
                    4
                )
                autoCast.Shine:SetPoint(
                    "BOTTOMRIGHT",
                    autoCast,
                    "BOTTOMRIGHT",
                    4,
                    -4
                )
            end

            if autoCast.Mask then
                autoCast.Mask:ClearAllPoints()
                autoCast.Mask:SetPoint(
                    "TOPLEFT",
                    autoCast,
                    "TOPLEFT",
                    2,
                    -2
                )
                autoCast.Mask:SetPoint(
                    "BOTTOMRIGHT",
                    autoCast,
                    "BOTTOMRIGHT",
                    -2,
                    2
                )
            end

            if autoCast.Corners then
                autoCast.Corners:ClearAllPoints()
                autoCast.Corners:SetAllPoints(autoCast)
            end

            autoCast:Hide()
        end

        StyleButton(button, Layout.SECONDARY_BUTTON_SIZE)

        local checked = button.CheckedTexture or button:GetCheckedTexture()
        if checked then
            checked:ClearAllPoints()
            checked:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
            checked:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        end

        if index == 1 then
            button:SetPoint("LEFT", frame, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", buttons[index - 1], "RIGHT", 0, 0)
        end

        buttons[index] = button
    end

    frame.buttons = buttons
    RegisterStateDriver(frame, "visibility", "[nopet]hide;show")

    Module.petBar = frame
end

local function UpdatePetBar()
    local frame = Module.petBar
    if not frame then
        return
    end

    for index, button in ipairs(frame.buttons) do
        local name, texture, isToken, isActive, autoCastAllowed,
            autoCastEnabled = GetPetActionInfo(index)

        if isToken then
            button.icon:SetTexture(texture and _G[texture])
            button.tooltipName = name and _G[name]
        else
            button.icon:SetTexture(texture)
            button.tooltipName = name
        end

        button.icon:SetShown(texture ~= nil)
        button:SetChecked(isActive and true or false)
        if button.AutoCastOverlay then
            button.AutoCastOverlay:SetShown(autoCastAllowed and true or false)
            button.AutoCastOverlay:ShowAutoCastEnabled(
                autoCastEnabled and true or false
            )
        end

        if texture then
            local usable = not GetPetActionSlotUsable
                or GetPetActionSlotUsable(index)
            button.icon:SetVertexColor(
                usable and 1 or 0.4,
                usable and 1 or 0.4,
                usable and 1 or 0.4
            )
        end

        local start, duration, enable = GetPetActionCooldown(index)
        CooldownFrame_Set(button.cooldown, start, duration, enable)
    end
end

local function LayoutPetBar()
    if not Module.petBar then
        return
    end

    Module.petBar:ClearAllPoints()

    if KamiUIPlayerFrame then
        Module.petBar:SetPoint(
            "BOTTOMRIGHT",
            KamiUIPlayerFrame,
            "BOTTOMLEFT",
            -6,
            0
        )
    else
        Module.petBar:SetPoint(
            "TOP",
            UIParent,
            "CENTER",
            0,
            -260
        )
    end
end

-- Forever ships the Wrath-style MultiCast bar. Reuse its native buttons,
-- pages, flyouts and secure casting rather than recreating totem actions.
-- Blizzard's default parent (MainMenuBar) is hidden by KamiUI, so the
-- native bar must be detached before it can appear.
local function CreateTotemBar()
    if playerClass ~= "SHAMAN" or Module.totemBar then return end
    local native = MultiCastActionBarFrame
    if not native or not MultiCastSummonSpellButton
        or not MultiCastRecallSpellButton then
        return
    end

    native:SetParent(UIParent)
    -- The legacy slide script continuously restores the MainMenuBar anchor.
    -- Leave its event handlers and native secure click scripts intact.
    native:SetScript("OnUpdate", nil)
    -- Older clients use OnShow/OnHide only to reposition the default
    -- action bar. Do not suppress different handlers from newer clients.
    if UIParent_ManageFramePositions then
        if native:GetScript("OnShow") == UIParent_ManageFramePositions then
            native:SetScript("OnShow", nil)
        end
        if native:GetScript("OnHide") == UIParent_ManageFramePositions then
            native:SetScript("OnHide", nil)
        end
    end
    Module.totemBar = native

    local function StyleNative(button)
        if not button or button.KamiTotemStyled then return end
        button.KamiTotemStyled = true
        StyleButton(button, Layout.SECONDARY_BUTTON_SIZE)
        HideTexture(button.overlayTex)
        HideTexture(button.Overlay)
    end

    StyleNative(MultiCastSummonSpellButton)
    StyleNative(MultiCastRecallSpellButton)
    for index = 1, 12 do
        StyleNative(_G["MultiCastActionButton" .. index])
    end
    for index = 1, 4 do
        local slot = _G["MultiCastSlotButton" .. index]
        if slot and not slot.KamiTotemStyled then
            slot.KamiTotemStyled = true
            slot:SetSize(Layout.SECONDARY_BUTTON_SIZE,
                Layout.SECONDARY_BUTTON_SIZE)
            CreateButtonChrome(slot)
            HideTexture(slot.overlay)
            -- The slot's native background is visible when no totem is
            -- selected. Keep that indicator and Blizzard's flyout handling.
        end
    end
end

local function LayoutTotemBar()
    local native = Module.totemBar
    local bar4 = Module.bars[4]
    if not native or not bar4 then return end
    local size = Layout.SECONDARY_BUTTON_SIZE

    native:ClearAllPoints()
    native:SetSize(size * 6, size)
    local main = Module.bars[1]
    if main then
        native:SetPoint("BOTTOMRIGHT", main.buttons[1],
            "TOPLEFT", -8, 0)
    end

    -- F1-F4: totems; F5: Recall; F6: Call (with Blizzard's set flyout).
    for index = 1, 4 do
        local slot = _G["MultiCastSlotButton" .. index]
        if slot then
            slot:ClearAllPoints()
            slot:SetPoint("BOTTOMLEFT", native, "BOTTOMLEFT",
                size * (index - 1), 0)
        end
    end

    for page = 1, 3 do
        local pageFrame = _G["MultiCastActionPage" .. page]
        if pageFrame then
            pageFrame:ClearAllPoints()
            pageFrame:SetSize(size * 4, size)
            pageFrame:SetPoint("BOTTOMLEFT", native, "BOTTOMLEFT",
                0, 0)
        end
        for slot = 1, 4 do
            local button = _G["MultiCastActionButton" ..
                ((page - 1) * 4 + slot)]
            if button and pageFrame then
                button:ClearAllPoints()
                button:SetPoint("BOTTOMLEFT", pageFrame,
                    "BOTTOMLEFT", (slot - 1) * size, 0)
            end
        end
    end

    MultiCastRecallSpellButton:ClearAllPoints()
    MultiCastRecallSpellButton:SetPoint("BOTTOMLEFT",
        native, "BOTTOMLEFT", size * 4, 0)

    MultiCastSummonSpellButton:ClearAllPoints()
    MultiCastSummonSpellButton:SetPoint("BOTTOMLEFT",
        native, "BOTTOMLEFT", size * 5, 0)
end

local function TotemBarAvailable()
    if not Module.totemBar then return false end
    if HasMultiCastActionBar then
        return HasMultiCastActionBar() and true or false
    end
    return (Module.totemBar.numActiveSlots or 0) > 0
end

local function CreateStanceBar()
    if Module.stanceBar or not StanceButtonMixin then
        return
    end

    local frame = CreateFrame("Frame", "KamiUIStanceBar", UIParent)
    frame:SetSize(Layout.SECONDARY_BUTTON_SIZE * 10, Layout.SECONDARY_BUTTON_SIZE)
    frame.buttons = {}

    for index = 1, 10 do
        local button = CreateFrame(
            "CheckButton",
            "KamiUIStanceButton" .. index,
            frame,
            "StanceButtonTemplate"
        )
        button:SetID(index)
        button.index = index
        button:SetSize(Layout.SECONDARY_BUTTON_SIZE, Layout.SECONDARY_BUTTON_SIZE)

        -- Keep Blizzard's inherited StanceButtonTemplate click handler.
        -- Replacing it with addon Lua taints CastShapeshiftForm.
        StyleButton(button, Layout.SECONDARY_BUTTON_SIZE)

        frame.buttons[index] = button
    end

    Module.stanceBar = frame
end

local function UpdateStanceState()
    local frame = Module.stanceBar
    if not frame then
        return
    end

    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0

    -- These are visual state updates only. Blizzard updates the same properties
    -- on StanceButtonTemplate in combat, so keep them separate from protected
    -- layout/show/hide changes.
    for index, button in ipairs(frame.buttons) do
        if index <= count then
            local texture, isActive, isCastable = GetShapeshiftFormInfo(index)

            button.icon:SetTexture(texture)
            button.icon:SetShown(texture ~= nil)
            button.icon:SetVertexColor(
                isCastable and 1 or 0.4,
                isCastable and 1 or 0.4,
                isCastable and 1 or 0.4
            )
            button:SetChecked(isActive and true or false)

            local start, duration, enable = GetShapeshiftFormCooldown(index)
            CooldownFrame_Set(button.cooldown, start, duration, enable)
        end
    end
end

local function UpdateStanceBar()
    local frame = Module.stanceBar
    if not frame then
        return
    end

    UpdateStanceState()

    if InCombatLockdown and InCombatLockdown() then
        Module.layoutPending = true
        return
    end

    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    local previous

    for index, button in ipairs(frame.buttons) do
        if index <= count then
            button:ClearAllPoints()
            if previous then
                button:SetPoint("RIGHT", previous, "LEFT", 0, 0)
            else
                local bar4 = Module.bars[4]
                if bar4 then
                    local main = Module.bars[1]
                    if main then
                        button:SetPoint(
                            "BOTTOMRIGHT", main.buttons[1],
                            "TOPLEFT", -8, 0
                        )
                    end
                end
            end

            button:Show()
            previous = button
        else
            button:Hide()
        end
    end

    local totems = count == 0 and playerClass == "SHAMAN"
        and TotemBarAvailable()
    frame:SetShown(count > 0)

    local bar6 = Module.bars[6]
    if bar6 then
        bar6.frame:SetShown(count == 0 and not totems)
    end
    if Module.totemBar then
        Module.totemBar:SetShown(totems)
    end
    Module.secondaryMode = count > 0 and "stance"
        or totems and "totem" or "bar6"
end

local function LayoutBars()
    for _, bar in pairs(Module.bars) do
        if bar.def.layout == "primary" then
            LayoutPrimaryBar(bar)
        elseif bar.def.layout == "secondaryGrid" then
            LayoutBar5(bar)
        elseif bar.def.layout == "secondaryRow" then
            LayoutBar6(bar)
        end
    end

    LayoutPetBar()
    LayoutTotemBar()
    UpdateStanceBar()
end

local function PurgeSecureKey(frame, key)
    if not frame or not issecurevariable then
        return
    end

    frame[key] = nil
    local index = 42

    while not issecurevariable(frame, key) do
        frame[index] = nil
        index = index + 1
    end
end

local function HideBlizzardFrame(frame, clearEvents)
    if not frame or Module.blizzardHiddenFrames[frame] then
        return
    end

    if clearEvents then
        frame:UnregisterAllEvents()
    end

    if frame.system then
        PurgeSecureKey(frame, "isShownExternal")
    end

    if frame.HideBase then
        frame:HideBase()
    else
        frame:Hide()
    end

    UI:KeepFrameHidden(frame)
    Module.blizzardHiddenFrames[frame] = true
end

local function HideBlizzardBars()
    if InCombatLockdown and InCombatLockdown() then
        Module.layoutPending = true
        return
    end

    HideBlizzardFrame(MainActionBar, false)
    HideBlizzardFrame(MultiBarBottomLeft, true)
    HideBlizzardFrame(MultiBarBottomRight, true)
    HideBlizzardFrame(MultiBarRight, true)
    HideBlizzardFrame(MultiBarLeft, true)
    HideBlizzardFrame(MultiBar5, true)
    HideBlizzardFrame(MultiBar6, true)
    HideBlizzardFrame(MultiBar7, true)
    if Module.stanceBar then
        HideBlizzardFrame(StanceBar, true)
    end

    if Module.petBar then
        HideBlizzardFrame(PetActionBar, true)
    end

    HideBlizzardFrame(MicroButtonAndBagsBar, false)
    HideBlizzardFrame(MicroMenuContainer, true)
    HideBlizzardFrame(MicroMenu, true)
    HideBlizzardFrame(BagsBar, true)
end

-- These F-keys belong to whichever bar currently occupies the shared
-- secondary position. A single owner avoids conflicts between hidden bars.
-- Priority is intentional: F1 normally targets the player in WoW.
local function LabelFunctionKey(button, index)
    if not button or button.KamiFunctionKey then return end
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    label:SetTextColor(1, 1, 1)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -1)
    label:SetText("F" .. index)
    button.KamiFunctionKey = label
end

local function LabelSecondaryBarButtons()
    local bar6 = Module.bars[6]
    if bar6 then
        for index, button in ipairs(bar6.buttons) do
            LabelFunctionKey(button, index)
        end
    end
    if Module.stanceBar then
        for index = 1, 8 do
            LabelFunctionKey(Module.stanceBar.buttons[index], index)
        end
    end
    if Module.totemBar then
        LabelFunctionKey(MultiCastRecallSpellButton, 5)
        LabelFunctionKey(MultiCastSummonSpellButton, 6)
        for page = 1, 3 do
            for index = 1, 4 do
                LabelFunctionKey(_G["MultiCastActionButton" ..
                    ((page - 1) * 4 + index)], index)
            end
        end
    end
end

local function BindFunctionKeys()
    local owner = Module.functionKeyOwner
    if not owner then return end
    ClearOverrideBindings(owner)

    local mode = Module.secondaryMode
    if mode == "totem" then
        local native = Module.totemBar
        local page = native and native.currentPage or 1
        if type(page) ~= "number" then page = 1 end
        local names = {
            "MultiCastActionButton" .. ((page - 1) * 4 + 1),
            "MultiCastActionButton" .. ((page - 1) * 4 + 2),
            "MultiCastActionButton" .. ((page - 1) * 4 + 3),
            "MultiCastActionButton" .. ((page - 1) * 4 + 4),
            "MultiCastRecallSpellButton",
            "MultiCastSummonSpellButton",
        }
        for index, name in ipairs(names) do
            if _G[name] then
                SetOverrideBindingClick(owner, true, "F" .. index,
                    name, "LeftButton")
            end
        end
    else
        local buttons = mode == "stance"
            and Module.stanceBar and Module.stanceBar.buttons
            or Module.bars[6] and Module.bars[6].buttons
        local count = mode == "stance"
            and (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0)
            or 8
        if buttons then
            for index = 1, math.min(8, count) do
                local button = buttons[index]
                if button then
                    SetOverrideBindingClick(owner, true, "F" .. index,
                        button:GetName(),
                        mode == "stance" and "LeftButton" or "Keybind")
                end
            end
        end
    end
end

local function BindFrameButtons(owner, buttons, bindingPattern, clickButton)
    ClearOverrideBindings(owner)

    for index, button in ipairs(buttons) do
        local binding = string.format(bindingPattern, index)

        for keyIndex = 1, select("#", GetBindingKey(binding)) do
            local key = select(keyIndex, GetBindingKey(binding))

            if key and key ~= "" then
                SetOverrideBindingClick(
                    owner,
                    false,
                    key,
                    button:GetName(),
                    clickButton
                )
            end
        end
    end
end

function Module:ReassignBindings()
    if InCombatLockdown and InCombatLockdown() then
        self.bindingsPending = true
        return
    end

    self.bindingsPending = false

    for _, def in ipairs(BAR_DEFS) do
        local bar = self.bars[def.id]

        if bar then
            BindFrameButtons(
                bar.frame,
                bar.buttons,
                def.binding,
                "Keybind"
            )
        end
    end

    if self.petBar then
        BindFrameButtons(
            self.petBar,
            self.petBar.buttons,
            "BONUSACTIONBUTTON%d",
            "LeftButton"
        )
    end

    if self.stanceBar then
        BindFrameButtons(
            self.stanceBar,
            self.stanceBar.buttons,
            "SHAPESHIFTBUTTON%d",
            "LeftButton"
        )
    end

    BindFunctionKeys()
end

local function CreateBars()
    if not next(Module.bars) then
        for _, def in ipairs(BAR_DEFS) do
            CreateActionBar(def)
        end
    end

    CreatePetBar()
    CreateStanceBar()
    CreateTotemBar()
    LabelSecondaryBarButtons()
    if not Module.functionKeyOwner then
        Module.functionKeyOwner = CreateFrame(
            "Frame", "KamiUISecondaryFunctionKeys", UIParent)
    end
end

function Module:Apply()
    if InCombatLockdown and InCombatLockdown() then
        self.layoutPending = true
        return
    end

    self.layoutPending = false

    CreateBars()
    LayoutBars()
    HideBlizzardBars()
    UpdatePetBar()
    self:ReassignBindings()
    UpdateGCDSwipes()
end

function Module:Initialize()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("UPDATE_BINDINGS", function()
        Module:ReassignBindings()
    end)

    -- Refresh on cooldown changes and shortly after a successful cast;
    -- spell cooldown information can lag the cast event by a frame.
    UI:RegisterEvent("SPELL_UPDATE_COOLDOWN", UpdateGCDSwipes)
    UI:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", UpdateGCDSwipes)
    UI:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit == "player" then
            if type(spellID) == "number"
                and UI:CanAccessValue(spellID)
            then
                lastCastSpellID = spellID
            end
            UpdateGCDSwipes()
            C_Timer.After(0.06, UpdateGCDSwipes)
            C_Timer.After(0.16, UpdateGCDSwipes)
        end
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
        UpdateStanceState()

        if InCombatLockdown and InCombatLockdown() then
            Module.layoutPending = true
            return
        end

        UpdateStanceBar()
        Module:ReassignBindings()
    end)

    -- A learned Call spell unlocks the native bar; a changed totem set
    -- swaps the four page buttons. Relayout/rebind only out of combat.
    local function QueueTotemRefresh()
        if playerClass ~= "SHAMAN" then return end
        if Module.totemRefreshQueued then return end
        Module.totemRefreshQueued = true
        C_Timer.After(0, function()
            Module.totemRefreshQueued = false
            if InCombatLockdown and InCombatLockdown() then
                Module.layoutPending = true
            else
                Module:Apply()
            end
        end)
    end

    if playerClass == "SHAMAN" then
        UI:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR", QueueTotemRefresh)
        UI:RegisterEvent("SPELLS_CHANGED", QueueTotemRefresh)
        if ChangeMultiCastActionPage then
            hooksecurefunc("ChangeMultiCastActionPage", QueueTotemRefresh)
        end
    end

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        UpdateStanceState()
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", function()
        UpdateStanceState()
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", function()
        UpdateStanceState()
    end)

    for _, event in ipairs({
        "PLAYER_CONTROL_LOST",
        "PLAYER_CONTROL_GAINED",
        "PLAYER_FARSIGHT_FOCUS_CHANGED",
        "PET_BAR_UPDATE",
        "PET_BAR_UPDATE_COOLDOWN",
        "PET_BAR_UPDATE_USABLE",
        "PET_UI_UPDATE",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_MOUNT_DISPLAY_CHANGED",
    }) do
        UI:RegisterEvent(event, UpdatePetBar)
    end

    UI:RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then
            UpdatePetBar()
        end
    end)

    UI:RegisterEvent("UNIT_FLAGS", function(_, unit)
        if unit == "pet" then
            UpdatePetBar()
        end
    end)

    UI:RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "pet" then
            UpdatePetBar()
        end
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_ActionBar"
            or addonName == "Blizzard_EditMode"
            or addonName == "Blizzard_MicroMenu"
            or addonName == "Blizzard_MainMenuBarBagButtons"
        then
            C_Timer.After(0, function()
                Module:Apply()
            end)
        end
    end)

    UI:RegisterBottomInsetCallback(function(inset)
        Module.bottomInset = inset

        if InCombatLockdown and InCombatLockdown() then
            Module.layoutPending = true
            return
        end

        LayoutBars()
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.layoutPending then
            Module:Apply()
        elseif Module.bindingsPending then
            Module:ReassignBindings()
        end
    end)
end

Module:Initialize()
