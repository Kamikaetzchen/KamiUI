local UI = KamiUI

local Module = UI:NewModule("Chat")

Module.name = "KamiUI_Chat"
Module.version = "0.2.0"

local SETUP_VERSION = 2

local defaults = {
    leftWidth = 500,
    combatWidth = 450,
    height = 220,
    tabHeight = 28,
    inputHeight = 24,
    fontSize = 14,
    padding = 4,
    x = 0,
    y = 0,
    background = { 0, 0, 0, 0.85 },
    border = { 0.2, 0.2, 0.2, 1 },
    tabBackground = { 0.02, 0.02, 0.02, 0.80 },
    tabSelectedBackground = { 0.08, 0.08, 0.08, 0.95 },
}

local leftTabs = {
    { key = "general", label = "General" },
    { key = "party", label = "Party" },
    { key = "guild", label = "Guild" },
    { key = "whisper", label = "Whisper" },
}

local managedWindows = {
    guild = {
        name = "Guild",
        groups = {
            "GUILD",
            "OFFICER",
        },
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
    whisper = {
        name = "Whisper",
        groups = {
            "WHISPER",
            "BN_WHISPER",
        },
        privateMessages = true,
    },
}

local hiddenObjects = setmetatable({}, { __mode = "k" })

local function GetBottom()
    return defaults.y + UI:GetBottomInset()
end

local function HideObject(object)
    if not object then
        return
    end

    object:SetAlpha(0)
    object:Hide()

    if object.EnableMouse then
        object:EnableMouse(false)
    end

    if not hiddenObjects[object] and object.HookScript then
        hiddenObjects[object] = true

        object:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
    end
end

local function CreatePanel(name, width, height)
    local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(defaults.background))
    panel:SetBackdropBorderColor(unpack(defaults.border))
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

    if not Module.inputPanel then
        Module.inputPanel = CreatePanel(
            "KamiUIChatInputPanel",
            defaults.leftWidth,
            defaults.inputHeight
        )
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
        UIParent,
        "BOTTOMLEFT",
        defaults.x + defaults.leftWidth,
        bottom
    )

    Module.inputPanel:ClearAllPoints()
    Module.inputPanel:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        defaults.x,
        bottom + defaults.height + defaults.tabHeight
    )
end

local function CreateTab(index, config)
    local button = CreateFrame(
        "Button",
        "KamiUIChatTab" .. index,
        UIParent,
        "BackdropTemplate"
    )

    local width = defaults.leftWidth / #leftTabs
    button:SetSize(width, defaults.tabHeight)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropBorderColor(unpack(defaults.border))

    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    text:SetText(config.label)
    text:SetTextColor(0.72, 0.72, 0.72)

    local font, _, flags = GameFontNormal:GetFont()
    if font then
        text:SetFont(font, defaults.fontSize, flags)
    end

    button.text = text
    button.key = config.key

    button:SetScript("OnClick", function(self)
        Module:SelectTab(self.key)
    end)

    Module.tabs[config.key] = button
    return button
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
            tab:SetPoint("BOTTOMLEFT", Module.leftPanel, "TOPLEFT", 0, 0)
        end

        previous = tab
    end
end

local function UpdateTabStyles()
    for _, config in ipairs(leftTabs) do
        local tab = Module.tabs[config.key]
        local selected = config.key == Module.selectedTab

        if selected then
            tab:SetBackdropColor(unpack(defaults.tabSelectedBackground))
            tab.text:SetTextColor(1, 1, 1)
        else
            tab:SetBackdropColor(unpack(defaults.tabBackground))
            tab.text:SetTextColor(0.72, 0.72, 0.72)
        end
    end
end

local function HideFrameChrome(frame)
    if not frame then
        return
    end

    HideObject(frame.Background)
    HideObject(frame.ScrollBar)
    HideObject(frame.ScrollToBottomButton)
    HideObject(frame.ResizeButton)

    local name = frame:GetName()

    if not name then
        return
    end

    HideObject(_G[name .. "ButtonFrame"])
    HideObject(_G[name .. "Tab"])

    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        HideObject(_G[name .. suffix])
    end
end

local function StyleFont(frame)
    local font, _, flags = frame:GetFont()

    if font then
        frame:SetFont(font, defaults.fontSize, flags)
    end

    frame:SetFading(false)
end

local function StyleEditBox(frame)
    local editBox = frame and frame.editBox

    if not editBox then
        return
    end

    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", Module.inputPanel, "TOPLEFT", 0, 0)
    editBox:SetPoint("BOTTOMRIGHT", Module.inputPanel, "BOTTOMRIGHT", 0, 0)

    local name = editBox:GetName()

    if name then
        for _, suffix in ipairs({
            "Left",
            "Right",
            "Mid",
            "FocusLeft",
            "FocusRight",
            "FocusMid",
        }) do
            HideObject(_G[name .. suffix])
        end
    end

    local font, _, flags = editBox:GetFont()

    if font then
        editBox:SetFont(font, defaults.fontSize, flags)
    end

    if not editBox.KamiUIInputHooked then
        editBox.KamiUIInputHooked = true

        editBox:HookScript("OnEditFocusGained", function()
            Module.inputPanel:Show()
        end)

        editBox:HookScript("OnEditFocusLost", function()
            C_Timer.After(0, function()
                for _, backend in pairs(Module.leftFrames) do
                    local other = backend and backend.editBox

                    if other and other.HasFocus and other:HasFocus() then
                        return
                    end
                end

                Module.inputPanel:Hide()
            end)
        end)
    end
end

local function PositionLeftFrame(frame)
    frame:SetClampedToScreen(false)
    frame:ClearAllPoints()
    frame:SetPoint(
        "TOPLEFT",
        Module.leftPanel,
        "TOPLEFT",
        defaults.padding,
        -defaults.padding
    )
    frame:SetPoint(
        "BOTTOMRIGHT",
        Module.leftPanel,
        "BOTTOMRIGHT",
        -defaults.padding,
        defaults.padding
    )
end

local function PositionCombatFrame()
    if not ChatFrame2 then
        return
    end

    local quickBar = _G.CombatLogQuickButtonFrame_Custom
    local topInset = defaults.padding

    if quickBar then
        topInset = quickBar:GetHeight() + defaults.padding

        quickBar:SetParent(Module.combatPanel)
        quickBar:ClearAllPoints()
        quickBar:SetPoint("TOPLEFT", Module.combatPanel, "TOPLEFT", 0, 0)
        quickBar:SetPoint("TOPRIGHT", Module.combatPanel, "TOPRIGHT", 0, 0)
        quickBar:Show()

        local background = _G.CombatLogQuickButtonFrame_CustomTexture
        if background then
            background:SetAlpha(0)
        end
    end

    ChatFrame2:SetClampedToScreen(false)
    ChatFrame2:ClearAllPoints()
    ChatFrame2:SetPoint(
        "TOPLEFT",
        Module.combatPanel,
        "TOPLEFT",
        defaults.padding,
        -topInset
    )
    ChatFrame2:SetPoint(
        "BOTTOMRIGHT",
        Module.combatPanel,
        "BOTTOMRIGHT",
        -defaults.padding,
        defaults.padding
    )
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

local function ConfigureWindow(frame, config)
    RemoveAllMessageGroups(frame)
    RemoveAllChannels(frame)

    for _, group in ipairs(config.groups) do
        AddMessageGroup(frame, group)
    end

    if config.privateMessages and frame.ReceiveAllPrivateMessages then
        frame:ReceiveAllPrivateMessages()
    elseif config.privateMessages and ChatFrame_ReceiveAllPrivateMessages then
        ChatFrame_ReceiveAllPrivateMessages(frame)
    end

    if frame.isDocked then
        FCF_UnDockFrame(frame)
    end

    FCF_SetLocked(frame, true)
    frame:Show()

    return frame
end

local function EnsureWindow(config)
    local frame = FindChatWindow(config.name)

    if not frame then
        frame = FCF_OpenNewWindow(config.name, true)
    end

    if not frame then
        return
    end

    return ConfigureWindow(frame, config)
end

local function SyncGeneralWindow()
    local frame = Module.leftFrames.general

    if not frame or not ChatFrame1 then
        return
    end

    RemoveAllMessageGroups(frame)
    RemoveAllChannels(frame)

    for _, group in pairs(ChatFrame1.messageTypeList or {}) do
        AddMessageGroup(frame, group)
    end

    for _, channel in pairs(ChatFrame1.channelList or {}) do
        if frame.AddChannel then
            frame:AddChannel(channel)
        else
            ChatFrame_AddChannel(frame, channel)
        end
    end

    if frame.ReceiveAllPrivateMessages then
        frame:ReceiveAllPrivateMessages()
    elseif ChatFrame_ReceiveAllPrivateMessages then
        ChatFrame_ReceiveAllPrivateMessages(frame)
    end
end

local function EnsureGeneralWindow()
    local frame = FindChatWindow("Kami General")

    if not frame then
        frame = FCF_OpenNewWindow("Kami General", true)
    end

    if not frame then
        return
    end

    if frame.isDocked then
        FCF_UnDockFrame(frame)
    end

    FCF_SetLocked(frame, true)
    frame:Show()

    return frame
end

local function SetupCombatLog()
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_CombatLog")
    end

    if ChatFrame2 and ChatFrame2.isDocked then
        FCF_UnDockFrame(ChatFrame2)
    end

    if ChatFrame2 then
        FCF_SetLocked(ChatFrame2, true)
        ChatFrame2:Show()
    end
end

local function ParkDefaultChatFrame()
    if not ChatFrame1 then
        return
    end

    if ChatFrame1.BreakFromFrameManager then
        ChatFrame1:BreakFromFrameManager()
    end

    ChatFrame1.ignoreFramePositionManager = true
    ChatFrame1:SetClampedToScreen(false)
    ChatFrame1:SetAlpha(0)
    ChatFrame1:EnableMouse(false)

    if ChatFrame1.ClearAllPointsBase and ChatFrame1.SetPointBase then
        ChatFrame1:ClearAllPointsBase()
        ChatFrame1:SetPointBase(
            "TOPLEFT",
            UIParent,
            "BOTTOMLEFT",
            -1000,
            -1000
        )
    end

    ChatFrame1:Show()
end

local function HideBlizzardChatUI()
    HideObject(GeneralDockManager)
    HideObject(ChatFrameMenuButton)
    HideObject(ChatFrameChannelButton)
    HideObject(TextToSpeechButton)
    HideObject(QuickJoinToastButton)

    for index = 1, NUM_CHAT_WINDOWS do
        HideObject(_G["ChatFrame" .. index .. "Tab"])
    end
end

local function StyleLeftFrames()
    for _, frame in pairs(Module.leftFrames) do
        if frame then
            HideFrameChrome(frame)
            StyleFont(frame)
            StyleEditBox(frame)
            PositionLeftFrame(frame)
        end
    end
end

local function StyleCombatFrame()
    if not ChatFrame2 then
        return
    end

    HideFrameChrome(ChatFrame2)
    StyleFont(ChatFrame2)
    HideObject(ChatFrame2.editBox)
    PositionCombatFrame()
end

function Module:SelectTab(key)
    local selected = self.leftFrames[key]

    if not selected then
        return
    end

    self.selectedTab = key

    for frameKey, frame in pairs(self.leftFrames) do
        if frame then
            local active = frameKey == key
            frame:SetAlpha(active and 1 or 0)
            frame:EnableMouse(active)

            if frame.editBox and frame.editBox.EnableMouse then
                frame.editBox:EnableMouse(active)
            end
        end
    end

    SELECTED_CHAT_FRAME = selected

    if ChatFrameUtil and ChatFrameUtil.SetLastActiveWindow then
        ChatFrameUtil.SetLastActiveWindow(selected.editBox)
    end

    UpdateTabStyles()
end

function Module:SetupWindows()
    self.leftFrames.general = EnsureGeneralWindow()
    self.leftFrames.party = EnsureWindow(managedWindows.party)
    self.leftFrames.guild = EnsureWindow(managedWindows.guild)
    self.leftFrames.whisper = EnsureWindow(managedWindows.whisper)

    SyncGeneralWindow()
    SetupCombatLog()
end

function Module:ApplyLayout()
    EnsurePanels()
    EnsureTabs()
    PositionPanels()
    PositionTabs()
    ParkDefaultChatFrame()
    HideBlizzardChatUI()
    StyleLeftFrames()
    StyleCombatFrame()

    self:SelectTab(self.selectedTab or "general")
end

function Module:Reset()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = {}

    self:SetupWindows()
    self.selectedTab = "general"
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

function Module:Initialize()
    self.tabs = {}
    self.leftFrames = {}
    self.selectedTab = "general"

    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = KamiUIDB.chat or {}

    self:SetupWindows()
    self:ApplyLayout()

    KamiUIDB.chat.initialized = true
    KamiUIDB.chat.setupVersion = SETUP_VERSION

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:SetupWindows()
            Module:ApplyLayout()
        end)
    end)

    UI:RegisterBottomInsetCallback(function()
        PositionPanels()
    end)

    UI:RegisterEvent("CHANNEL_UI_UPDATE", function()
        C_Timer.After(0, SyncGeneralWindow)
    end)

    UI:RegisterEvent("UPDATE_CHAT_WINDOWS", function()
        C_Timer.After(0, function()
            SyncGeneralWindow()
            Module:ApplyLayout()
        end)
    end)

    UI:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", function()
        C_Timer.After(0, function()
            Module:ApplyLayout()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CombatLog" then
            C_Timer.After(0, function()
                StyleCombatFrame()
            end)
        end
    end)
end

Module:Initialize()
