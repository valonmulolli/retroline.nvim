---@class retroline.StatuslineOptionsModule
---@field normalize_opts fun(opts: retroline.StatuslineOpts|nil): retroline.StatuslineOpts
---@field is_sidebar fun(opts: retroline.StatuslineOpts, filetype: string): boolean
---@field resolve_layout fun(opts: retroline.StatuslineOpts, width: integer): string

---@type retroline.StateModule
local state = require("retroline.state")

---@type retroline.StatuslineOptionsModule
local M = {}

---@param value string
---@param items string[]
---@return boolean
local function contains(value, items)
  for _, item in ipairs(items) do
    if item == value then
      return true
    end
  end
  return false
end

---@param opts retroline.StatuslineOpts|nil
---@return retroline.StatuslineOpts
function M.normalize_opts(opts)
  ---@type retroline.StatuslineOpts
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults.statusline), opts or {})
  if merged.style ~= "rounded" and merged.style ~= "square" and merged.style ~= "none" then
    merged.style = "rounded"
  end
  if type(merged.global) ~= "boolean" then
    merged.global = true
  end
  if type(merged.sidebar_minimal) ~= "boolean" then
    merged.sidebar_minimal = true
  end
  if type(merged.sidebar_filetypes) ~= "table" then
    merged.sidebar_filetypes = vim.deepcopy(state.defaults.statusline.sidebar_filetypes)
  end
  if type(merged.sidebar_labels) ~= "table" then
    merged.sidebar_labels = vim.deepcopy(state.defaults.statusline.sidebar_labels)
  end
  if type(merged.retro) ~= "boolean" then
    merged.retro = false
  end
  if type(merged.transparent) ~= "boolean" then
    merged.transparent = false
  end
  if type(merged.adaptive) ~= "boolean" then
    merged.adaptive = true
  end
  if type(merged.compact_width) ~= "number" then
    merged.compact_width = state.defaults.statusline.compact_width
  end
  if type(merged.minimal_width) ~= "number" then
    merged.minimal_width = state.defaults.statusline.minimal_width
  end
  merged.minimal_width = math.max(48, math.floor(merged.minimal_width))
  merged.compact_width = math.max(merged.minimal_width + 1, math.floor(merged.compact_width))
  if type(merged.show_filetype) ~= "boolean" then
    merged.show_filetype = true
  end
  if type(merged.show_flags) ~= "boolean" then
    merged.show_flags = true
  end
  if type(merged.show_git) ~= "boolean" then
    merged.show_git = true
  end
  if type(merged.show_lsp) ~= "boolean" then
    merged.show_lsp = true
  end
  if type(merged.show_location) ~= "boolean" then
    merged.show_location = true
  end
  if type(merged.show_progress) ~= "boolean" then
    merged.show_progress = true
  end
  if type(merged.pad) ~= "string" then
    merged.pad = " "
  end
  return merged
end

---@param opts retroline.StatuslineOpts
---@param filetype string
---@return boolean
function M.is_sidebar(opts, filetype)
  if opts.sidebar_minimal == false then
    return false
  end
  return contains(filetype, opts.sidebar_filetypes)
end

---@param opts retroline.StatuslineOpts
---@param width integer
---@return string
function M.resolve_layout(opts, width)
  ---@type integer
  local minimal_width = opts.minimal_width
  if opts.retro then
    minimal_width = math.min(minimal_width, 68)
  end
  if opts.adaptive == false then
    return "full"
  end
  if width <= minimal_width then
    return "minimal"
  end
  if width <= opts.compact_width then
    return "compact"
  end
  return "full"
end

return M
