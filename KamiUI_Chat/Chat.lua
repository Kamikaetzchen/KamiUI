local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Chat", "KamiUI_Chat")


local SETUP_VERSION = 4

local defaults = {
    leftWidth = 500,
    combatWidth = 450,
    height = 220,
    tabHeight = 22,
    inputHeight = 24,
    fontSize = 14,
    padding = 4,
    x = 0,
    y = 0,
}

local leftTabs = {
    { key = "general", label = "General" },
    { key = "party", label = "Party" },
    { key = "guild", label = "Guild" },
    { key = "whisper", label = "Whisper" },
}

local managedWindows = {
    general = {
        name = "Kami General",
        cloneDefault = true,
    },
    party = {
        name = "Party",
        groups = {
            "PARTY",
            "PARTY_LEADER",
            "RAID",
            "RAID_LEADER",
            "RAID_WARNING",
            "INSTANCE_CHAT",
            "INSTANCE_CHAT_LEADER",
            "BATTLEGROUND",
            "BATTLEGROUND_LEADER",
        },
    },
    guild = {
        name = "Guild",
        groups = {
            "GUILD",
            "OFFICER",
        },
    },
    whisper = {
        name = "Whisper",
        groups = {
            "WHISPER",
            "BN_WHISPER",
        },
        privateMessages = true,
    },
}

local function GetBottom()
    return defaults.y + UI:GetBottomInset()
end

local function HideRegion(region)
    if region then
        Styles:HideRegion(region)
        region:Hide()
    end
end

local function HideFrame(frame)
    if frame then
        UI:KeepFrameHidden(frame)
    end
end

local function HideChromeObject(object)
    if not object then
        return
    end

    if object:IsObjectType("Frame") then
        HideFrame(object)
    else
        HideRegion(object)
    end
end

local function CreatePanel(name, width, height)
    local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    panel:SetFrameStrata("LOW")
    panel:SetSize(width, height)
    Styles:ApplyBackdrop(
        panel,
        Palette.window.chat,
        Palette.windowBorder.chat
    )
    panel:EnableMouse(false)

    return panel
end

local function EnsurePanels()
    if not Module.leftPanel then
        Module.leftPanel = CreatePanel(
            "KamiUIChatPanel",
            defaults.leftWidth,
            defaults.height
        )
    end

    if not Module.combatPanel then
        Module.combatPanel = CreatePanel(
            "KamiUICombatLogPanel",
            defaults.combatWidth,
            defaults.height
        )
    end

    if not Module.tabPanel then
        Module.tabPanel = CreateFrame(
            "Frame",
            "KamiUIChatTabPanel",
            UIParent
        )
        Module.tabPanel:SetSize(defaults.leftWidth, defaults.tabHeight)
        Module.tabPanel:SetFrameStrata("DIALOG")
        Module.tabPanel:SetFrameLevel(100)
    end

    if not Module.inputPanel then
        Module.inputPanel = CreatePanel(
            "KamiUIChatInputPanel",
            defaults.leftWidth,
            defaults.inputHeight
        )
        Module.inputPanel:SetFrameStrata("DIALOG")
        Module.inputPanel:Hide()
    end

end

local function PositionPanels()
    local bottom = GetBottom()

    Module.leftPanel:ClearAllPoints()
    Module.leftPanel:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        defaults.x,
        bottom
    )

    Module.combatPanel:ClearAllPoints()
    Module.combatPanel:SetPoint(
        "BOTTOMLEFT",
        Module.leftPanel,
        "BOTTOMRIGHT",
        0,
        0
    )

    Module.tabPanel:ClearAllPoints()
    Module.tabPanel:SetPoint(
        "BOTTOMLEFT",
        Module.leftPanel,
        "TOPLEFT",
        0,
        0
    )

    Module.inputPanel:ClearAllPoints()
    Module.inputPanel:SetPoint(
        "BOTTOMLEFT",
        Module.leftPanel,
        "TOPLEFT",
        0,
        defaults.tabHeight
    )
end

local function CreateTab(index, config)
    local button = CreateFrame(
        "Button",
        "KamiUIChatTab" .. index,
        Module.tabPanel
    )

    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(Module.tabPanel:GetFrameLevel() + 1)
    button:SetSize(defaults.leftWidth / #leftTabs, defaults.tabHeight)
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetText(config.label)

    Components:StyleTab(button, {
        orientation = "top",
        joinLeft = index > 1,
    })

    button.key = config.key
    button:SetScript("OnClick", function(self)
        Module:SelectTab(self.key)
    end)

    Module.tabs[config.key] = button
end

local function EnsureTabs()
    if next(Module.tabs) then
        return
    end

    for index, config in ipairs(leftTabs) do
        CreateTab(index, config)
    end
end

local function PositionTabs()
    local previous

    for _, config in ipairs(leftTabs) do
        local tab = Module.tabs[config.key]
        tab:ClearAllPoints()

        if previous then
            tab:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", 0, 0)
        else
            tab:SetPoint(
                "BOTTOMLEFT",
                Module.tabPanel,
                "BOTTOMLEFT",
                0,
                0
            )
        end

        previous = tab
    end
end

local function UpdateTabStyles()
    for _, config in ipairs(leftTabs) do
        local tab = Module.tabs[config.key]
        local active = config.key == Module.selectedTab

        Components:SetTabState(tab, active, true)
    end
end

local function FindChatWindow(name)
    for index = 3, NUM_CHAT_WINDOWS do
        local windowName = FCF_GetChatWindowInfo(index)

        if windowName == name then
            return _G["ChatFrame" .. index]
        end
    end
end

local function RemoveAllMessageGroups(frame)
    if frame.RemoveAllMessageGroups then
        frame:RemoveAllMessageGroups()
    else
        ChatFrame_RemoveAllMessageGroups(frame)
    end
end

local function RemoveAllChannels(frame)
    if frame.RemoveAllChannels then
        frame:RemoveAllChannels()
    else
        ChatFrame_RemoveAllChannels(frame)
    end
end

local function AddMessageGroup(frame, group)
    if ChatTypeGroup and not ChatTypeGroup[group] then
        return
    end

    if frame.AddMessageGroup then
        frame:AddMessageGroup(group)
    else
        ChatFrame_AddMessageGroup(frame, group)
    end
end

local function AddChannel(frame, channel)
    if not channel or channel == "" then
        return
    end

    if frame.AddChannel then
        frame:AddChannel(channel)
    elseif ChatFrame_AddChannel then
        ChatFrame_AddChannel(frame, channel)
    end
end

local function ConfigureWindow(frame, config)
    RemoveAllMessageGroups(frame)
    RemoveAllChannels(frame)

    if config.cloneDefault and ChatFrame1 then
        for _, group in pairs(ChatFrame1.messageTypeList or {}) do
            AddMessageGroup(frame, group)
        end

        for _, channel in pairs(ChatFrame1.channelList or {}) do
            AddChannel(frame, channel)
        end
    else
        for _, group in ipairs(config.groups or {}) do
            AddMessageGroup(frame, group)
        end
    end

    if config.privateMessages and frame.ReceiveAllPrivateMessages then
        frame:ReceiveAllPrivateMessages()
    elseif config.privateMessages and ChatFrame_ReceiveAllPrivateMessages then
        ChatFrame_ReceiveAllPrivateMessages(frame)
    end

    if frame.isDocked and FCF_UnDockFrame then
        FCF_UnDockFrame(frame)
    end

    FCF_SetLocked(frame, true)
    frame:Show()

    return frame
end

local function EnsureWindow(config)
    local frame = FindChatWindow(config.name)

    if not frame then
        if securecallfunction then
            frame = securecallfunction(
                FCF_OpenNewWindow,
                config.name,
                true
            )
        else
            frame = FCF_OpenNewWindow(config.name, true)
        end
    end

    if not frame then
        return
    end

    return ConfigureWindow(frame, config)
end

local function HideEditBoxDecorations(editBox)
    if not editBox then
        return
    end

    local name = editBox:GetName()

    if name then
        for _, suffix in ipairs({
            "Left",
            "Right",
            "Mid",
            "FocusLeft",
            "FocusRight",
            "FocusMid",
            "Header",
            "HeaderSuffix",
            "NewcomerHint",
            "Prompt",
            "Language",
        }) do
            HideChromeObject(_G[name .. suffix])
        end
    end

    HideChromeObject(editBox.header)
    HideChromeObject(editBox.headerSuffix)
    HideChromeObject(editBox.languageHeader)
    HideChromeObject(editBox.NewcomerHint)
    HideChromeObject(editBox.prompt)
end

local function ApplyEditBoxInsets(editBox)
    if editBox and editBox.SetTextInsets then
        editBox:SetTextInsets(
            defaults.padding,
            defaults.padding,
            0,
            0
        )
    end
end

local function StyleInputEditBox()
    local editBox = ChatFrame1 and ChatFrame1.editBox

    if not editBox or not Module.inputPanel then
        return
    end

    Module.inputEditBox = editBox

    if editBox.SetParent then
        editBox:SetParent(UIParent)
    end

    if not editBox.KamiUIInsetHooked
        and hooksecurefunc
        and editBox.UpdateHeader
    then
        editBox.KamiUIInsetHooked = true

        hooksecurefunc(
            editBox,
            "UpdateHeader",
            function(self)
                HideEditBoxDecorations(self)
                ApplyEditBoxInsets(self)
            end
        )
    end

    HideEditBoxDecorations(editBox)
    ApplyEditBoxInsets(editBox)

    editBox:ClearAllPoints()
    editBox:SetPoint(
        "TOPLEFT",
        Module.inputPanel,
        "TOPLEFT",
        0,
        0
    )
    editBox:SetPoint(
        "BOTTOMRIGHT",
        Module.inputPanel,
        "BOTTOMRIGHT",
        0,
        0
    )
    editBox:SetAlpha(1)

    if editBox.EnableMouse then
        editBox:EnableMouse(true)
    end

    local font, _, flags = editBox:GetFont()

    if font then
        editBox:SetFont(font, defaults.fontSize, flags)
    end
end

local function HideFrameChrome(frame)
    if not frame then
        return
    end

    HideChromeObject(frame.Background)
    HideChromeObject(frame.clickAnywhereButton)

    -- Blizzard's scroll handling uses this scrollbar; keep its parent intact.
    UI:SuppressFrame(frame.ScrollBar, {
        persistent = true,
        children = true,
    })
    HideFrame(frame.ScrollToBottomButton)
    HideFrame(frame.ResizeButton)

    local name = frame:GetName()

    if name then
        HideChromeObject(_G[name .. "ButtonFrame"])
        HideChromeObject(_G[name .. "Tab"])

        for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
            HideChromeObject(_G[name .. suffix])
        end
    end
end

local function StyleNativeChatFrame(frame, parent, topInset)
    if not frame or not parent then
        return
    end

    if frame.isDocked and FCF_UnDockFrame then
        FCF_UnDockFrame(frame)
    end

    FCF_SetLocked(frame, true)

    frame:SetParent(parent)
    frame:ClearAllPoints()
    frame:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        defaults.padding,
        -(topInset or defaults.padding)
    )
    frame:SetPoint(
        "BOTTOMRIGHT",
        parent,
        "BOTTOMRIGHT",
        -defaults.padding,
        defaults.padding
    )

    frame:SetAlpha(1)
    frame:SetFading(false)
    if not frame.KamiUIMaxLinesSet then
        -- Calling SetMaxLines again can discard existing chat history.
        frame:SetMaxLines(500)
        frame.KamiUIMaxLinesSet = true
    end
    frame:SetScrollAllowed(true)

    if not frame.KamiUIWheelHooked then
        frame.KamiUIWheelHooked = true
        frame:SetScript("OnMouseWheel", function(self, delta)
            if delta > 0 then
                self:ScrollUp()
            else
                self:ScrollDown()
            end
        end)
    end
    frame:SetJustifyH("LEFT")
    frame:SetIndentedWordWrap(false)
    frame:SetHyperlinksEnabled(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)

    local font, _, flags = frame:GetFont()
    if font then
        frame:SetFont(font, defaults.fontSize, flags)
    end

    frame:Show()

    -- Showing a native chat frame can re-show its Blizzard tab/chrome.
    -- Hide it only after the frame itself is visible.
    HideFrameChrome(frame)
end

local function HideStockFrame(frame)
    if not frame then
        return
    end

    UI:SuppressFrame(frame, {
        persistent = true,
        children = true,
    })
    if frame.SetHyperlinksEnabled then
        frame:SetHyperlinksEnabled(false)
    end

    HideFrameChrome(frame)
end

local positioningCombatBar = false

local function PositionCombatBar()
    local bar = _G.CombatLogQuickButtonFrame_Custom
    local frame = Module.backends.combat

    if not bar
        or not frame
        or not Module.combatPanel
        or positioningCombatBar
    then
        return
    end

    positioningCombatBar = true

    bar:SetParent(Module.combatPanel)
    bar:SetAlpha(1)
    bar:EnableMouse(true)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", Module.combatPanel, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", Module.combatPanel, "TOPRIGHT", 0, 0)
    bar:Show()

    local background = _G.CombatLogQuickButtonFrame_CustomTexture
    if background then
        background:SetAlpha(0)
    end

    StyleNativeChatFrame(
        frame,
        Module.combatPanel,
        bar:GetHeight() + defaults.padding,
        false
    )

    positioningCombatBar = false
end

local function SetupCombatLog()
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_CombatLog")
    end

    Module.backends.combat = ChatFrame2

    if ChatFrame2 then
        ChatFrame2:Show()
        FCF_SetLocked(ChatFrame2, true)
    end
end

local function IsManagedEditBox(editBox)
    return editBox ~= nil
        and editBox == Module.inputEditBox
end

local function UpdateInputPanelVisibility()
    if not Module.inputPanel then
        return
    end

    Module.inputPanel:SetShown(
        IsManagedEditBox(ACTIVE_CHAT_EDIT_BOX)
    )
end

local function PositionManagedChatFrames()
    for _, config in ipairs(leftTabs) do
        local frame = Module.backends[config.key]

        if frame then
            StyleNativeChatFrame(
                frame,
                Module.leftPanel,
                defaults.padding
            )
        end
    end
end

local function HideStockChatUI()
    -- Preserve dock manager behavior while hiding its own UI.
    UI:SuppressFrame(GeneralDockManager, { persistent = true })
    HideChromeObject(ChatFrameMenuButton)
    HideChromeObject(ChatFrameChannelButton)
    HideChromeObject(TextToSpeechButton)
    HideChromeObject(QuickJoinToastButton)

    local managed = {}

    for _, frame in pairs(Module.backends) do
        if frame then
            managed[frame] = true
        end
    end

    for index = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. index]

        if frame and not managed[frame] then
            HideStockFrame(frame)
        end
    end
end

function Module:SelectTab(key)
    local backend = self.backends[key]

    if not backend then
        return
    end

    self.selectedTab = key

    for _, config in ipairs(leftTabs) do
        local frame = self.backends[config.key]

        if frame then
            local active = config.key == key

            frame:SetAlpha(active and 1 or 0)
            frame:EnableMouse(active)

            if frame.EnableMouseWheel then
                frame:EnableMouseWheel(active)
            end

            if frame.SetHyperlinksEnabled then
                frame:SetHyperlinksEnabled(active)
            end
        end
    end

    UpdateTabStyles()
    UpdateInputPanelVisibility()
end

function Module:SetupBackends()
    self.backends.general = EnsureWindow(managedWindows.general)
    self.backends.party = EnsureWindow(managedWindows.party)
    self.backends.guild = EnsureWindow(managedWindows.guild)
    self.backends.whisper = EnsureWindow(managedWindows.whisper)

    SetupCombatLog()
    StyleInputEditBox()

    if ChatFrameUtil
        and ChatFrameUtil.SetLastActiveWindow
        and Module.inputEditBox
        and securecallfunction
    then
        securecallfunction(
            ChatFrameUtil.SetLastActiveWindow,
            Module.inputEditBox
        )
    end
end

function Module:ApplyLayout()
    EnsurePanels()
    EnsureTabs()
    PositionPanels()
    PositionTabs()
    HideStockChatUI()
    PositionManagedChatFrames()
    StyleInputEditBox()
    PositionCombatBar()
    self:SelectTab(self.selectedTab or "general")
end

function Module:Reset()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = {}

    self.selectedTab = "general"
    self:SetupBackends()
    self:ApplyLayout()

    KamiUIDB.chat.initialized = true
    KamiUIDB.chat.setupVersion = SETUP_VERSION

    UI:Print("Chat reset")
end

UI:RegisterCommand(
    "chat",
    "reset",
    function()
        Module:Reset()
    end,
    "Reset chat configuration"
)

local function StartChatUI()
    if Module.starting or Module.started then
        return
    end

    Module.starting = true

    EnsurePanels()
    EnsureTabs()
    PositionPanels()
    PositionTabs()

    Module:SetupBackends()
    Module:ApplyLayout()

    KamiUIDB.chat.initialized = true
    KamiUIDB.chat.setupVersion = SETUP_VERSION

    Module.starting = false
    Module.started = true
end

function Module:Initialize()
    self.tabs = {}
    self.backends = {}
    self.selectedTab = "general"

    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = KamiUIDB.chat or {}

    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback(
            "ChatFrame.OnEditBoxFocusGained",
            function(_, editBox)
                if not IsManagedEditBox(editBox) then
                    return
                end

                HideEditBoxDecorations(editBox)
                ApplyEditBoxInsets(editBox)
                UpdateInputPanelVisibility()
            end,
            Module
        )

        EventRegistry:RegisterCallback(
            "ChatFrame.OnEditBoxFocusLost",
            function(_, editBox)
                if not IsManagedEditBox(editBox) then
                    return
                end

                if C_Timer and C_Timer.After then
                    C_Timer.After(
                        0,
                        UpdateInputPanelVisibility
                    )
                else
                    UpdateInputPanelVisibility()
                end
            end,
            Module
        )
    end

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if Module.started then
            Module:ApplyLayout()
        else
            StartChatUI()
        end
    end)

    UI:RegisterBottomInsetCallback(function()
        if Module.started then
            PositionPanels()
        end
    end)

    local refreshQueued = false

    local function RefreshChatWindows()
        if Module.starting then
            HideStockChatUI()
            return
        end

        if not Module.started or refreshQueued then
            return
        end

        refreshQueued = true
        C_Timer.After(0, function()
            refreshQueued = false
            HideStockChatUI()
            PositionManagedChatFrames()
            PositionCombatBar()
            Module:SelectTab(Module.selectedTab or "general")
        end)
    end

    UI:RegisterEvent("UPDATE_CHAT_WINDOWS", RefreshChatWindows)
    UI:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", RefreshChatWindows)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CombatLog" and Module.started then
            HideStockChatUI()
            PositionCombatBar()
        end
    end)

    UI:RegisterEvent("UI_SCALE_CHANGED", function()
        if Module.started then
            Module:ApplyLayout()
        end
    end)
end

Module:Initialize()
