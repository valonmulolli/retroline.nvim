---@class retroline.DiagnosticCounts
---@field ERROR integer
---@field WARN integer
---@field INFO integer
---@field HINT integer

---@class retroline.DiagnosticsModule
---@field normalize_opts fun(opts: retroline.DiagnosticOpts|nil): retroline.DiagnosticOpts
---@field component_for_buffer fun(bufnr: integer, opts?: retroline.DiagnosticOpts): string
---@field component fun(opts?: retroline.DiagnosticOpts): string
---@field refresh_buffer fun(bufnr?: integer): nil
---@field clear_buffer fun(bufnr: integer): nil
---@field clear_all fun(): nil
---@field setup_autocmds fun(group: integer, on_change?: fun(severity: string|nil): nil): nil

---@type retroline.StateModule
local state = require("retroline.state")
---@type retroline.HighlightsModule
local highlights = require("retroline.highlights")

---@type retroline.DiagnosticsModule
local M = {}

---@type string[]
local severity_order = { "ERROR", "WARN", "INFO", "HINT" }
---@type table<string, string[]>
local severity_by_style = {
  minimal = { "ERROR", "WARN", "INFO", "HINT" },
  compact = { "ERROR", "WARN" },
  full = { "ERROR", "WARN", "INFO", "HINT" },
}
---@type table<string, string>
local severity_hl = {
  ERROR = "RetrolineDiagError",
  WARN = "RetrolineDiagWarn",
  INFO = "RetrolineDiagInfo",
  HINT = "RetrolineDiagHint",
  OK = "RetrolineDiagOk",
}

---@param severity string
---@param items string[]
---@return boolean
local function severity_enabled(severity, items)
  for _, item in ipairs(items) do
    if item == severity then
      return true
    end
  end
  return false
end

---@type table<string, string[]>
local alert_frames = {
  ERROR = { "!!", "!*", "*!", "!!" },
  WARN = { "??", "?~", "~?", "??" },
}

---@type table<integer, string>
local severity_map = {
  [vim.diagnostic.severity.ERROR] = "ERROR",
  [vim.diagnostic.severity.WARN] = "WARN",
  [vim.diagnostic.severity.INFO] = "INFO",
  [vim.diagnostic.severity.HINT] = "HINT",
}

---@type table<integer, retroline.DiagnosticCounts>
local cache = {}

---@return integer
local function now_ms()
  ---@type table<string, any>|nil
  local uv = vim.uv or vim.loop
  if uv ~= nil and type(uv.now) == "function" then
    return uv.now()
  end
  return math.floor(vim.fn.reltimefloat(vim.fn.reltime()) * 1000)
end

---@return retroline.DiagnosticCounts
local function new_counts()
  ---@type retroline.DiagnosticCounts
  local counts = {
    ERROR = 0,
    WARN = 0,
    INFO = 0,
    HINT = 0,
  }
  return counts
end

---@param counts retroline.DiagnosticCounts
---@return retroline.DiagnosticCounts
local function clone_counts(counts)
  ---@type retroline.DiagnosticCounts
  local cloned = {
    ERROR = counts.ERROR,
    WARN = counts.WARN,
    INFO = counts.INFO,
    HINT = counts.HINT,
  }
  return cloned
end

---@param target retroline.DiagnosticCounts
---@param source retroline.DiagnosticCounts
---@return nil
local function add_counts(target, source)
  target.ERROR = target.ERROR + source.ERROR
  target.WARN = target.WARN + source.WARN
  target.INFO = target.INFO + source.INFO
  target.HINT = target.HINT + source.HINT
end

---@param bufnr integer
---@return retroline.DiagnosticCounts
local function collect_counts(bufnr)
  ---@type retroline.DiagnosticCounts
  local counts = new_counts()
  ---@type vim.Diagnostic[]
  local items = vim.diagnostic.get(bufnr)
  for _, item in ipairs(items) do
    ---@type string|nil
    local key = severity_map[item.severity]
    if key ~= nil then
      counts[key] = counts[key] + 1
    end
  end
  return counts
end

---@param bufnr integer
---@return retroline.DiagnosticCounts
local function get_buffer_counts(bufnr)
  ---@type retroline.DiagnosticCounts|nil
  local counts = cache[bufnr]
  if counts ~= nil then
    return counts
  end
  M.refresh_buffer(bufnr)
  return cache[bufnr] or new_counts()
end

---@return retroline.DiagnosticCounts
local function get_workspace_counts()
  ---@type retroline.DiagnosticCounts
  local total = new_counts()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      add_counts(total, get_buffer_counts(bufnr))
    end
  end
  return total
end

---@param opts retroline.DiagnosticOpts|nil
---@return retroline.DiagnosticOpts
function M.normalize_opts(opts)
  ---@type retroline.DiagnosticOpts
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults.diagnostic), opts or {})
  if type(merged.enabled) ~= "boolean" then
    merged.enabled = true
  end
  if merged.scope ~= "buffer" and merged.scope ~= "workspace" then
    merged.scope = "buffer"
  end
  if merged.style ~= "minimal" and merged.style ~= "compact" and merged.style ~= "full" then
    merged.style = "full"
  end
  if type(merged.animate) ~= "boolean" then
    merged.animate = true
  end
  if type(merged.animation) ~= "string" or state.diagnostic_animations[merged.animation] == nil then
    merged.animation = state.defaults.diagnostic.animation
  end
  if type(merged.animate_severities) ~= "table" then
    merged.animate_severities = vim.deepcopy(state.defaults.diagnostic.animate_severities)
  end
  ---@type string[]
  local animate_severities = {}
  for _, severity in ipairs(merged.animate_severities) do
    if type(severity) == "string" and severity_hl[severity] ~= nil then
      table.insert(animate_severities, severity)
    end
  end
  if #animate_severities == 0 then
    animate_severities = vim.deepcopy(state.defaults.diagnostic.animate_severities)
  end
  merged.animate_severities = animate_severities
  if type(merged.show_zero) ~= "boolean" then
    merged.show_zero = false
  end
  if type(merged.use_highlights) ~= "boolean" then
    merged.use_highlights = true
  end
  if type(merged.separator) ~= "string" then
    merged.separator = " "
  end
  if type(merged.empty) ~= "string" then
    merged.empty = ""
  end
  if type(merged.labels) ~= "table" then
    merged.labels = vim.deepcopy(state.defaults.diagnostic.labels)
  end
  for _, severity in ipairs(severity_order) do
    if type(merged.labels[severity]) ~= "string" then
      merged.labels[severity] = state.defaults.diagnostic.labels[severity]
    end
  end
  return merged
end

---@param bufnr? integer
---@return nil
function M.refresh_buffer(bufnr)
  ---@type integer
  local target = bufnr or vim.api.nvim_get_current_buf()
  if target == 0 then
    target = vim.api.nvim_get_current_buf()
  end
  if vim.api.nvim_buf_is_valid(target) == false then
    return
  end
  cache[target] = collect_counts(target)
end

---@param bufnr integer
---@return nil
function M.clear_buffer(bufnr)
  cache[bufnr] = nil
end

---@return nil
function M.clear_all()
  cache = {}
end

---@param text string
---@param group string
---@param use_highlights boolean
---@return string
local function maybe_hl(text, group, use_highlights)
  if use_highlights == false then
    return text
  end
  return highlights.wrap(group, text)
end

---@param counts retroline.DiagnosticCounts
---@return string|nil, integer
local function highest_nonzero(counts)
  for _, severity in ipairs(severity_order) do
    if counts[severity] > 0 then
      return severity, counts[severity]
    end
  end
  return nil, 0
end

---@param previous retroline.DiagnosticCounts
---@param current retroline.DiagnosticCounts
---@return string|nil
local function first_increase(previous, current)
  for _, severity in ipairs(severity_order) do
    if current[severity] > previous[severity] then
      return severity
    end
  end
  return nil
end

---@param opts retroline.DiagnosticOpts
---@param severity string
---@return string
local function marker_for(opts, severity)
  if opts.animate == false then
    return ""
  end
  if severity_enabled(severity, opts.animate_severities) == false then
    return ""
  end
  if state.runtime.diag_alert_severity == severity and now_ms() <= state.runtime.diag_alert_until then
    ---@type string[]|nil
    local pulse = alert_frames[severity]
    if pulse ~= nil and #pulse > 0 then
      ---@type integer
      local pulse_index = ((state.runtime.frame_index - 1) % #pulse) + 1
      return pulse[pulse_index] or pulse[1] or ""
    end
  end
  ---@type retroline.DiagnosticAnimationPreset|nil
  local preset = state.diagnostic_animations[opts.animation]
  if preset == nil then
    preset = state.diagnostic_animations[state.defaults.diagnostic.animation]
  end
  if preset == nil then
    return ""
  end

  ---@type string[]|nil
  local frames = preset[severity]
  if frames == nil or #frames == 0 then
    frames = preset.OK
  end
  if frames == nil or #frames == 0 then
    return ""
  end

  ---@type integer
  local index = ((state.runtime.frame_index - 1) % #frames) + 1
  return frames[index] or frames[1] or ""
end

---@param opts retroline.DiagnosticOpts
---@param severity string
---@param value integer
---@return string
local function format_severity(opts, severity, value)
  ---@type string
  local marker = marker_for(opts, severity)
  ---@type string
  local text = opts.labels[severity] .. tostring(value)
  if marker ~= "" then
    text = marker .. text
  end
  return maybe_hl(text, severity_hl[severity], opts.use_highlights)
end

---@param haystack string
---@param needle string
---@return boolean
local function contains_casefold(haystack, needle)
  if needle == "" then
    return false
  end
  return string.find(string.upper(haystack), string.upper(needle), 1, true) ~= nil
end

---@param opts retroline.DiagnosticOpts
---@return string
local function format_ok(opts)
  if opts.empty == "" then
    return ""
  end
  ---@type string
  local marker = marker_for(opts, "OK")
  ---@type string
  local text = opts.empty
  if marker ~= "" then
    if contains_casefold(marker, text) then
      text = marker
    else
      text = marker .. text
    end
  end
  return maybe_hl(text, severity_hl.OK, opts.use_highlights)
end

---@param bufnr integer
---@param opts? retroline.DiagnosticOpts
---@return string
function M.component_for_buffer(bufnr, opts)
  if vim.api.nvim_buf_is_valid(bufnr) == false then
    return ""
  end

  ---@type retroline.DiagnosticOpts
  local merged = state.runtime.config.diagnostic
  if opts ~= nil then
    merged = M.normalize_opts(vim.tbl_deep_extend("force", vim.deepcopy(state.runtime.config.diagnostic), opts))
  end
  if merged.enabled == false then
    return ""
  end

  ---@type retroline.DiagnosticCounts
  local counts = new_counts()
  if merged.scope == "workspace" then
    counts = get_workspace_counts()
  else
    counts = clone_counts(get_buffer_counts(bufnr))
  end

  if merged.style == "minimal" then
    ---@type string|nil, integer
    local severity, value = highest_nonzero(counts)
    if severity ~= nil then
      return format_severity(merged, severity, value)
    end
    return format_ok(merged)
  end

  ---@type string[]
  local target_order = severity_by_style[merged.style] or severity_order
  ---@type string[]
  local parts = {}
  for _, severity in ipairs(target_order) do
    ---@type integer
    local value = counts[severity]
    if merged.show_zero or value > 0 then
      table.insert(parts, format_severity(merged, severity, value))
    end
  end

  if #parts == 0 then
    return format_ok(merged)
  end
  return table.concat(parts, merged.separator)
end

---@param opts? retroline.DiagnosticOpts
---@return string
function M.component(opts)
  return M.component_for_buffer(vim.api.nvim_get_current_buf(), opts)
end

---@param group integer
---@param on_change? fun(severity: string|nil): nil
---@return nil
function M.setup_autocmds(group, on_change)
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    ---@param ev vim.api.keyset.create_autocmd.callback_args
    callback = function(ev)
      ---@type retroline.DiagnosticCounts
      local previous = clone_counts(cache[ev.buf] or new_counts())
      M.refresh_buffer(ev.buf)
      ---@type retroline.DiagnosticCounts
      local current = cache[ev.buf] or new_counts()
      ---@type string|nil
      local increase = first_increase(previous, current)
      if on_change ~= nil then
        on_change(increase)
      end
      pcall(vim.cmd, "redrawstatus")
    end,
    desc = "Update retroline diagnostics cache",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    ---@param ev vim.api.keyset.create_autocmd.callback_args
    callback = function(ev)
      M.refresh_buffer(ev.buf)
    end,
    desc = "Warm diagnostics cache for active buffer",
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    ---@param ev vim.api.keyset.create_autocmd.callback_args
    callback = function(ev)
      M.clear_buffer(ev.buf)
    end,
    desc = "Drop retroline diagnostics cache for closed buffer",
  })
end

return M
