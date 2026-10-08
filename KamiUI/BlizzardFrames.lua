local UI = KamiUI

local hiddenFrameSink
local persistentSuppression = setmetatable({}, { __mode = "k" })

local function DisableInput(frame, recursive, keyboard)
    if not frame then
        return
    end

    if frame.EnableMouse then
        frame:EnableMouse(false)
    end

    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(false)
    end

    if keyboard and frame.EnableKeyboard then
        frame:EnableKeyboard(false)
    end

    if recursive and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            DisableInput(child, true, keyboard)
        end
    end
end

function UI:GetHiddenFrameSink()
    if hiddenFrameSink then
        return hiddenFrameSink
    end

    hiddenFrameSink = CreateFrame(
        "Frame",
        "KamiUIBlizzardFrameSink",
        UIParent
    )
    hiddenFrameSink:Hide()

    return hiddenFrameSink
end

-- Keep Blizzard's lifecycle/backend alive while making its root frame
-- invisible and non-interactive. Child input is only disabled on request:
-- protected backends such as the bank must not be walked recursively.
function UI:SuppressFrame(frame, options)
    if not frame then
        return nil
    end

    options = options or {}

    if frame.SetAlpha then
        frame:SetAlpha(0)
    end

    if options.disableInput ~= false then
        DisableInput(
            frame,
            options.children == true,
            options.keyboard == true
        )
    end

    if options.persistent and frame.HookScript then
        local savedOptions = persistentSuppression[frame]

        if not savedOptions then
            savedOptions = {}
            persistentSuppression[frame] = savedOptions

            frame:HookScript("OnShow", function(self)
                UI:SuppressFrame(self, persistentSuppression[self])
            end)
        end

        savedOptions.disableInput = options.disableInput
        savedOptions.children = options.children
        savedOptions.keyboard = options.keyboard
    end

    return frame
end

-- Use for Blizzard UI that KamiUI fully replaces but whose scripts do not
-- need to be destroyed. A shown child of a hidden parent stays effectively
-- invisible without an OnShow -> Hide() fight.
function UI:KeepFrameHidden(frame)
    if not frame or not frame.SetParent then
        return frame
    end

    local sink = self:GetHiddenFrameSink()

    if not frame.GetParent or frame:GetParent() ~= sink then
        frame:SetParent(sink)
    end

    return frame
end

-- Use when the Blizzard implementation itself is no longer needed.
function UI:DisableFrame(frame, options)
    if not frame then
        return nil
    end

    options = options or {}

    if options.unregisterUnitWatch
        and UnregisterUnitWatch
    then
        pcall(UnregisterUnitWatch, frame)
    end

    if options.unregisterEvents ~= false
        and frame.UnregisterAllEvents
    then
        frame:UnregisterAllEvents()
    end

    DisableInput(
        frame,
        options.children == true,
        options.keyboard == true
    )

    if frame.Hide then
        frame:Hide()
    end

    if options.sink then
        self:KeepFrameHidden(frame)
    end

    return frame
end

-- Remove a Blizzard UIPanel from UIParent's panel layout management while
-- leaving the frame and its backend alive.
function UI:DetachUIPanel(frame)
    if not frame then
        return nil
    end

    if SetUIPanelAttribute then
        SetUIPanelAttribute(frame, "enabled", false)
        SetUIPanelAttribute(frame, "allowOtherPanels", 1)
        SetUIPanelAttribute(frame, "checkFit", 0)
    end

    if frame.SetAttribute then
        frame:SetAttribute("UIPanelLayout-defined", true)
        frame:SetAttribute("UIPanelLayout-enabled", false)
        frame:SetAttribute("UIPanelLayout-allowOtherPanels", 1)
        frame:SetAttribute("UIPanelLayout-checkFit", 0)
    end

    return frame
end

-- Remove frames such as the Forever swing timer from Blizzard's managed
-- bottom-frame layout so KamiUI can anchor them directly.
function UI:DetachManagedFrame(frame)
    if not frame then
        return nil
    end

    if frame.BreakFromFrameManager then
        frame:BreakFromFrameManager()
        return frame
    end

    frame.ignoreFramePositionManager = true

    if GetBottomManagedFrameContainer then
        local container = GetBottomManagedFrameContainer()

        if container and container.RemoveManagedFrame then
            container:RemoveManagedFrame(frame)
        end
    end

    return frame
end
