---@class retroline.SetupModule
---@field setup fun(opts?: retroline.Config): nil

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
---@type retroline.StatuslineModule
local statusline = require("retroline.statusline")
---@type retroline.StatuslineManagerModule
local statusline_manager = require("retroline.statusline.manage")
---@type retroline.HighlightsModule
local highlights = require("retroline.highlights")
---@type retroline.LifecycleModule
local lifecycle = require("retroline.lifecycle")

---@type retroline.SetupModule
local M = {}

---@param defaults string[]
---@param value any
---@return string[]
local function normalize_string_list(defaults, value)
  if type(value) ~= "table" then
    return vim.deepcopy(defaults)
  end

  ---@type string[]
  local list = {}
  for _, item in ipairs(value) do
    if type(item) == "string" and item ~= "" then
      table.insert(list, item)
    end
  end

  if #list == 0 then
    return vim.deepcopy(defaults)
  end
  return list
end

---@param opts retroline.PerformanceOpts|nil
---@return retroline.PerformanceOpts
local function normalize_performance_opts(opts)
  ---@type retroline.PerformanceOpts
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults.performance), opts or {})
  if type(merged.smart_idle) ~= "boolean" then
    merged.smart_idle = state.defaults.performance.smart_idle
  end
  if type(merged.stop_timer_on_idle) ~= "boolean" then
    merged.stop_timer_on_idle = state.defaults.performance.stop_timer_on_idle
  end
  if type(merged.idle_timeout) ~= "number" then
    merged.idle_timeout = state.defaults.performance.idle_timeout
  end
  if type(merged.diagnostic_pulse) ~= "number" then
    merged.diagnostic_pulse = state.defaults.performance.diagnostic_pulse
  end
  merged.idle_timeout = math.max(250, math.floor(merged.idle_timeout))
  merged.diagnostic_pulse = math.max(300, math.floor(merged.diagnostic_pulse))

  merged.active_mode_prefixes =
    normalize_string_list(state.defaults.performance.active_mode_prefixes, merged.active_mode_prefixes)
  return merged
end

---@param merged retroline.Config
---@param opts retroline.Config|nil
---@return nil
local function apply_retro_defaults(merged, opts)
  if merged.statusline == nil or merged.statusline.retro == false then
    return
  end

  ---@type boolean
  local has_frames = opts ~= nil and type(opts.frames) == "table" and #opts.frames > 0
  ---@type boolean
  local has_animation = opts ~= nil and type(opts.animation) == "string" and opts.animation ~= ""
  if has_frames == false and has_animation == false then
    ---@type retroline.AnimationPreset|nil
    local preset = state.animations.retro_scan
    if preset ~= nil then
      merged.animation = "retro_scan"
      merged.frames = vim.deepcopy(preset.frames)
      if opts == nil or type(opts.interval) ~= "number" then
        merged.interval = preset.interval
      end
    end
  end

  ---@type boolean
  local has_mode_animation = opts ~= nil
    and type(opts.mode) == "table"
    and type(opts.mode.animation) == "string"
    and opts.mode.animation ~= ""
  if has_mode_animation == false then
    merged.mode.animation = "retro_cursor"
  end

  ---@type boolean
  local has_diagnostic_animation = opts ~= nil
    and type(opts.diagnostic) == "table"
    and type(opts.diagnostic.animation) == "string"
    and opts.diagnostic.animation ~= ""
  if has_diagnostic_animation == false then
    merged.diagnostic.animation = "retro_alarm"
  end
end

---@param group integer
---@return nil
local function setup_lifecycle_autocmds(group)
  vim.api.nvim_clear_autocmds({ group = group })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    ---@param _ev vim.api.keyset.create_autocmd.callback_args
    callback = function(_ev)
      lifecycle.stop()
    end,
    desc = "Stop retroline timer before exit",
  })

  vim.api.nvim_create_autocmd("UIEnter", {
    group = group,
    once = true,
    ---@param _ev vim.api.keyset.create_autocmd.callback_args
    callback = function(_ev)
      if state.runtime.config.enabled then
        lifecycle.start()
      end
    end,
    desc = "Start retroline when UI is ready",
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    ---@param _ev vim.api.keyset.create_autocmd.callback_args
    callback = function(_ev)
      lifecycle.mark_activity()
      pcall(vim.cmd, "redrawstatus")
    end,
    desc = "Refresh statusline when mode changes",
  })

  vim.api.nvim_create_autocmd({
    "InsertEnter",
    "InsertLeave",
    "CmdlineEnter",
    "CmdlineLeave",
    "BufEnter",
    "WinEnter",
    "TermEnter",
    "CursorMoved",
    "CursorMovedI",
    "TextChanged",
    "TextChangedI",
    "TextChangedP",
    "WinScrolled",
  }, {
    group = group,
    ---@param _ev vim.api.keyset.create_autocmd.callback_args
    callback = function(_ev)
      lifecycle.mark_activity()
    end,
    desc = "Keep retroline animation active while editing",
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    ---@param _ev vim.api.keyset.create_autocmd.callback_args
    callback = function(_ev)
      statusline_manager.sync_window()
    end,
    desc = "Apply retroline to new local statusline windows",
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    ---@param ev vim.api.keyset.create_autocmd.callback_args
    callback = function(ev)
      local winid = tonumber(ev.match)
      if winid ~= nil then
        statusline_manager.forget_window(winid)
      end
    end,
    desc = "Forget closed retroline window state",
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    ---@param _ev vim.api.keyset.create_autocmd.callback_args
    callback = function(_ev)
      highlights.setup()
    end,
    desc = "Restore retroline highlight groups after colorscheme",
  })
end

---@param group integer
---@return nil
local function setup_diagnostics_autocmds(group)
  diagnostics.setup_autocmds(group, function(severity)
    ---@type string|nil
    local level = severity
    if level == "ERROR" then
      lifecycle.mark_diagnostic_alert("ERROR")
      return
    end
    if level == "WARN" then
      ---@type integer
      local pulse = math.floor(state.runtime.config.performance.diagnostic_pulse * 0.75)
      lifecycle.mark_diagnostic_alert("WARN", pulse)
      return
    end
    lifecycle.mark_activity()
  end)
  diagnostics.refresh_buffer(0)
end

---@param opts? retroline.Config
---@return nil
function M.setup(opts)
  lifecycle.stop()

  ---@type retroline.Config
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults), opts or {})
  merged.mode = mode.normalize_opts(merged.mode)
  merged.path = path.normalize_opts(merged.path)
  merged.diagnostic = diagnostics.normalize_opts(merged.diagnostic)
  merged.statusline = statusline.normalize_opts(merged.statusline)
  apply_retro_defaults(merged, opts)
  merged = animations.resolve_setup_config(merged, opts)
  merged.performance = normalize_performance_opts(merged.performance)
  merged.skip_filetypes = normalize_string_list(state.defaults.skip_filetypes, merged.skip_filetypes)

  state.runtime.config = merged
  state.runtime.frame_index = 1
  state.runtime.last_activity = 0
  state.runtime.diag_alert_until = 0
  state.runtime.diag_alert_severity = ""
  highlights.setup()

  if state.runtime.statusline_enabled then
    if merged.enabled then
      statusline_manager.enable()
    else
      statusline_manager.disable()
    end
  end

  if state.runtime.augroup == nil then
    state.runtime.augroup = vim.api.nvim_create_augroup("RetrolineLifecycle", { clear = true })
  end
  ---@type integer
  local group = state.runtime.augroup

  setup_lifecycle_autocmds(group)
  setup_diagnostics_autocmds(group)

  if #vim.api.nvim_list_uis() > 0 and state.runtime.config.enabled then
    lifecycle.start()
  end
end

return M
