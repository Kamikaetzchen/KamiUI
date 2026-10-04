local UI = KamiUI

local Module = UI:NewModule("Chat")

Module.name = "KamiUI_Chat"
Module.version = "0.3.0"

local SETUP_VERSION = 3

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
    frame:SetScrollAllowed(true)
    frame:SetJustifyH("LEFT")
    frame:SetIndentedWordWrap(false)
    frame:SetHyperlinksEnabled(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)

    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() then
            if delta > 0 then
                self:ScrollToTop()
            else
                self:ScrollToBottom()
            end

            return
        end

        local offset = self:GetScrollOffset() or 0
        local maximum = self:GetMaxScrollRange() or 0
        local nextOffset = offset + delta * 3

        nextOffset = math.max(0, math.min(maximum, nextOffset))
        self:SetScrollOffset(nextOffset)
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

local function SetTabBackground(tab, r, g, b, a)
    for _, texture in ipairs(tab.backgrounds or {}) do
        texture:SetColorTexture(r, g, b, a)
    end
end

local function CreateTabVisual(tab)
    local chamfer = 4
    local backgrounds = {}

    local lower = tab:CreateTexture(nil, "BACKGROUND")
    lower:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    lower:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
    lower:SetPoint("TOP", tab, "TOP", 0, -chamfer)
    backgrounds[#backgrounds + 1] = lower

    for row = 0, chamfer - 1 do
        local inset = chamfer - row
        local strip = tab:CreateTexture(nil, "BACKGROUND")
        strip:SetPoint("TOPLEFT", tab, "TOPLEFT", inset, -row)
        strip:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -inset, -row)
        strip:SetHeight(1)
        backgrounds[#backgrounds + 1] = strip
    end

    tab.backgrounds = backgrounds

    local borders = {}

    local top = tab:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", tab, "TOPLEFT", chamfer, 0)
    top:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -chamfer, 0)
    top:SetHeight(1)
    top:SetColorTexture(unpack(defaults.border))
    borders[1] = top

    local bottom = tab:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    bottom:SetColorTexture(unpack(defaults.border))
    borders[2] = bottom

    local left = tab:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -chamfer)
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    left:SetColorTexture(unpack(defaults.border))
    borders[3] = left

    local right = tab:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, -chamfer)
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    right:SetColorTexture(unpack(defaults.border))
    borders[4] = right

    for step = 1, chamfer do
        local leftChamfer = tab:CreateTexture(nil, "OVERLAY")
        leftChamfer:SetPoint(
            "TOPLEFT",
            tab,
            "TOPLEFT",
            step - 1,
            -(chamfer - step)
        )
        leftChamfer:SetSize(1, 1)
        leftChamfer:SetColorTexture(unpack(defaults.border))

        local rightChamfer = tab:CreateTexture(nil, "OVERLAY")
        rightChamfer:SetPoint(
            "TOPRIGHT",
            tab,
            "TOPRIGHT",
            -(step - 1),
            -(chamfer - step)
        )
        rightChamfer:SetSize(1, 1)
        rightChamfer:SetColorTexture(unpack(defaults.border))
    end

    tab.borders = borders

    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", tab, "TOPLEFT", chamfer, -1)
    highlight:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -chamfer, 1)
    highlight:SetColorTexture(1, 1, 1, 0.06)
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

    CreateTabVisual(button)
    SetTabBackground(button, 0, 0, 0, 0.40)

    if index > 1 and button.borders and button.borders[3] then
        button.borders[3]:Hide()
    end

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

        SetTabBackground(
            tab,
            active and 0.04 or 0.00,
            active and 0.04 or 0.00,
            active and 0.05 or 0.00,
            active and 0.55 or 0.40
        )

        local text = tab:GetFontString()

        if text then
            if active then
                text:SetTextColor(1.00, 0.82, 0.00)
            else
                text:SetTextColor(0.72, 0.72, 0.72)
            end
        end

        if tab.borders and tab.borders[2] then
            tab.borders[2]:SetShown(not active)
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

local function InstallMessageMirror()
    if Module.messageMirrorInstalled or not ScrollingMessageFrameSecureMixin then
        return
    end

    Module.messageMirrorInstalled = true

    -- ChatFrameMixin:AddMessage() always forwards through this secure mixin.
    -- Hooking it once is much safer than trying to hook methods on individual
    -- frame userdata while Blizzard is still constructing chat windows.
    hooksecurefunc(
        ScrollingMessageFrameSecureMixin,
        "AddMessage",
        function(frame, ...)
            local key = Module.backendKeys[frame]
            local target = key and Module.displays[key]

            if target then
                target:AddMessage(...)
            end
        end
    )
end

local function AttachBackend(key, backend)
    local display = Module.displays[key]

    if not backend or not display then
        return
    end

    Module.backendKeys[backend] = key

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
    PositionPanels()
    PositionTabs()

    -- Put the stock chat UI out of sight before opening/configuring any
    -- backend windows. If Blizzard fires layout events during setup, the user
    -- never sees the intermediate docked-window state.
    HideStockChatUI()
    InstallMessageMirror()

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
    self.backendKeys = setmetatable({}, { __mode = "k" })
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
        if Module.starting then
            HideStockChatUI()
            return
        end

        if Module.started then
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
            C_Timer.After(0, function()
                Module:ApplyLayout()
            end)
        end
    end)
end

Module:Initialize()
