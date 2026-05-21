<h1 align="center">retroline.nvim</h1>

<p align="center">
  <strong>Animated statusline for Neovim</strong>
</p>

<p align="center">
  <a href="https://neovim.io">
    <img src="https://img.shields.io/badge/Neovim-0.12+-57A143?style=flat" alt="Neovim">
  </a>
  <a href="https://github.com/valonmulolli/retroline.nvim">
    <img src="https://img.shields.io/github/license/valonmulolli/retroline.nvim?style=flat&color=blue" alt="License">
  </a>
</p>

---

## Features

- **Timer-driven animation** -- 21 status presets with configurable intervals
- **Smart idle** -- timer pauses when idle, wakes on keystroke or mode change
- **Animated mode indicator** -- mode labels (N, I, V, etc.) with marker animations
- **Smart path shortening** -- truncates deep paths intelligently
- **Cached diagnostics** -- severity counts with per-severity pulse animations
- **Adaptive layouts** -- full, compact, or minimal based on window width
- **Retro mode** -- bracketed chips, hardware-themed presets, compact-biased thresholds
- **Context segments** -- optional Git branch and LSP client info
- **Built-in renderer** -- `retroline.statusline()` works out of the box
- **Standalone components** -- use `mode_component()`, `path_component()`, etc. in custom statuslines

---

## Install

### lazy.nvim

```lua
{
  "valonmulolli/retroline.nvim",
  name = "retroline.nvim",
  event = "UIEnter",
  config = function()
    require("retroline").setup({
      animation = "orbit",
    })
  end,
}
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({
  {
    src = "https://github.com/valonmulolli/retroline.nvim",
    name = "retroline.nvim",
  },
})

require("retroline").setup({
  animation = "orbit",
})
```

---

## Usage

```lua
-- Enable the built-in statusline (sets laststatus=3)
require("retroline").enable_statusline()

-- Or use individual components in your own statusline
local retroline = require("retroline")
local my_statusline = function()
  return table.concat({
    retroline.mode_component(),
    retroline.path_component(),
    "%=",
    retroline.diagnostic_component(),
  })
end
vim.o.statusline = "%!v:lua.vim.api.nvim_eval_statusline(vim.o.statusline, {})"
```

### Cycle animations at runtime

```lua
-- Status animation
require("retroline").next_animation()

-- Mode marker
require("retroline").next_mode_animation()

-- Diagnostic animation
require("retroline").next_diagnostic_animation()
```

---

## API

| Method | Returns | Description |
|---|---|---|
| `setup(opts)` | `nil` | Configure retroline |
| `start()` / `stop()` / `toggle()` | `nil` | Timer lifecycle |
| `is_running()` | `boolean` | Check if timer is active |
| `component()` | `string` | Current animation frame |
| `mode_component(opts?)` | `string` | Animated mode label |
| `path_component(opts?)` | `string` | Formatted file path |
| `diagnostic_component(opts?)` | `string` | Diagnostic counts with animation |
| `statusline()` | `string` | Full rendered statusline |
| `enable_statusline()` / `disable_statusline()` | `nil` | Built-in statusline toggle |
| `set_animation(name)` / `next_animation()` | `string` | Cycle status animation |
| `current_animation()` / `list_animations()` | `string`/`string[]` | Query status animation |
| `set_mode_animation(name)` / `next_mode_animation()` | `string` | Cycle mode animation |
| `current_mode_animation()` / `list_mode_animations()` | `string`/`string[]` | Query mode animation |
| `set_diagnostic_animation(name)` / `next_diagnostic_animation()` | `string` | Cycle diagnostic animation |
| `current_diagnostic_animation()` / `list_diagnostic_animations()` | `string`/`string[]` | Query diagnostic animation |

---

## Animation Presets

### Status (21)

`dots` `line` `pulse` `meter` `bounce` `snake` `trail` `scan` `binary` `orbit` `tunnel` `ladder` `rover` `flicker` `zipper` `ramps` `retro_scan` `retro_blink` `retro_boot` `retro_modem` `retro_probe`

### Mode marker (15)

`spin` `pulse` `wave` `bounce` `chevron` `blink` `dot3` `arrow` `spark` `steps` `retro_cursor` `retro_block` `retro_ticks` `retro_prompt` `retro_gate`

### Diagnostic (6)

`ascii_alert` `ascii_wave` `ascii_blink` `ascii_meter` `retro_alarm` `retro_panel`

---

## Default Config

```lua
{
  enabled = true,
  animation = "dots",
  interval = 150,
  frames = { ".  ", ".. ", "..." },
  mode = {
    style = "short",       -- "short" | "long"
    animate = true,
    animation = "spin",
    separator = "",
  },
  path = {
    style = "relative",    -- "relative" | "absolute" | "filename"
    max_length = 56,
    shorten_len = 1,
    keep_segments = 2,
    trunc_prefix = ".../",
  },
  diagnostic = {
    enabled = true,
    scope = "buffer",      -- "buffer" | "workspace"
    style = "full",        -- "minimal" | "compact" | "full"
    animate = true,
    animate_severities = { "ERROR", "WARN", "INFO", "HINT", "OK" },
    animation = "ascii_alert",
    show_zero = false,
    use_highlights = true,
    separator = " ",
    empty = "OK",
    labels = { ERROR = "E", WARN = "W", INFO = "I", HINT = "H" },
  },
  statusline = {
    style = "rounded",     -- "rounded" | "square" | "none"
    global = true,
    sidebar_minimal = true,
    sidebar_filetypes = {
      "snacks_layout_box", "snacks_picker_input", "snacks_picker_list",
      "snacks_picker_preview", "neo-tree", "NvimTree", "oil", "qf",
    },
    sidebar_labels = {
      snacks_layout_box = "Explorer",
      snacks_picker_input = "Search",
      snacks_picker_list = "Results",
      snacks_picker_preview = "Preview",
      ["neo-tree"] = "Explorer", NvimTree = "Explorer",
      oil = "Explorer", qf = "Quickfix",
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
  skip_filetypes = {
    "snacks_dashboard", "dashboard", "alpha", "starter", "snacks_layout_box",
  },
}
```

---

## Tests

```sh
nvim --headless -u NONE -i NONE --cmd "set rtp+=. shadafile=NONE" -l scripts/test.lua
```

---

## Internal Layout

```
lua/retroline/
├── init.lua                 -- Public API facade
├── setup.lua                -- Config merge, autocmd wiring
├── state.lua                -- Defaults, runtime state, animation tables
├── lifecycle.lua            -- UV timer lifecycle (start/stop/tick)
├── animations.lua           -- Frame resolution, animation cycling
├── mode.lua                 -- Mode labels, mode marker animation
├── path.lua                 -- Path formatting, smart shortening
├── diagnostics.lua          -- Cached diagnostics, severity animation
├── highlights.lua           -- Highlight groups (default/retro/transparent)
├── statusline.lua           -- Statusline module facade
├── api/
│   ├── base.lua             -- Core API methods
│   └── presets.lua          -- Animation preset cycling API
└── statusline/
    ├── options.lua          -- Option normalization, layout selection
    ├── style.lua            -- Section delimiters, retro chip helpers
    ├── context.lua          -- Cached git branch + LSP info
    ├── render.lua           -- Statusline string builder
    └── manage.lua           -- Enable/disable, per-window management
```
