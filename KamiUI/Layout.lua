local UI = KamiUI

-- Editable layout dimensions and offsets, grouped by module.
-- Derived sizes are calculated at their point of use.
-- Global text/style settings: Styles.lua. Colors: Palette.lua.
UI.Layout = {
    Characters = {
        LEFT_PANE_WIDTH = 323,
        RIGHT_PANE_WIDTH = 210,
        FRAME_HEIGHT = 420,
        HEADER_HEIGHT = 40,
        SLOT_SIZE = 36,
        SLOT_GAP = 3,
        BORDER_INSET = 1,
        LIST_CONTENT_INSET = 14,
    },

    Bags = {
        SLOT_SIZE = 36,
        SLOT_SPACING = 3,
        COLUMNS = 10,
        FRAME_PADDING = 10,
        HEADER_HEIGHT = 28,
        FOOTER_HEIGHT = 24,
        BAG_BAR_HEIGHT = 42,
    },

    Bank = {
        SLOT_SIZE = 36,
        SLOT_SPACING = 3,
        COLUMNS = 10,
        FRAME_PADDING = 10,
        HEADER_HEIGHT = 28,
        FOOTER_HEIGHT = 24,
        BAG_BAR_HEIGHT = 42,
    },

    Loot = {
        FRAME_WIDTH = 280,
        HEADER_HEIGHT = 28,
        FRAME_PADDING = 7,
        ROW_HEIGHT = 36,
        ROW_SPACING = 3,
        ICON_SIZE = 32,
        CURSOR_OFFSET_X = 12,
        CURSOR_OFFSET_Y = -12,
        SCREEN_PADDING = 8,
    },

    Professions = {
        FRAME_WIDTH = 640,
        FRAME_HEIGHT = 520,
        HEADER_HEIGHT = 40,
        RECIPE_PANEL_WIDTH = 300,
        CONTENT_PADDING = 8,
        ROW_HEIGHT = 22,
        REAGENT_ROW_HEIGHT = 42,
    },

    ObjectiveTracker = {
        PANEL_WIDTH = 300,
        COLLAPSED_WIDTH = 120,
        HEADER_HEIGHT = 24,
        MAX_HEIGHT_RATIO = 0.35,
        CONTENT_PADDING = 6,
        SECTION_HEADER_HEIGHT = 20,
        HEADER_INDENT = 2,
        SECTION_INDENT = 4,
        QUEST_INDENT = 2,
        QUEST_SELECT_SIZE = 14,
        QUEST_SELECT_GAP = 1,
        QUEST_LEVEL_WIDTH = 28,
        QUEST_TITLE_GAP = 5,
        QUEST_ITEM_SIZE = 18,
        QUEST_ITEM_GAP = 4,
        QUEST_SPACING = 5,
        OBJECTIVE_SPACING = 1,
        OBJECTIVE_COUNT_WIDTH = 34,
        OBJECTIVE_COUNT_GAP = 5,
    },

    Chat = {
        LEFT_WIDTH = 500,
        HEIGHT = 220,
        TAB_HEIGHT = 22,
        INPUT_HEIGHT = 24,
        PADDING = 4,
        X = 0,
        Y = 0,
    },

    Minimap = {
        SIZE = 220,
        POINT = "BOTTOM",
        RELATIVE_POINT = "BOTTOM",
        X = 0,
        Y = 0,
        ButtonCollector = {
            BUTTON_SIZE = 31,
            COLUMNS = 2,
            MAX_ROWS = 6,
            SPACING = 4,
            OFFSET_X = 8,
            OFFSET_Y = 0,
            SCAN_INTERVAL = 2,
        },
    },

    Nameplates = {
        PLATE_WIDTH = 200,
        HEALTH_HEIGHT = 7,
        CAST_HEIGHT = 10,
        TEXT_ROW_HEIGHT = 12,
        TEXT_GAP = 3,
        -- Native click area; does not affect the visible health bar.
        CLICK_HEIGHT = 40,
        AURA_GAP = 4,
        AURA_SIZE = 20,
        AURA_SPACING = 2,
        MAX_AURAS = 5,
    },

    RadialMenu = {
        RADIUS = 100,
        ICON_SIZE = 48,
        CENTER_SIZE = 76,
        SUB_MIN_RADIUS = 52,
        SUB_MAX_RADIUS = 135,
        SUB_GAP = 6,
        SUB_OFFSET = 134,
        SUB_ICON_SIZE = 40,
        Q_SCREEN_X = 0.35,
        E_SCREEN_X = 0.65,
        SCREEN_Y = 0.58,
    },

    -- Combat HUD prototype: two centered bars, one primary and one secondary.
    ActionBars = {
        BUTTON_SIZE = 30,
        SECOND_ROW_BUTTON_SIZE = 28,
        SECONDARY_BUTTON_SIZE = 26,
        BUTTON_SPACING = 0,
        ICON_ZOOM = 0.06,
        OFFSET_X = -400,
        OFFSET_Y = 28,
        BAR_GAP = 3,
        PLAYER_GAP = 10,
        TARGET_GAP = 12,
        VISIBLE_PRIMARY_BARS = 2,
    },

    Auras = {
        WIDTH = 300,
        HEIGHT = 25,
        ICON_SIZE = 25,
        GROUP_GAP = 4,
        X = 0,
        Y = 300,
    },

    DamageMeter = {
        WIDTH = 400,
        HEIGHT = 240,
        HEADER_HEIGHT = 20,
        COLUMN_HEADER_HEIGHT = 17,
        ROW_HEIGHT = 18,
        MAX_ROWS = 11,
        POPUP_ROW_HEIGHT = 20,
    },

    InfoPanel = {
        HEIGHT = 20,
        SPACING = 8,
        SLOT_WIDTHS = {
            location = 210,
            speed = 52,
            xp = 78,
            rested = 72,
            levelup = 72,
            bags = 52,
            durability = 52,
            gold = 112,
            latency = 58,
            clock = 58,
        },
    },

    ThreatMeter = {
        WIDTH = 260,
        TITLE_HEIGHT = 20,
        ROW_HEIGHT = 20,
        MAX_ROWS = 10,
    },

    SwingTimer = {
        WIDTH = 200,
        HEIGHT = 15,
        OFFSET_Y = 4,
        SPACING = 0,
    },

    Timers = {
        WIDTH = 200,
        HEIGHT = 12,      -- Visible bar and icon
        ROW_PADDING = 1,  -- Transparent space above/below each row
        MAX_NAMEPLATES = 40,
        FONT_SIZE = 9,
        UNIT_WIDTH = 90,
        UNIT_GAP = 5,
        TIME_WIDTH = 38,
        GAP = 0,          -- Row padding supplies 2px visual gap
        GROUP_GAP = 2,    -- Additional gap between unit containers
        -- Duration filter for short buffs (including Battle Shout),
        -- DoTs and HoTs; totems are tracked separately.
        MAX_AURA_DURATION = 180,
        OFFSET_X = -8,
        OFFSET_Y = 16,
    },

    XPBar = {
        HEIGHT = 10,
        SEGMENTS = 20,
    },

    UnitFrames = {
        Base = {
            PRIMARY_WIDTH = 380,
            PRIMARY_HEIGHT = 56,
            PRIMARY_HEALTH_HEIGHT = 31,
            PRIMARY_POWER_HEIGHT = 22,
            PRIMARY_HEALTH_CAST_HEIGHT = 24,
            PRIMARY_POWER_CAST_HEIGHT = 19,
            PRIMARY_CAST_HEIGHT = 9,
            -- Every combination occupies the same 54px content area.
            -- Cat/Bear mana and casts still share it without resizing.
            PRIMARY_MANA_HEIGHT = 8,
            PRIMARY_HEALTH_MANA_HEIGHT = 29,
            PRIMARY_POWER_MANA_HEIGHT = 15,
            PRIMARY_HEALTH_MANA_CAST_HEIGHT = 20,
            PRIMARY_POWER_MANA_CAST_HEIGHT = 14,
            PRIMARY_NAME_WIDTH = 165,
            PRIMARY_TEXT_INSET = 8,
            COMPACT_WIDTH = 150,
            COMPACT_HEIGHT = 25,
            COMPACT_HEALTH_HEIGHT = 13,
            COMPACT_POWER_HEIGHT = 9,
            COMPACT_TEXT_INSET = 2,
            HEALTH_WIDTH = 100,
            HEALTH_HEIGHT = 13,
        },
        Pet = {
            WIDTH = 100,
            HEIGHT = 25,
            HEALTH_HEIGHT = 13,
            POWER_HEIGHT = 9,
            NAME_WIDTH = 64,
            NAME_FONT_OFFSET = -1,
            TARGET_HEIGHT = 13,
            TARGET_HEALTH_HEIGHT = 11,
        },
        Secondary = {
            WIDTH = 150,
            HEIGHT = 25,
            HEALTH_HEIGHT = 13,
            POWER_HEIGHT = 9,
            NAME_WIDTH = 105,
            FONT_OFFSET = -1,
        },
        Player = { FRAME_Y = -250 },
        Target = { FRAME_Y = -250 },
        Party = {
            PARTY_WIDTH = 200,
            PARTY_HEIGHT = 40,
            PARTY_SPACING = 41,
            PARTY_TOP_OFFSET = 145,
            NAME_WIDTH = 112,
            PET_WIDTH = 100,
            PET_HEIGHT = 25,
            PET_HEALTH_HEIGHT = 13,
            PET_POWER_HEIGHT = 9,
            PET_NAME_WIDTH = 64,
            TARGET_WIDTH = 100,
            TARGET_HEIGHT = 13,
            TARGET_HEALTH_HEIGHT = 11,
        },
        Raid = {
            FRAME_WIDTH = 75,
            FRAME_HEIGHT = 25,
            HEALTH_HEIGHT = 13,
            POWER_HEIGHT = 9,
            GROUP_COUNT = 8,
            GROUP_SIZE = 5,
            GROUP_SPACING = 2,
            MEMBER_SPACING = 1,
            PARTY_GAP = 2,
            LEFT_OFFSET = 100,
            AURA_SIZE = 6,
            MAX_BUFFS = 3,
            MAX_DEBUFFS = 3,
        },
        Auras = {
            DEFAULT_AURAS_PER_ROW = 8,
            TARGET_AURAS_PER_ROW = 10,
            AURA_SPACING = 1,
        },
        Indicators = {
            STATUS_ICON_SIZE = 12,
        },
    },
}
