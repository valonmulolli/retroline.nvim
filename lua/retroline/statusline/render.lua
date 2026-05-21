---@class retroline.StatuslineRenderModule
---@field render fun(): string

---@type retroline.StateModule
local state = require("retroline.state")
---@type retroline.AnimationModule
local animations = require("retroline.animations")
---@type retroline.ModeModule
local mode = require("retroline.mode")
---@type retroline.PathModule
local path = require("retroline.path")
---@type retroline.DiagnosticsModule
local diagnostics = require("retroline.diagnostics")
---@type retroline.HighlightsModule
local highlights = require("retroline.highlights")
---@type retroline.StatuslineOptionsModule
local options = require("retroline.statusline.options")
---@type retroline.StatuslineStyleModule
local style = require("retroline.statusline.style")
---@type retroline.StatuslineContextModule
local context = require("retroline.statusline.context")

---@type retroline.StatuslineRenderModule
local M = {}

---@return integer
local function target_winid()
  ---@type integer
  local winid = tonumber(vim.g.statusline_winid) or 0
  if winid ~= 0 and vim.api.nvim_win_is_valid(winid) then
    return winid
  end
  return vim.api.nvim_get_current_win()
end

---@param label string
---@param text string
---@param layout string
---@return string
local function retro_segment_text(label, text, layout)
  if layout == "full" then
    return label .. " " .. text
  end
  return string.sub(label, 1, 1) .. ":" .. text
end

---@param opts retroline.StatuslineOpts
---@param filetype string
---@return string
local function sidebar_statusline(opts, filetype)
  ---@type string
  local label = opts.sidebar_labels[filetype] or (filetype ~= "" and filetype or "Panel")
  if opts.retro then
    label = string.upper(label)
  end
  ---@type string
  local chip_text = opts.retro and style.retro_chip(label) or label
  ---@type string
  local left = style.wrap("RetrolineMuted", opts.pad .. chip_text .. opts.pad)
  return left .. "%="
end

---@param config retroline.Config
---@param layout string
---@param width integer
---@param bufnr integer
---@return string
local function path_for_layout(config, layout, width, bufnr)
  if layout == "full" then
    return path.component_for_buffer(bufnr)
  end

  ---@type retroline.PathOpts
  local path_opts = vim.deepcopy(config.path)
  if layout == "minimal" then
    path_opts.style = "filename"
    path_opts.keep_segments = 1
    path_opts.max_length = math.max(12, math.floor(width * 0.52))
  else
    path_opts.keep_segments = math.max(1, config.path.keep_segments)
    path_opts.max_length = math.max(18, math.floor(width * 0.45))
  end
  return path.component_for_buffer(bufnr, path_opts)
end

---@param config retroline.Config
---@param layout string
---@param bufnr integer
---@return string
local function diagnostics_for_layout(config, layout, bufnr)
  ---@type retroline.DiagnosticOpts|nil
  local diagnostic_opts = nil
  if layout ~= "full" then
    diagnostic_opts = vim.deepcopy(config.diagnostic)
    if layout == "minimal" then
      diagnostic_opts.style = "minimal"
      diagnostic_opts.animate = false
    else
      diagnostic_opts.style = "compact"
    end
  end
  return diagnostics.component_for_buffer(bufnr, diagnostic_opts)
end

---@param opts retroline.StatuslineOpts
---@param layout string
---@param bufnr integer
---@return string, string
local function context_blocks(opts, layout, bufnr)
  if layout == "minimal" then
    return "", ""
  end

  ---@type string
  local git = ""
  ---@type string
  local lsp = ""
  if opts.show_git or opts.show_lsp then
    git, lsp = context.context_for_buffer(bufnr)
  end

  ---@type string
  local git_block = ""
  if opts.show_git and git ~= "" then
    ---@type string
    local text = opts.retro
      and style.retro_chip(retro_segment_text("GIT", git, layout))
      or ("git:" .. git)
    git_block = style.wrap("RetrolineMuted", opts.pad .. text)
  end

  ---@type string
  local lsp_block = ""
  if opts.show_lsp and lsp ~= "" and layout == "full" then
    ---@type string
    local text = opts.retro
      and style.retro_chip(retro_segment_text("LSP", lsp, layout))
      or ("lsp:" .. lsp)
    lsp_block = style.wrap("RetrolineMuted", opts.pad .. text)
  end

  return git_block, lsp_block
end

---@param opts retroline.StatuslineOpts
---@param left_delim string
---@param right_delim string
---@param layout string
---@return string
local function mode_for_layout(opts, left_delim, right_delim, layout)
  ---@type retroline.ModeOpts|nil
  local mode_opts = nil
  if layout == "minimal" then
    mode_opts = { style = "short", animate = false, animation = "spin", separator = "" }
  end
  ---@type string
  local mode_text = mode.component(mode_opts)
  ---@type string
  local mode_group = highlights.mode_group(mode.current_mode())
  if opts.retro then
    mode_text = retro_segment_text("MODE", mode_text, layout)
    return highlights.wrap(mode_group, style.retro_chip(mode_text))
  end
  return highlights.wrap(mode_group, left_delim .. mode_text .. right_delim)
end

---@return string
function M.render()
  ---@type integer
  local winid = target_winid()
  ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return ""
  end
  ---@type retroline.Config
  local config = state.runtime.config
  ---@type retroline.StatuslineOpts
  local opts = config.statusline
  if opts == nil then
    opts = options.normalize_opts(nil)
  end
  ---@type string
  local filetype = vim.bo[bufnr].filetype
  if options.is_sidebar(opts, filetype) then
    return sidebar_statusline(opts, filetype)
  end
  ---@type integer
  local width = vim.api.nvim_win_get_width(winid)
  ---@type string
  local layout = options.resolve_layout(opts, width)
  ---@type string
  local left_delim, right_delim = style.section_delims(opts.style)
  if opts.retro then
    left_delim, right_delim = "[", "]"
  end

  ---@type string
  local mode_block = mode_for_layout(opts, left_delim, right_delim, layout)
  ---@type string
  local path_text = path_for_layout(config, layout, width, bufnr)
  if opts.retro then
    ---@type string
    local path_label = layout == "full" and "PATH" or "FILE"
    path_text = retro_segment_text(path_label, path_text, layout)
    path_text = style.retro_chip(path_text)
  end
  ---@type string
  local path_block = style.wrap("RetrolinePath", opts.pad .. path_text .. opts.pad)

  ---@type string
  local anim = ""
  if layout == "full" then
    if opts.retro then
      anim = highlights.wrap("RetrolineAnim", opts.pad .. style.retro_chip(animations.current_frame()) .. opts.pad)
    else
      anim = style.wrap("RetrolineAnim", opts.pad .. animations.current_frame() .. opts.pad)
    end
  end

  ---@type string
  local flags = ""
  if opts.show_flags and layout == "full" then
    flags = style.wrap("RetrolineMuted", "%h%m%r")
  end

  ---@type string
  local filetype_text = ""
  if opts.show_filetype and layout ~= "minimal" then
    if opts.retro then
      ---@type string
      local chip_text = layout == "full" and "FT %y" or "T:%y"
      filetype_text = style.wrap("RetrolineMuted", opts.pad .. style.retro_chip(chip_text))
    else
      filetype_text = style.wrap("RetrolineMuted", opts.pad .. "%y")
    end
  end

  ---@type string
  local diagnostics_block = diagnostics_for_layout(config, layout, bufnr)
  if diagnostics_block ~= "" then
    if opts.retro and layout ~= "full" and config.diagnostic.animation ~= "retro_alarm" then
      diagnostics_block = style.wrap("RetrolineMuted", opts.pad .. "[") .. diagnostics_block
        .. style.wrap("RetrolineMuted", "]")
    else
      diagnostics_block = opts.pad .. diagnostics_block
    end
  end

  ---@type string, string
  local git_block, lsp_block = context_blocks(opts, layout, bufnr)

  ---@type string
  local location = ""
  if opts.show_location then
    if layout == "minimal" then
      location = opts.retro and style.retro_chip(retro_segment_text("LINE", "%l", layout)) or "%l"
    else
      ---@type string
      local location_label = layout == "full" and "POS" or "LINE"
      location = opts.retro
        and style.retro_chip(retro_segment_text(location_label, "%l:%c", layout))
        or "%l:%c"
    end
  end

  ---@type string
  local progress = ""
  if opts.show_progress and (layout == "full" or (opts.retro and layout == "compact")) then
    ---@type string
    local progress_label = layout == "full" and "TOP" or "PCT"
    progress = opts.retro
      and style.retro_chip(retro_segment_text(progress_label, "%p%%", layout))
      or "%p%%"
  end

  ---@type string
  local left = table.concat({
    mode_block,
    opts.pad,
    "%<",
    path_block,
    flags,
    filetype_text,
  })

  ---@type string
  local location_block = location ~= "" and (opts.pad .. location) or ""
  ---@type string
  local progress_block = progress ~= "" and (opts.pad .. progress) or ""

  ---@type string
  local right = table.concat({
    git_block,
    lsp_block,
    diagnostics_block,
    location_block,
    progress_block,
    opts.pad,
  })

  if layout == "full" and anim ~= "" then
    return left .. "%=" .. anim .. "%=" .. right
  end
  return left .. "%=" .. right
end

return M
