local UI = KamiUI

local Module = UI:NewModule("Chat")

Module.name = "KamiUI_Chat"
Module.version = "0.3.0"

local SETUP_VERSION = 3

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
    panel:SetFrameStrata("LOW")
    panel:SetSize(width, height)
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

    Module.inputPanel:ClearAllPoints()
    Module.inputPanel:SetPoint(
        "BOTTOMLEFT",
        Module.leftPanel,
        "TOPLEFT",
        0,
        defaults.tabHeight
    )
end

local function CreateDisplay(name, parent)
    local frame = CreateFrame("ScrollingMessageFrame", name, parent)
    frame:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        defaults.padding,
        -defaults.padding
    )
    frame:SetPoint(
        "BOTTOMRIGHT",
        parent,
        "BOTTOMRIGHT",
        -defaults.padding,
        defaults.padding
    )

    frame:SetFontObject(ChatFontNormal)

    local font, _, flags = frame:GetFont()
    if font then
        frame:SetFont(font, defaults.fontSize, flags)
    end

    frame:SetFading(false)
    frame:SetMaxLines(500)
    frame:SetJustifyH("LEFT")
    frame:SetIndentedWordWrap(false)
    frame:SetHyperlinksEnabled(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)

    frame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            self:ScrollUp()
        else
            self:ScrollDown()
        end
    end)

    frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
        SetItemRef(link, text, button, self)
    end)

    frame:SetScript(
        "OnHyperlinkEnter",
        function(self, link, text, region, left, bottom, width, height)
            if EventRegistry then
                EventRegistry:TriggerEvent(
                    "ChatFrame.OnHyperlinkEnter",
                    self,
                    link,
                    text,
                    region,
                    left,
                    bottom,
                    width,
                    height
                )
            end
        end
    )

    frame:SetScript("OnHyperlinkLeave", function(self)
        if EventRegistry then
            EventRegistry:TriggerEvent("ChatFrame.OnHyperlinkLeave", self)
        end
    end)

    return frame
end

local function EnsureDisplays()
    if not Module.displays.general then
        Module.displays.general = CreateDisplay(
            "KamiUIChatDisplayGeneral",
            Module.leftPanel
        )
    end

    if not Module.displays.party then
        Module.displays.party = CreateDisplay(
            "KamiUIChatDisplayParty",
            Module.leftPanel
        )
    end

    if not Module.displays.guild then
        Module.displays.guild = CreateDisplay(
            "KamiUIChatDisplayGuild",
            Module.leftPanel
        )
    end

    if not Module.displays.whisper then
        Module.displays.whisper = CreateDisplay(
            "KamiUIChatDisplayWhisper",
            Module.leftPanel
        )
    end

    if not Module.displays.combat then
        Module.displays.combat = CreateDisplay(
            "KamiUICombatLogDisplay",
            Module.combatPanel
        )
    end
end

local function CreateTab(index, config)
    local button = CreateFrame(
        "Button",
        "KamiUIChatTab" .. index,
        Module.leftPanel,
        "BackdropTemplate"
    )

    button:SetSize(defaults.leftWidth / #leftTabs, defaults.tabHeight)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropBorderColor(unpack(defaults.border))

    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    text:SetText(config.label)

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
                Module.leftPanel,
                "TOPLEFT",
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

        if config.key == Module.selectedTab then
            tab:SetBackdropColor(unpack(defaults.tabSelectedBackground))
            tab.text:SetTextColor(1, 1, 1)
        else
            tab:SetBackdropColor(unpack(defaults.tabBackground))
            tab.text:SetTextColor(0.72, 0.72, 0.72)
        end
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

local function CopyHistory(backend, display)
    display:Clear()

    for index = 1, backend:GetNumMessages() do
        display:AddMessage(backend:GetMessageInfo(index))
    end
end

local function AttachBackend(key, backend)
    local display = Module.displays[key]

    if not backend or not display then
        return
    end

    backend.KamiUIMirrorKeys = backend.KamiUIMirrorKeys or {}

    if not backend.KamiUIMirrorKeys[key] then
        backend.KamiUIMirrorKeys[key] = true

        hooksecurefunc(backend, "AddMessage", function(_, ...)
            local target = Module.displays[key]

            if target then
                target:AddMessage(...)
            end
        end)
    end

    if display.KamiUIBackend ~= backend then
        display.KamiUIBackend = backend
        CopyHistory(backend, display)
    end
end

local function StyleEditBox(frame)
    local editBox = frame and frame.editBox

    if not editBox then
        return
    end

    if editBox.SetIgnoreParentAlpha then
        editBox:SetIgnoreParentAlpha(true)
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
            local texture = _G[name .. suffix]

            if texture then
                texture:SetAlpha(0)
            end
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
                for _, backend in pairs(Module.backends) do
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

local function HideBackendFrame(frame)
    if not frame then
        return
    end

    frame:SetAlpha(0)
    frame:SetFading(false)
    frame:EnableMouse(false)

    HideObject(frame.Background)
    HideObject(frame.ScrollBar)
    HideObject(frame.ScrollToBottomButton)
    HideObject(frame.ResizeButton)

    local name = frame:GetName()

    if name then
        HideObject(_G[name .. "ButtonFrame"])
        HideObject(_G[name .. "Tab"])

        for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
            HideObject(_G[name .. suffix])
        end
    end
end

local positioningCombatBar = false

local function PositionCombatBar()
    local bar = _G.CombatLogQuickButtonFrame_Custom

    if not bar or not Module.combatPanel or positioningCombatBar then
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

    local display = Module.displays.combat

    if display then
        display:ClearAllPoints()
        display:SetPoint(
            "TOPLEFT",
            Module.combatPanel,
            "TOPLEFT",
            defaults.padding,
            -(bar:GetHeight() + defaults.padding)
        )
        display:SetPoint(
            "BOTTOMRIGHT",
            Module.combatPanel,
            "BOTTOMRIGHT",
            -defaults.padding,
            defaults.padding
        )
    end

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

local function HideStockChatUI()
    HideObject(GeneralDockManager)
    HideObject(ChatFrameMenuButton)
    HideObject(ChatFrameChannelButton)
    HideObject(TextToSpeechButton)
    HideObject(QuickJoinToastButton)

    for index = 1, NUM_CHAT_WINDOWS do
        HideBackendFrame(_G["ChatFrame" .. index])
    end

    for _, backend in pairs(Module.backends) do
        StyleEditBox(backend)
    end
end

function Module:SelectTab(key)
    local display = self.displays[key]
    local backend = self.backends[key]

    if not display or not backend then
        return
    end

    self.selectedTab = key

    for _, config in ipairs(leftTabs) do
        self.displays[config.key]:SetShown(config.key == key)
    end

    SELECTED_CHAT_FRAME = backend

    if ChatFrameUtil and ChatFrameUtil.SetLastActiveWindow then
        ChatFrameUtil.SetLastActiveWindow(backend.editBox)
    end

    UpdateTabStyles()
end

function Module:SetupBackends()
    self.backends.general = ChatFrame1
    self.backends.party = EnsureWindow(managedWindows.party)
    self.backends.guild = EnsureWindow(managedWindows.guild)
    self.backends.whisper = EnsureWindow(managedWindows.whisper)

    SetupCombatLog()

    for key, backend in pairs(self.backends) do
        AttachBackend(key, backend)
    end
end

function Module:ApplyLayout()
    EnsurePanels()
    EnsureDisplays()
    EnsureTabs()
    PositionPanels()
    PositionTabs()
    HideStockChatUI()
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
    if Module.starting then
        return
    end

    Module.starting = true

    EnsurePanels()
    EnsureDisplays()
    EnsureTabs()

    Module:SetupBackends()
    Module:ApplyLayout()

    KamiUIDB.chat.initialized = true
    KamiUIDB.chat.setupVersion = SETUP_VERSION

    Module.starting = false
    Module.started = true
end

function Module:Initialize()
    self.tabs = {}
    self.displays = {}
    self.backends = {}
    self.selectedTab = "general"

    KamiUIDB = KamiUIDB or {}
    KamiUIDB.chat = KamiUIDB.chat or {}

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, StartChatUI)
    end)

    UI:RegisterBottomInsetCallback(function()
        if Module.started then
            PositionPanels()
        end
    end)

    UI:RegisterEvent("UPDATE_CHAT_WINDOWS", function()
        if Module.started and not Module.starting then
            C_Timer.After(0, function()
                HideStockChatUI()
                PositionCombatBar()
            end)
        end
    end)

    UI:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", function()
        if Module.started and not Module.starting then
            C_Timer.After(0, HideStockChatUI)
        end
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_CombatLog" and Module.started then
            C_Timer.After(0, function()
                HideStockChatUI()
                PositionCombatBar()
            end)
        end
    end)

    UI:RegisterEvent("UI_SCALE_CHANGED", function()
        if Module.started then
            C_Timer.After(0, Module.ApplyLayout)
        end
    end)
end

Module:Initialize()
