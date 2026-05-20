---@class retroline.AnimationPreset
---@field frames string[]
---@field interval integer

---@class retroline.ModeOpts
---@field style string
---@field animate boolean
---@field animation string
---@field separator string

---@class retroline.PathOpts
---@field style string
---@field max_length integer
---@field shorten_len integer
---@field keep_segments integer
---@field trunc_prefix string

---@class retroline.DiagnosticOpts
---@field enabled boolean
---@field scope string
---@field style string
---@field animate boolean
---@field animate_severities string[]
---@field animation string
---@field show_zero boolean
---@field use_highlights boolean
---@field separator string
---@field empty string
---@field labels table<string, string>

---@class retroline.DiagnosticAnimationPreset
---@field ERROR string[]
---@field WARN string[]
---@field INFO string[]
---@field HINT string[]
---@field OK string[]

---@class retroline.StatuslineOpts
---@field style string
---@field global boolean
---@field sidebar_minimal boolean
---@field sidebar_filetypes string[]
---@field sidebar_labels table<string, string>
---@field retro boolean
---@field transparent boolean
---@field adaptive boolean
---@field compact_width integer
---@field minimal_width integer
---@field show_filetype boolean
---@field show_flags boolean
---@field show_git boolean
---@field show_lsp boolean
---@field show_location boolean
---@field show_progress boolean
---@field pad string

---@class retroline.PerformanceOpts
---@field smart_idle boolean
---@field idle_timeout integer
---@field stop_timer_on_idle boolean
---@field active_mode_prefixes string[]
---@field diagnostic_pulse integer

---@class retroline.Config
---@field enabled boolean
---@field animation string
---@field interval integer
---@field frames string[]
---@field mode retroline.ModeOpts
---@field path retroline.PathOpts
---@field diagnostic retroline.DiagnosticOpts
---@field statusline retroline.StatuslineOpts
---@field performance retroline.PerformanceOpts
---@field skip_filetypes string[]

---@class retroline.RuntimeState
---@field config retroline.Config
---@field frame_index integer
---@field timer uv.uv_timer_t|nil
---@field running boolean
---@field augroup integer|nil
---@field statusline_enabled boolean
---@field statusline_prev_global string|nil
---@field statusline_prev_laststatus integer|nil
---@field statusline_prev_windows table<integer, string>
 ---@field last_activity integer
 ---@field diag_alert_until integer
 ---@field diag_alert_severity string

---@class retroline.StateModule
---@field animations table<string, retroline.AnimationPreset>
---@field animation_names string[]
---@field mode_animations table<string, string[]>
---@field mode_animation_names string[]
---@field diagnostic_animations table<string, retroline.DiagnosticAnimationPreset>
---@field diagnostic_animation_names string[]
---@field defaults retroline.Config
---@field runtime retroline.RuntimeState

---@type retroline.StateModule
local M = {}

---@type table<string, retroline.AnimationPreset>
M.animations = {
  dots = {
    frames = { ".  ", ".. ", "..." },
    interval = 150,
  },
  line = {
    frames = { "|  ", "/  ", "-  ", "\\  " },
    interval = 90,
  },
  pulse = {
    frames = { "o  ", "oo ", "ooo", " oo", "  o" },
    interval = 120,
  },
  meter = {
    frames = { "[---]", "[=--]", "[==-]", "[===]", "[-==]", "[--=]" },
    interval = 110,
  },
  bounce = {
    frames = { "<   ", " <  ", "  < ", "   <", "  < ", " <  " },
    interval = 95,
  },
  snake = {
    frames = { "><  ", " <> ", "  ><", " <> " },
    interval = 100,
  },
  trail = {
    frames = { ">   ", "=>  ", "==> ", "===>", " ==>", "  =>", "   >", "  =>", " ==>", "===>" },
    interval = 85,
  },
  scan = {
    frames = { "|...", ".|..", "..|.", "...|", "..|.", ".|.." },
    interval = 95,
  },
  binary = {
    frames = { "0001", "0010", "0100", "1000", "0100", "0010" },
    interval = 105,
  },
  orbit = {
    frames = { "(   )", "(.  )", "(.. )", "(...)", "( ..)", "(  .)" },
    interval = 95,
  },
  tunnel = {
    frames = { "[   ]", "[ . ]", "[ ..]", "[...]", "[.. ]", "[.  ]" },
    interval = 100,
  },
  ladder = {
    frames = { "_   ", "__  ", "___ ", "____", " ___", "  __", "   _" },
    interval = 90,
  },
  rover = {
    frames = { "^   ", " ^  ", "  ^ ", "   ^", "  ^ ", " ^  " },
    interval = 85,
  },
  flicker = {
    frames = { "`   ", "'   ", ".   ", "*   ", ".   ", "'   " },
    interval = 80,
  },
  zipper = {
    frames = { "<><>", "><><", "<><>", "><><" },
    interval = 95,
  },
  ramps = {
    frames = { "[   ]", "[=  ]", "[== ]", "[===]", "[ ==]", "[  =]" },
    interval = 100,
  },
  retro_scan = {
    frames = { "[=   ]", "[==  ]", "[=== ]", "[ ===]", "[  ==]", "[   =]" },
    interval = 90,
  },
  retro_blink = {
    frames = { "#   ", ".   ", "#   ", ".   " },
    interval = 80,
  },
  retro_boot = {
    frames = { "BIOS", "BOOT", "LOAD", "RUN " },
    interval = 140,
  },
  retro_modem = {
    frames = { "AT  ", "ATZ ", "ATDT", "RING", "LINK" },
    interval = 125,
  },
  retro_probe = {
    frames = { "ROM ", "RAM ", "I/O ", "CRT ", "RDY " },
    interval = 115,
  },
}

---@type string[]
M.animation_names = {
  "dots",
  "line",
  "pulse",
  "meter",
  "bounce",
  "snake",
  "trail",
  "scan",
  "binary",
  "orbit",
  "tunnel",
  "ladder",
  "rover",
  "flicker",
  "zipper",
  "ramps",
  "retro_scan",
  "retro_blink",
  "retro_boot",
  "retro_modem",
  "retro_probe",
}

---@type table<string, string[]>
M.mode_animations = {
  spin = { "|", "/", "-", "\\" },
  pulse = { ".", "o", "O", "o" },
  wave = { "~", "^", "~", "-" },
  bounce = { ".", ":", "*", ":" },
  chevron = { ">  ", ">> ", ">>>", ">> " },
  blink = { ".", " ", ".", " " },
  dot3 = { "   ", ".  ", ".. ", "...", ".. ", ".  " },
  arrow = { ">  ", ">> ", ">>>", " >>", "  >" },
  spark = { ".  ", "o  ", "O  ", "o  " },
  steps = { "1  ", "12 ", "123", " 23", "  3" },
  retro_cursor = { "_", " ", "_", " " },
  retro_block = { "[]", "##", "[]", "##" },
  retro_ticks = { "t1", "t2", "t3", "t4" },
  retro_prompt = { ">", ">|", ">>", ">|" },
  retro_gate = { "[]", "[|", "[]", "|]" },
}

---@type string[]
M.mode_animation_names = {
  "spin",
  "pulse",
  "wave",
  "bounce",
  "chevron",
  "blink",
  "dot3",
  "arrow",
  "spark",
  "steps",
  "retro_cursor",
  "retro_block",
  "retro_ticks",
  "retro_prompt",
  "retro_gate",
}

---@type table<string, retroline.DiagnosticAnimationPreset>
M.diagnostic_animations = {
  ascii_alert = {
    ERROR = { "!!", "!x", "x!", "!!" },
    WARN = { "??", "?~", "~?", "??" },
    INFO = { "ii", "i.", ".i", "ii" },
    HINT = { "..", ".:", ":.", ".." },
    OK = { "--", "==", "--", "==" },
  },
  ascii_wave = {
    ERROR = { "!!", "!!>", "!!>>", "!!>" },
    WARN = { "??", "??>", "??>>", "??>" },
    INFO = { "ii", "ii>", "ii>>", "ii>" },
    HINT = { "..", "..>", "..>>", "..>" },
    OK = { "--", "-->", "-->>", "-->" },
  },
  ascii_blink = {
    ERROR = { "!!", "  ", "!!", "  " },
    WARN = { "??", "  ", "??", "  " },
    INFO = { "ii", "  ", "ii", "  " },
    HINT = { "..", "  ", "..", "  " },
    OK = { "ok", "  ", "ok", "  " },
  },
  ascii_meter = {
    ERROR = { "[!  ]", "[!! ]", "[!!!]", "[ !!]" },
    WARN = { "[?  ]", "[?? ]", "[???]", "[ ??]" },
    INFO = { "[i  ]", "[ii ]", "[iii]", "[ ii]" },
    HINT = { "[.  ]", "[.. ]", "[...]", "[ ..]" },
    OK = { "[ok ]", "[ ok]", "[ok ]", "[ ok]" },
  },
  retro_alarm = {
    ERROR = { "[!!]", "<!!>", "[!!]", "<!!>" },
    WARN = { "[??]", "<~~>", "[??]", "<~~>" },
    INFO = { "[ii]", "<ii>", "[ii]", "<ii>" },
    HINT = { "[..]", "<..>", "[..]", "<..>" },
    OK = { "[OK]", "[ok]", "[OK]", "[ok]" },
  },
  retro_panel = {
    ERROR = { "ERR", "E!!", "ERR", "E!!" },
    WARN = { "WRN", "W??", "WRN", "W??" },
    INFO = { "INF", "I::", "INF", "I::" },
    HINT = { "HNT", "H..", "HNT", "H.." },
    OK = { "RDY", "RUN", "RDY", "RUN" },
  },
}

---@type string[]
M.diagnostic_animation_names = { "ascii_alert", "ascii_wave", "ascii_blink", "ascii_meter", "retro_alarm", "retro_panel" }

---@type retroline.Config
M.defaults = {
  enabled = true,
  animation = "dots",
  interval = 150,
  frames = { ".  ", ".. ", "..." },
  mode = {
    style = "short",
    animate = true,
    animation = "spin",
    separator = "",
  },
  path = {
    style = "relative",
    max_length = 56,
    shorten_len = 1,
    keep_segments = 2,
    trunc_prefix = ".../",
  },
  diagnostic = {
    enabled = true,
    scope = "buffer",
    style = "full",
    animate = true,
    animate_severities = { "ERROR", "WARN", "INFO", "HINT", "OK" },
    animation = "ascii_alert",
    show_zero = false,
    use_highlights = true,
    separator = " ",
    empty = "OK",
    labels = {
      ERROR = "E",
      WARN = "W",
      INFO = "I",
      HINT = "H",
    },
  },
  statusline = {
    style = "rounded",
    global = true,
    sidebar_minimal = true,
    sidebar_filetypes = {
      "snacks_layout_box",
      "snacks_picker_input",
      "snacks_picker_list",
      "snacks_picker_preview",
      "neo-tree",
      "NvimTree",
      "oil",
      "qf",
    },
    sidebar_labels = {
      snacks_layout_box = "Explorer",
      snacks_picker_input = "Search",
      snacks_picker_list = "Results",
      snacks_picker_preview = "Preview",
      ["neo-tree"] = "Explorer",
      NvimTree = "Explorer",
      oil = "Explorer",
      qf = "Quickfix",
    },
    retro = false,
    transparent = false,
    adaptive = true,
    compact_width = 108,
    minimal_width = 82,
    show_filetype = true,
    show_flags = true,
    show_git = true,
    show_lsp = true,
    show_location = true,
    show_progress = true,
    pad = " ",
  },
  performance = {
    smart_idle = true,
    idle_timeout = 1200,
    stop_timer_on_idle = true,
    active_mode_prefixes = { "i", "R", "v", "V", "\22", "c", "s", "t" },
    diagnostic_pulse = 1600,
  },
  skip_filetypes = { "snacks_dashboard", "dashboard", "alpha", "starter", "snacks_layout_box" },
}

---@type retroline.RuntimeState
M.runtime = {
  config = vim.deepcopy(M.defaults),
  frame_index = 1,
  timer = nil,
  running = false,
  augroup = nil,
  statusline_enabled = false,
  statusline_prev_global = nil,
  statusline_prev_laststatus = nil,
  statusline_prev_windows = {},
  last_activity = 0,
  diag_alert_until = 0,
  diag_alert_severity = "",
}

return M
