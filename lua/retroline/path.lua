---@class retroline.PathModule
---@field normalize_opts fun(opts: retroline.PathOpts|nil): retroline.PathOpts
---@field component_for_buffer fun(bufnr: integer, opts?: retroline.PathOpts): string
---@field component fun(opts?: retroline.PathOpts): string

---@type retroline.StateModule
local state = require("retroline.state")

---@type retroline.PathModule
local M = {}

---@type table<string, string>
local special_filetype_labels = {
  snacks_layout_box = "Explorer",
  snacks_picker_input = "Search",
  snacks_picker_list = "Results",
  snacks_picker_preview = "Preview",
  ["neo-tree"] = "Explorer",
  NvimTree = "Explorer",
  oil = "Explorer",
  qf = "Quickfix",
  help = "Help",
}

---@param text string
---@return string
local function title_case(text)
  ---@type string
  local lower = string.lower(text)
  return (lower:gsub("(%a)([%w_]*)", function(first, rest)
    return string.upper(first) .. string.lower(rest)
  end))
end

---@param name string
---@return string
local function bracket_name_to_label(name)
  ---@type string
  local inner = name:gsub("^<", ""):gsub(">$", "")
  inner = inner:gsub("_", " ")
  if inner == "" then
    return "[Panel]"
  end
  return "[" .. title_case(inner) .. "]"
end

---@param path string
---@return string[]
local function split_path(path)
  ---@type string[]
  local segments = {}
  for segment in string.gmatch(path, "[^/]+") do
    table.insert(segments, segment)
  end
  return segments
end

---@param path string
---@return string
local function path_prefix(path)
  if vim.startswith(path, "~/") then
    return "~/"
  end
  if vim.startswith(path, "/") then
    return "/"
  end
  return ""
end

---@param path string
---@param opts retroline.PathOpts
---@return string
local function smart_shorten_path(path, opts)
  ---@type integer
  local width = vim.fn.strdisplaywidth(path)
  if opts.max_length <= 0 or width <= opts.max_length then
    return path
  end

  ---@type string[]
  local segments = split_path(path)
  if #segments == 0 then
    return path
  end

  ---@type integer
  local keep_segments = math.max(1, opts.keep_segments)
  ---@type integer
  local shorten_len = math.max(1, opts.shorten_len)
  ---@type integer
  local keep_from = math.max(1, (#segments - keep_segments) + 1)
  ---@type string[]
  local shortened = {}

  for index, segment in ipairs(segments) do
    if index < keep_from then
      ---@type string
      local short = string.sub(segment, 1, shorten_len)
      if short == "" then
        short = segment
      end
      table.insert(shortened, short)
    else
      table.insert(shortened, segment)
    end
  end

  ---@type string
  local candidate = path_prefix(path) .. table.concat(shortened, "/")
  if vim.fn.strdisplaywidth(candidate) <= opts.max_length then
    return candidate
  end

  ---@type integer
  local tail_start = math.max(1, (#segments - keep_segments) + 1)
  ---@type string[]
  local tail = {}
  for index = tail_start, #segments do
    table.insert(tail, segments[index])
  end

  ---@type string
  local tail_text = table.concat(tail, "/")
  ---@type string
  local truncated = opts.trunc_prefix .. tail_text
  if vim.fn.strdisplaywidth(truncated) <= opts.max_length then
    return truncated
  end
  if vim.fn.strdisplaywidth(tail_text) <= opts.max_length then
    return tail_text
  end

  ---@type integer
  local cut_from = math.max(1, (#tail_text - opts.max_length) + 1)
  return string.sub(tail_text, cut_from)
end

---@param bufnr integer
---@param opts retroline.PathOpts
---@return string
local function format_buffer_path(bufnr, opts)
  ---@type string
  local ft = vim.bo[bufnr].filetype
  ---@type string
  local bt = vim.bo[bufnr].buftype
  ---@type retroline.StatuslineOpts
  local statusline_opts = state.runtime.config.statusline or state.defaults.statusline
  ---@type string|nil
  local special_label = statusline_opts.sidebar_labels[ft] or special_filetype_labels[ft]
  if special_label ~= nil then
    return "[" .. special_label .. "]"
  end
  if bt == "terminal" then
    return "[Terminal]"
  end

  ---@type string
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end
  if name:match("^<.+>$") ~= nil then
    return bracket_name_to_label(name)
  end

  ---@type string
  local path = ""
  if opts.style == "filename" then
    path = vim.fn.fnamemodify(name, ":t")
  elseif opts.style == "absolute" then
    path = vim.fn.fnamemodify(name, ":~")
  else
    path = vim.fn.fnamemodify(name, ":~:.")
  end

  return smart_shorten_path(path, opts)
end

---@param opts retroline.PathOpts|nil
---@return retroline.PathOpts
function M.normalize_opts(opts)
  ---@type retroline.PathOpts
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults.path), opts or {})
  if merged.style ~= "relative" and merged.style ~= "absolute" and merged.style ~= "filename" then
    merged.style = "relative"
  end
  if type(merged.max_length) ~= "number" then
    merged.max_length = state.defaults.path.max_length
  end
  if type(merged.shorten_len) ~= "number" then
    merged.shorten_len = state.defaults.path.shorten_len
  end
  if type(merged.keep_segments) ~= "number" then
    merged.keep_segments = state.defaults.path.keep_segments
  end
  merged.max_length = math.max(8, math.floor(merged.max_length))
  merged.shorten_len = math.max(1, math.floor(merged.shorten_len))
  merged.keep_segments = math.max(1, math.floor(merged.keep_segments))
  if type(merged.trunc_prefix) ~= "string" or merged.trunc_prefix == "" then
    merged.trunc_prefix = ".../"
  end
  return merged
end

---@param bufnr integer
---@param opts? retroline.PathOpts
---@return string
function M.component_for_buffer(bufnr, opts)
  if vim.api.nvim_buf_is_valid(bufnr) == false then
    return "[No Name]"
  end

  ---@type retroline.PathOpts
  local merged = state.runtime.config.path
  if opts ~= nil then
    merged = M.normalize_opts(vim.tbl_deep_extend("force", vim.deepcopy(state.runtime.config.path), opts))
  end
  return format_buffer_path(bufnr, merged)
end

---@param opts? retroline.PathOpts
---@return string
function M.component(opts)
  return M.component_for_buffer(vim.api.nvim_get_current_buf(), opts)
end

return M
