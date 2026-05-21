---@class retroline.LifecycleModule
---@field start fun(): nil
---@field stop fun(): nil
---@field toggle fun(): nil
---@field restart_if_running fun(): nil
---@field is_running fun(): boolean
---@field mark_activity fun(duration_ms?: integer): nil
---@field mark_diagnostic_alert fun(severity?: string, duration_ms?: integer): nil

---@type retroline.StateModule
local state = require("retroline.state")
---@type retroline.AnimationModule
local animations = require("retroline.animations")

---@type retroline.LifecycleModule
local M = {}

---@return integer
local function now_ms()
  ---@type table<string, any>|nil
  local uv = vim.uv or vim.loop
  if uv ~= nil and type(uv.now) == "function" then
    return uv.now()
  end
  return math.floor(vim.fn.reltimefloat(vim.fn.reltime()) * 1000)
end

---@param value string
---@param prefix string
---@return boolean
local function starts_with(value, prefix)
  return string.sub(value, 1, #prefix) == prefix
end

---@param mode string
---@param prefixes string[]
---@return boolean
local function is_active_mode(mode, prefixes)
  for _, prefix in ipairs(prefixes) do
    if starts_with(mode, prefix) then
      return true
    end
  end
  return false
end

---@return nil
local function stop_timer()
  state.runtime.running = false
  ---@type uv.uv_timer_t|nil
  local timer = state.runtime.timer
  if timer == nil then
    return
  end
  timer:stop()
  if timer:is_closing() == false then
    timer:close()
  end
  state.runtime.timer = nil
end

---@return boolean
local function should_tick()
  if animations.should_animate() == false then
    return false
  end

  ---@type retroline.PerformanceOpts
  local perf = state.runtime.config.performance
  if perf.smart_idle == false then
    return true
  end

  ---@type string
  local raw_mode = vim.api.nvim_get_mode().mode
  if is_active_mode(raw_mode, perf.active_mode_prefixes) then
    return true
  end

  ---@type integer
  local now = now_ms()
  if now <= state.runtime.diag_alert_until then
    return true
  end
  return (now - state.runtime.last_activity) <= perf.idle_timeout
end

---@return nil
local function tick()
  if should_tick() == false then
    if state.runtime.config.performance.stop_timer_on_idle or animations.should_animate() == false then
      stop_timer()
    end
    return
  end

  ---@type string[]
  local frames = state.runtime.config.frames
  if #frames == 0 then
    return
  end

  state.runtime.frame_index = (state.runtime.frame_index % #frames) + 1
  pcall(vim.cmd, "redrawstatus")
end

---@return boolean
function M.is_running()
  return state.runtime.running
end

---@param duration_ms? integer
---@return nil
function M.mark_activity(duration_ms)
  ---@type integer
  local now = now_ms()
  state.runtime.last_activity = now
  if type(duration_ms) == "number" and duration_ms > 0 then
    ---@type integer
    local until_ts = now + math.floor(duration_ms)
    if until_ts > state.runtime.diag_alert_until then
      state.runtime.diag_alert_until = until_ts
    end
  end

  if
    state.runtime.config.enabled
    and state.runtime.config.performance.stop_timer_on_idle
    and state.runtime.running == false
    and animations.should_animate()
  then
    M.start()
  end
end

---@param severity? string
---@param duration_ms? integer
---@return nil
function M.mark_diagnostic_alert(severity, duration_ms)
  ---@type integer
  local pulse = math.floor(duration_ms or state.runtime.config.performance.diagnostic_pulse)
  if pulse > 0 then
    ---@type integer
    local now = now_ms()
    state.runtime.diag_alert_until = math.max(state.runtime.diag_alert_until, now + pulse)
  end
  if type(severity) == "string" and severity ~= "" then
    state.runtime.diag_alert_severity = severity
  end
  M.mark_activity()
  pcall(vim.cmd, "redrawstatus")
end

---@return nil
function M.start()
  if state.runtime.running then
    return
  end

  ---@type table<string, any>|nil
  local uv = vim.uv or vim.loop
  if uv == nil then
    return
  end

  ---@type uv.uv_timer_t|nil
  local timer = uv.new_timer()
  if timer == nil then
    return
  end

  state.runtime.last_activity = now_ms()
  state.runtime.timer = timer
  state.runtime.running = true
  timer:start(0, state.runtime.config.interval, vim.schedule_wrap(tick))
end

---@return nil
function M.stop()
  stop_timer()
end

---@return nil
function M.toggle()
  if state.runtime.running then
    M.stop()
    return
  end
  M.start()
end

---@return nil
function M.restart_if_running()
  if state.runtime.running == false then
    return
  end
  M.stop()
  M.start()
end

return M
