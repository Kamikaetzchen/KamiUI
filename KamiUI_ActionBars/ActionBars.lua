local UI = KamiUI
local LAB = LibStub("LibActionButton-1.0")

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.2.0"

local defaults = {
    buttonSize = 40,
    secondaryButtonSize = 30,
    buttonSpacing = 0,
    iconZoom = 0.08,
    alpha = 1,
    offsetX = -400,
    offsetY = 0,
}

Module.bottomInset = UI:GetBottomInset()
Module.bars = {}
Module.layoutPending = false
Module.bindingsPending = false
Module.blizzardHiddenFrames = setmetatable({}, { __mode = "k" })

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

local function CreateEdge(parent, pointA, pointB, width, height)
    local edge = parent:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(0, 0, 0, 1)
    edge:SetPoint(pointA, parent, pointA)
    edge:SetPoint(pointB, parent, pointB)

    if width then
        edge:SetWidth(width)
    end

    if height then
        edge:SetHeight(height)
    end

    return edge
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

    button.KamiBorderTop = CreateEdge(
        button,
        "TOPLEFT",
        "TOPRIGHT",
        nil,
        1
    )
    button.KamiBorderBottom = CreateEdge(
        button,
        "BOTTOMLEFT",
        "BOTTOMRIGHT",
        nil,
        1
    )
    button.KamiBorderLeft = CreateEdge(
        button,
        "TOPLEFT",
        "BOTTOMLEFT",
        1,
        nil
    )
    button.KamiBorderRight = CreateEdge(
        button,
        "TOPRIGHT",
        "BOTTOMRIGHT",
        1,
        nil
    )
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
        defaults.iconZoom,
        1 - defaults.iconZoom,
        defaults.iconZoom,
        1 - defaults.iconZoom
    )
end

local function StyleCooldown(cooldown, button)
    if not cooldown then
        return
    end

    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(button)
end

local function FitStateTexture(texture, button)
    if not texture then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
end

local function StyleButton(button, size)
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
    FitStateTexture(
        button.PushedTexture or button:GetPushedTexture(),
        button
    )
    FitStateTexture(
        button.CheckedTexture or button:GetCheckedTexture(),
        button
    )

    StyleIcon(button)
    StyleCooldown(button.cooldown, button)
    StyleCooldown(button.lossOfControlCooldown, button)
    StyleCooldown(button.chargeCooldown, button)
end

local function NewLABConfig(binding)
    return {
        showGrid = false,
        tooltip = "enabled",
        flyoutDirection = "UP",
        actionButtonUI = false,
        spellCastVFX = false,
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
        table.insert(states, "[bonusbar:1,stealth:1]8")
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
            NewLABConfig(string.format(def.binding, index))
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

        StyleButton(
            button,
            def.layout == "primary"
                and defaults.buttonSize
                or defaults.secondaryButtonSize
        )

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
    local y = defaults.offsetY
        + Module.bottomInset
        + ((bar.def.row - 1) * defaults.buttonSize)

    for index = #bar.buttons, 1, -1 do
        local button = bar.buttons[index]
        button:ClearAllPoints()

        if nextButton then
            button:SetPoint(
                "RIGHT",
                nextButton,
                "LEFT",
                -defaults.buttonSpacing,
                0
            )
        else
            button:SetPoint(
                "BOTTOMRIGHT",
                UIParent,
                "BOTTOMRIGHT",
                defaults.offsetX,
                y
            )
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
    frame:SetSize(defaults.secondaryButtonSize * 10, defaults.secondaryButtonSize)

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
        button:SetSize(defaults.secondaryButtonSize, defaults.secondaryButtonSize)

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
            button.AutoCastOverlay:Hide()
        end

        local autoCast = CreateFrame("Frame", nil, button)
        autoCast:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        autoCast:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        autoCast:SetFrameLevel(button:GetFrameLevel() + 5)
        autoCast:Hide()

        local function CreateAutoCastEdge(pointA, pointB, width, height)
            local edge = autoCast:CreateTexture(nil, "OVERLAY")
            edge:SetColorTexture(0.20, 0.55, 1.00, 0.9)
            edge:SetPoint(pointA, autoCast, pointA)
            edge:SetPoint(pointB, autoCast, pointB)

            if width then
                edge:SetWidth(width)
            end

            if height then
                edge:SetHeight(height)
            end
        end

        CreateAutoCastEdge("TOPLEFT", "TOPRIGHT", nil, 1)
        CreateAutoCastEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
        CreateAutoCastEdge("TOPLEFT", "BOTTOMLEFT", 1, nil)
        CreateAutoCastEdge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

        button.KamiAutoCast = autoCast

        StyleButton(button, defaults.secondaryButtonSize)

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
        button.KamiAutoCast:SetShown(
            autoCastAllowed and autoCastEnabled and true or false
        )

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
            "TOPLEFT",
            KamiUIPlayerFrame,
            "BOTTOMLEFT",
            51,
            -2
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

local function CreateStanceBar()
    if Module.stanceBar or not StanceButtonMixin then
        return
    end

    local frame = CreateFrame("Frame", "KamiUIStanceBar", UIParent)
    frame:SetSize(defaults.secondaryButtonSize * 10, defaults.secondaryButtonSize)
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
        button:SetSize(defaults.secondaryButtonSize, defaults.secondaryButtonSize)

        button:SetScript("OnClick", function(self)
            if not KeybindFrames_InQuickKeybindMode() then
                CastShapeshiftForm(self:GetID())
            end
        end)

        StyleButton(button, defaults.secondaryButtonSize)

        frame.buttons[index] = button
    end

    Module.stanceBar = frame
end

local function UpdateStanceBar()
    local frame = Module.stanceBar
    if not frame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        Module.layoutPending = true
        return
    end

    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    local previous

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

            button:ClearAllPoints()
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 0, 0)
            else
                local bar4 = Module.bars[4]
                if bar4 then
                    button:SetPoint(
                        "BOTTOMLEFT",
                        bar4.buttons[1],
                        "TOPLEFT",
                        0,
                        0
                    )
                end
            end

            button:Show()
            previous = button
        else
            button:Hide()
        end
    end

    frame:SetShown(count > 0)

    local bar6 = Module.bars[6]
    if bar6 then
        bar6.frame:SetShown(count == 0)
    end
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

    frame:SetParent(Module.blizzardHider)
    Module.blizzardHiddenFrames[frame] = true
end

local function HideBlizzardBars()
    if InCombatLockdown and InCombatLockdown() then
        Module.layoutPending = true
        return
    end

    if not Module.blizzardHider then
        Module.blizzardHider = CreateFrame("Frame", "KamiUIActionBarHider")
        Module.blizzardHider:Hide()
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
end

local function CreateBars()
    if not next(Module.bars) then
        for _, def in ipairs(BAR_DEFS) do
            CreateActionBar(def)
        end
    end

    CreatePetBar()
    CreateStanceBar()
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

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
        if InCombatLockdown and InCombatLockdown() then
            Module.layoutPending = true
            return
        end

        UpdateStanceBar()
        Module:ReassignBindings()
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        UpdateStanceBar()
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", function()
        UpdateStanceBar()
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", function()
        UpdateStanceBar()
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
