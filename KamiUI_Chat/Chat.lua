local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Chat", "KamiUI_Chat")


local SETUP_VERSION = 6

local Layout = UI.Layout.Chat

local leftTabs = {
    { key = "general", label = "General" },
    { key = "combat", label = "Combat Log" },
    { key = "party", label = "Party" },
    { key = "guild", label = "Guild" },
    { key = "whisper", label = "Whispers" },
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

local function GetBottom()
    return Layout.Y + UI:GetBottomInset()
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

local function CreatePanel(name, width, height, transparent)
    local panel = CreateFrame("Frame", name, UIParent,
        transparent and nil or "BackdropTemplate")
    panel:SetFrameStrata("LOW")
    panel:SetSize(width, height)
    if not transparent then
        Styles:ApplyBackdrop(
            panel,
            Palette.window.chat,
            Palette.windowBorder.chat
        )
    end
    panel:EnableMouse(false)

    return panel
end

local function EnsurePanels()
    if not Module.leftPanel then
        Module.leftPanel = CreatePanel(
            "KamiUIChatPanel",
            Layout.LEFT_WIDTH,
            Layout.HEIGHT,
            true
        )
    end

    if not Module.tabPanel then
        Module.tabPanel = CreateFrame(
            "Frame",
            "KamiUIChatTabPanel",
            UIParent
        )
        Module.tabPanel:SetSize(Layout.LEFT_WIDTH, Layout.TAB_HEIGHT)
        Module.tabPanel:SetFrameStrata("DIALOG")
        Module.tabPanel:SetFrameLevel(100)
        Module.tabPanel:EnableMouse(true)
        -- Fade tabs until the mouse moves over the chat or tabs.
        -- Use the parent alpha so refreshing individual tab styling cannot
        -- accidentally make them permanently visible again.
        Module.tabPanel:SetAlpha(0.06)
        Module.tabPanel:SetScript("OnUpdate", function(self, elapsed)
            local hovered = self:IsMouseOver()
                or (Module.leftPanel and Module.leftPanel:IsMouseOver())
                or (Module.inputPanel and Module.inputPanel:IsShown()
                    and Module.inputPanel:IsMouseOver())
            local target = hovered and 1 or 0.06
            local current = self:GetAlpha()
            if math.abs(target - current) < 0.01 then
                if current ~= target then self:SetAlpha(target) end
                return
            end
            self:SetAlpha(current +
                (target - current) * math.min(1, elapsed * 9))
        end)
    end

    if not Module.inputPanel then
        Module.inputPanel = CreatePanel(
            "KamiUIChatInputPanel",
            Layout.LEFT_WIDTH,
            Layout.INPUT_HEIGHT
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
        Layout.X,
        bottom
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
        Layout.TAB_HEIGHT
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
    button:SetSize(Layout.LEFT_WIDTH / #leftTabs, Layout.TAB_HEIGHT)
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

    -- Do not accumulate duplicate groups on chat layout refreshes.
    for _, existing in ipairs(frame.messageTypeList or {}) do
        if existing == group then return end
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

    for _, group in ipairs(config.groups or {}) do
        AddMessageGroup(frame, group)
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
            "NewcomerHint",
            "Prompt",
        }) do
            HideChromeObject(_G[name .. suffix])
        end
    end

    -- The native header displays "To <name>:", the active channel, etc.
    -- Blizzard also adjusts the text insets to leave room for that header.
    HideChromeObject(editBox.NewcomerHint)
    HideChromeObject(editBox.prompt)
end

local function StyleInputEditBox()
    local editBox = ChatFrame1 and ChatFrame1.editBox

    if not editBox or not Module.inputPanel then
        return
    end

    Module.inputEditBox = editBox

    -- Keep Blizzard's native parent. SendMessage() reads GetParent() and
    -- expects the owning chat frame; reparenting taints/breaks sending,
    -- particularly under combat lockdown.
    -- Our tab switch changes ChatFrame1 alpha, so let the edit box ignore it.
    if editBox.SetIgnoreParentAlpha
        and not editBox.KamiUIIgnoreParentAlpha
    then
        editBox:SetIgnoreParentAlpha(true)
        editBox.KamiUIIgnoreParentAlpha = true
    end

    -- Do not hook UpdateHeader: ParseText can call it from SendText(),
    -- and addon code on that path can taint the protected chat send.
    -- Keep Blizzard's header/insets intact for whispers and channels.
    HideEditBoxDecorations(editBox)

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
        editBox:SetFont(font, Styles.FontSize.Chat, flags)
    end
end

local function HideFrameChrome(frame)
    if not frame then
        return
    end

    HideChromeObject(frame.Background)
    HideChromeObject(frame.clickAnywhereButton)

    -- Keep the native scrollbar alive: Blizzard's scrolling-message
    -- integration uses it for display updates. Suppressing the entire frame
    -- (and its children) prevented some history scrolls from refreshing.
    local scrollBar = frame.ScrollBar
    if scrollBar then
        scrollBar:SetAlpha(0)
        if scrollBar.EnableMouse then scrollBar:EnableMouse(false) end
        if not scrollBar.KamiUIAlphaHooked then
            scrollBar.KamiUIAlphaHooked = true
            scrollBar:HookScript("OnShow", function(self)
                self:SetAlpha(0)
            end)
        end
    end
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

    -- ChatFrame1 is Blizzard's primary static dock. Keep its registration
    -- and default-chat identity intact; only style/reposition its visuals.
    if frame ~= ChatFrame1 and frame.isDocked and FCF_UnDockFrame then
        FCF_UnDockFrame(frame)
    end

    FCF_SetLocked(frame, true)

    -- Blizzard clamps chat frames away from screen edges to reserve space
    -- for native buttons and the edit box. Those elements are hidden/moved
    -- in KamiUI, so clamping shifts an otherwise correctly anchored frame.
    -- This API is restricted during combat on protected frames.
    if not (InCombatLockdown and InCombatLockdown())
        and frame.SetClampedToScreen then
        frame:SetClampedToScreen(false)
    end

    -- Anchor the chat to our panel rather than Blizzard's Edit Mode
    -- position. The edit box remains a child of ChatFrame1, as required
    -- by Blizzard's SendMessage() implementation.
    frame:SetParent(parent)
    frame:ClearAllPoints()
    frame:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        Layout.PADDING,
        -(topInset or Layout.PADDING)
    )
    frame:SetPoint(
        "BOTTOMRIGHT",
        parent,
        "BOTTOMRIGHT",
        -Layout.PADDING,
        Layout.PADDING
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
            if delta == 0 then return end
            if IsShiftKeyDown and IsShiftKeyDown() then
                if delta > 0 then
                    self:ScrollToTop()
                else
                    self:ScrollToBottom()
                end
            elseif self.ScrollByAmount then
                self:ScrollByAmount(delta * 3)
            elseif delta > 0 then
                self:ScrollUp()
            else
                self:ScrollDown()
            end

            -- ScrollingMessageFrame can retain stale visible lines in this
            -- client after scrolling, especially with hidden native chrome.
            -- Explicitly refresh its display without clearing history.
            if self.RefreshDisplay then
                self:RefreshDisplay()
            elseif self.RefreshIfNecessary then
                self:RefreshIfNecessary()
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
        frame:SetFont(font, Styles.FontSize.Chat, flags)
    end

    frame:Show()

    -- Showing a native chat frame can re-show its Blizzard tab/chrome.
    -- Hide it only after the frame itself is visible.
    HideFrameChrome(frame)
end

-- Blizzard/Edit Mode may restore both the position and the size of native
-- chat frames after our layout. The previous guard only compared X, so
-- vertical drift and right-inset changes could go undetected indefinitely.
local managedAnchorElapsed = 0

local function KeepManagedChatAnchored(_, elapsed)
    managedAnchorElapsed = managedAnchorElapsed + elapsed
    if managedAnchorElapsed < 0.3 then return end
    managedAnchorElapsed = 0

    if not Module.started or not Module.leftPanel then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local panel = Module.leftPanel
    local panelLeft, panelRight = panel:GetLeft(), panel:GetRight()
    local panelTop, panelBottom = panel:GetTop(), panel:GetBottom()
    if not panelLeft or not panelRight or not panelTop
        or not panelBottom then return end

    for _, config in ipairs(leftTabs) do
        local frame = Module.backends[config.key]
        if frame then
            local topInset = Layout.PADDING
            if config.key == "combat" then
                local bar = _G.CombatLogQuickButtonFrame_Custom
                if bar then
                    topInset = bar:GetHeight() + Layout.PADDING
                end
            end

            local left, right = frame:GetLeft(), frame:GetRight()
            local top, bottom = frame:GetTop(), frame:GetBottom()
            local misplaced = frame:GetParent() ~= panel
                or frame:GetNumPoints() ~= 2
                or not left or not right or not top or not bottom
                or math.abs(left - (panelLeft + Layout.PADDING)) > 1
                or math.abs(right - (panelRight - Layout.PADDING)) > 1
                or math.abs(top - (panelTop - topInset)) > 1
                or math.abs(bottom - (panelBottom + Layout.PADDING)) > 1

            if misplaced then
                -- Blizzard may restore clamping along with the chat layout.
                -- Unclamp before reapplying anchors, never during combat.
                if frame.IsClampedToScreen and frame:IsClampedToScreen() then
                    frame:SetClampedToScreen(false)
                end
                if frame:GetParent() ~= panel then
                    frame:SetParent(panel)
                end
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", panel, "TOPLEFT",
                    Layout.PADDING, -topInset)
                frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT",
                    -Layout.PADDING, Layout.PADDING)
            end
        end
    end
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

    if not frame or not Module.leftPanel or positioningCombatBar then
        return
    end

    positioningCombatBar = true
    local topInset = Layout.PADDING

    if bar then
        bar:SetParent(Module.leftPanel)
        bar:SetAlpha(1)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", Module.leftPanel, "TOPLEFT", 0, 0)
        bar:SetPoint("TOPRIGHT", Module.leftPanel, "TOPRIGHT", 0, 0)

        local active = Module.selectedTab == "combat"
        bar:SetShown(active)
        bar:EnableMouse(active)

        local background = _G.CombatLogQuickButtonFrame_CustomTexture
        if background then background:SetAlpha(0) end
        topInset = bar:GetHeight() + Layout.PADDING
    end

    StyleNativeChatFrame(frame, Module.leftPanel, topInset)
    positioningCombatBar = false
end

-- Blizzard's combat log filter configuration triggers protected
-- ClearEventFilters() when applied. Do not mutate its filter tables or
-- apply settings from addon code (taint / ADDON_ACTION_FORBIDDEN).
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
                Layout.PADDING
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

    -- The combat filter toolbar belongs only to the Combat Log tab.
    local combatBar = _G.CombatLogQuickButtonFrame_Custom
    if combatBar then
        local active = key == "combat"
        combatBar:SetShown(active)
        combatBar:EnableMouse(active)
    end

    UpdateTabStyles()
    UpdateInputPanelVisibility()
end

function Module:SetupBackends()
    -- Preserve Blizzard's primary chat window and DEFAULT_CHAT_FRAME.
    -- Its channel subscriptions are managed by the secure chat code.
    self.backends.general = ChatFrame1

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
    -- Watch all four frame edges, not just General's left edge.
    Module.leftPanel:SetScript("OnUpdate", KeepManagedChatAnchored)
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

-- Read-only layout diagnostics: never modify Blizzard's chat processing.
-- /kami chat debug toggles outlines and reports the actual frame geometry.
local function DebugFrameName(frame)
    if not frame then return "nil" end
    if frame.GetName then
        return frame:GetName() or "<unnamed>"
    end
    return tostring(frame)
end

local function DebugFrameBounds(label, frame)
    if not frame then
        UI:Print(label .. ": missing")
        return
    end

    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then
        UI:Print(label .. ": coordinates unavailable")
        return
    end

    UI:Print(string.format(
        "%s: L %.1f R %.1f T %.1f B %.1f (%.1fx%.1f)",
        label, left, right, top, bottom, right - left, top - bottom
    ))
    UI:Print(string.format(
        "  parent=%s scale=%.2f effective=%.2f level=%d",
        DebugFrameName(frame:GetParent()), frame:GetScale(),
        frame:GetEffectiveScale(),
        frame.GetFrameLevel and frame:GetFrameLevel() or 0
    ))
end

local function CreateDebugOutline(target, r, g, b)
    local outline = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    outline:SetFrameStrata("TOOLTIP")
    outline:EnableMouse(false)
    outline:SetAllPoints(target)
    outline:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    outline:SetBackdropBorderColor(r, g, b, 1)
    return outline
end

local function DebugChatLayout()
    if InCombatLockdown and InCombatLockdown() then
        UI:Print("Chat debug: use outside combat")
        return
    end

    local panel = Module.leftPanel
    local frame = Module.backends and Module.backends.general
    if not panel or not frame then
        UI:Print("Chat debug: chat not initialized")
        return
    end

    if not Module.debugOutlines then
        Module.debugOutlines = {
            CreateDebugOutline(panel, 0, 1, 0),
            CreateDebugOutline(frame, 1, 0, 0),
        }
    end

    Module.debugOutlinesShown = not Module.debugOutlinesShown
    for _, outline in ipairs(Module.debugOutlines) do
        outline:SetShown(Module.debugOutlinesShown)
    end

    UI:Print("Chat debug: green=panel, red=ChatFrame1; outlines "
        .. (Module.debugOutlinesShown and "ON" or "OFF"))
    DebugFrameBounds("Panel", panel)
    DebugFrameBounds("General", frame)

    local panelLeft, panelRight = panel:GetLeft(), panel:GetRight()
    local panelTop, panelBottom = panel:GetTop(), panel:GetBottom()
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if panelLeft and panelRight and panelTop and panelBottom
        and left and right and top and bottom then
        UI:Print(string.format(
            "  offset from expected: L %+.1f R %+.1f T %+.1f B %+.1f",
            left - panelLeft - Layout.PADDING,
            right - panelRight + Layout.PADDING,
            top - panelTop + Layout.PADDING,
            bottom - panelBottom - Layout.PADDING
        ))
    end

    for index = 1, frame:GetNumPoints() do
        local point, relative, relativePoint, x, y = frame:GetPoint(index)
        UI:Print(string.format(
            "  anchor %d: %s -> %s:%s (%.1f, %.1f)",
            index, tostring(point), DebugFrameName(relative),
            tostring(relativePoint), x or 0, y or 0
        ))
    end

    if frame.GetTextInsets then
        local ok, l, r, t, b = pcall(frame.GetTextInsets, frame)
        if ok then
            UI:Print(string.format(
                "  text insets: %.1f %.1f %.1f %.1f",
                l or 0, r or 0, t or 0, b or 0
            ))
        end
    end

    local count = 0
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            count = count + 1
            if count <= 3 then
                DebugFrameBounds("Text region " .. count, region)
            end
        end
    end
    UI:Print("  FontString regions: " .. count
        .. ", isDocked=" .. tostring(frame.isDocked)
        .. ", isStaticDocked=" .. tostring(frame.isStaticDocked))
    if frame.IsClampedToScreen then
        UI:Print("  clampedToScreen=" .. tostring(frame:IsClampedToScreen()))
    end
    if frame.GetClampRectInsets then
        local l, r, t, b = frame:GetClampRectInsets()
        UI:Print(string.format(
            "  clamp insets: %.1f %.1f %.1f %.1f",
            l or 0, r or 0, t or 0, b or 0
        ))
    end
end

UI:RegisterCommand(
    "chat",
    "debug",
    DebugChatLayout,
    "Toggle chat bounds and inspect native frame positions"
)

-- Set Blizzard's native 24-hour chat timestamps once. Players can
-- subsequently change the format in the standard Chat settings.
local function EnsureChatTimestamps()
    if KamiUIDB.chat.timestampsConfigured then return end

    local format = TIMESTAMP_FORMAT_HHMM_24HR
    if not format then return end

    if GetCVar and GetCVar("showTimestamps") == "none" then
        if C_CVar and C_CVar.SetCVar then
            C_CVar.SetCVar("showTimestamps", format)
        elseif SetCVar then
            SetCVar("showTimestamps", format)
        end
    end

    KamiUIDB.chat.timestampsConfigured = true
end

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
        EnsureChatTimestamps()

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
