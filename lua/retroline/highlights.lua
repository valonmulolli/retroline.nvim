---@class retroline.HighlightsModule
---@field setup fun(): nil
---@field mode_group fun(raw_mode: string): string
---@field wrap fun(group: string, text: string): string

---@type retroline.StateModule
local state = require("retroline.state")

---@type retroline.HighlightsModule
local M = {}

---@type table<string, string>
local retro_palette = {
  bg = "#27251e",
  accent_dim = "#22808c",
  bright = "#ffffff",
  accent = "#32b8c6",
  text = "#d6d5d4",
  panel = "#0f3639",
  error = "#ff5f5f",
  blue = "#0066cc",
  green = "#9fe870",
  blue_dark = "#0b4c72",
  blue_bright = "#0099ff",
  mint = "#83d6c5",
}

---@type table<string, string>
local mode_group_prefix = {
  n = "RetrolineModeNormal",
  i = "RetrolineModeInsert",
  v = "RetrolineModeVisual",
  V = "RetrolineModeVisual",
  ["\22"] = "RetrolineModeVisual",
  R = "RetrolineModeReplace",
  c = "RetrolineModeCommand",
  t = "RetrolineModeTerminal",
  s = "RetrolineModeVisual",
}

---@param group string
---@param text string
---@return string
function M.wrap(group, text)
  return "%#" .. group .. "#" .. text .. "%*"
end

---@param raw_mode string
---@return string
function M.mode_group(raw_mode)
  ---@type string
  local prefix = string.sub(raw_mode, 1, 1)
  return mode_group_prefix[prefix] or "RetrolineModeNormal"
end

---@param color string
---@return integer
local function hex(color)
  return tonumber(string.sub(color, 2), 16) or 0
end

---@param group string
---@param fallback integer
---@return integer
local function fg_from(group, fallback)
  ---@type boolean
  local ok
  ---@type table<string, any>
  local hl
  ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = true })
  if ok and type(hl) == "table" and type(hl.fg) == "number" then
    return hl.fg
  end
  return fallback
end

---@return nil
local function setup_default()
  vim.api.nvim_set_hl(0, "RetrolineAnim", { link = "Special" })
  vim.api.nvim_set_hl(0, "RetrolinePath", { link = "StatusLine" })
  vim.api.nvim_set_hl(0, "RetrolineMuted", { link = "Comment" })

  vim.api.nvim_set_hl(0, "RetrolineModeNormal", { link = "StatusLine" })
  vim.api.nvim_set_hl(0, "RetrolineModeInsert", { link = "String" })
  vim.api.nvim_set_hl(0, "RetrolineModeVisual", { link = "Type" })
  vim.api.nvim_set_hl(0, "RetrolineModeReplace", { link = "DiagnosticError" })
  vim.api.nvim_set_hl(0, "RetrolineModeCommand", { link = "Function" })
  vim.api.nvim_set_hl(0, "RetrolineModeTerminal", { link = "Special" })

  vim.api.nvim_set_hl(0, "RetrolineDiagError", { link = "DiagnosticError" })
  vim.api.nvim_set_hl(0, "RetrolineDiagWarn", { link = "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "RetrolineDiagInfo", { link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "RetrolineDiagHint", { link = "DiagnosticHint" })
  vim.api.nvim_set_hl(0, "RetrolineDiagOk", { link = "Comment" })
end

---@return nil
local function setup_retro()
  vim.api.nvim_set_hl(0, "RetrolinePath", { fg = hex(retro_palette.text), bg = hex(retro_palette.bg) })
  vim.api.nvim_set_hl(0, "RetrolineAnim", { fg = hex(retro_palette.bright), bg = hex(retro_palette.panel), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineMuted", { fg = hex(retro_palette.accent), bg = hex(retro_palette.bg) })

  vim.api.nvim_set_hl(0, "RetrolineModeNormal", { fg = hex(retro_palette.bright), bg = hex(retro_palette.panel), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeInsert", { fg = hex(retro_palette.bg), bg = hex(retro_palette.green), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeVisual", { fg = hex(retro_palette.bg), bg = hex(retro_palette.mint), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeReplace", { fg = hex(retro_palette.bright), bg = hex(retro_palette.blue_bright), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeCommand", { fg = hex(retro_palette.bright), bg = hex(retro_palette.accent_dim), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeTerminal", { fg = hex(retro_palette.bright), bg = hex(retro_palette.blue_dark), bold = true })

  vim.api.nvim_set_hl(0, "RetrolineDiagError", { fg = hex(retro_palette.error), bg = hex(retro_palette.bg), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineDiagWarn", { fg = hex(retro_palette.green), bg = hex(retro_palette.bg), bold = true })
  vim.api.nvim_set_hl(0, "RetrolineDiagInfo", { fg = hex(retro_palette.accent), bg = hex(retro_palette.bg) })
  vim.api.nvim_set_hl(0, "RetrolineDiagHint", { fg = hex(retro_palette.mint), bg = hex(retro_palette.bg) })
  vim.api.nvim_set_hl(0, "RetrolineDiagOk", { fg = hex(retro_palette.text), bg = hex(retro_palette.bg) })
end

---@return nil
local function setup_transparent()
  ---@type integer
  local normal_fg = fg_from("Normal", 0xC0C0C0)
  ---@type integer
  local comment_fg = fg_from("Comment", normal_fg)

  vim.api.nvim_set_hl(0, "RetrolinePath", { fg = normal_fg, bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineAnim", { fg = comment_fg, bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineMuted", { fg = comment_fg, bg = "NONE" })

  vim.api.nvim_set_hl(0, "RetrolineModeNormal", { fg = fg_from("Identifier", normal_fg), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeInsert", { fg = fg_from("String", normal_fg), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeVisual", { fg = fg_from("Type", normal_fg), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeReplace", { fg = fg_from("DiagnosticError", normal_fg), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeCommand", { fg = fg_from("Function", normal_fg), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeTerminal", { fg = fg_from("Special", normal_fg), bg = "NONE", bold = true })

  vim.api.nvim_set_hl(0, "RetrolineDiagError", { fg = fg_from("DiagnosticError", normal_fg), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineDiagWarn", { fg = fg_from("DiagnosticWarn", normal_fg), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineDiagInfo", { fg = fg_from("DiagnosticInfo", normal_fg), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineDiagHint", { fg = fg_from("DiagnosticHint", normal_fg), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineDiagOk", { fg = comment_fg, bg = "NONE" })
end

---@return nil
local function setup_retro_transparent()
  vim.api.nvim_set_hl(0, "RetrolinePath", { fg = hex(retro_palette.text), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineAnim", { fg = hex(retro_palette.accent), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineMuted", { fg = hex(retro_palette.accent_dim), bg = "NONE" })

  vim.api.nvim_set_hl(0, "RetrolineModeNormal", { fg = hex(retro_palette.bright), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeInsert", { fg = hex(retro_palette.green), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeVisual", { fg = hex(retro_palette.mint), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeReplace", { fg = hex(retro_palette.blue_bright), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeCommand", { fg = hex(retro_palette.accent), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineModeTerminal", { fg = hex(retro_palette.blue), bg = "NONE", bold = true })

  vim.api.nvim_set_hl(0, "RetrolineDiagError", { fg = hex(retro_palette.error), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineDiagWarn", { fg = hex(retro_palette.green), bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "RetrolineDiagInfo", { fg = hex(retro_palette.accent), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineDiagHint", { fg = hex(retro_palette.mint), bg = "NONE" })
  vim.api.nvim_set_hl(0, "RetrolineDiagOk", { fg = hex(retro_palette.text), bg = "NONE" })
end

---@return nil
function M.setup()
  ---@type retroline.StatuslineOpts
  local opts = state.runtime.config.statusline or state.defaults.statusline
  if opts.retro == true and opts.transparent == true then
    setup_retro_transparent()
    return
  end
  if opts.retro == true then
    setup_retro()
    return
  end
  if opts.transparent == true then
    setup_transparent()
    return
  end
  setup_default()
end

return M
