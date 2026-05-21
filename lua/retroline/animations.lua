---@class retroline.SetAnimationOpts
---@field preserve_interval boolean

---@class retroline.AnimationModule
---@field should_animate fun(): boolean
---@field current_frame fun(): string
---@field current_mode_marker fun(animation_name: string): string
---@field list_animations fun(): string[]
---@field current_animation fun(): string
---@field set_animation fun(name: string, opts?: retroline.SetAnimationOpts, restart_if_running?: fun(): nil): boolean
---@field next_animation fun(restart_if_running?: fun(): nil): string
---@field resolve_setup_config fun(merged: retroline.Config, opts: retroline.Config|nil): retroline.Config

---@type retroline.StateModule
local state = require("retroline.state")

---@type retroline.AnimationModule
local M = {}

---@param value string
---@param items string[]
---@return boolean
local function contains(value, items)
  if type(items) ~= "table" then
    return false
  end
  for _, item in ipairs(items) do
    if item == value then
      return true
    end
  end
  return false
end

---@return boolean
function M.should_animate()
  ---@type retroline.Config
  local config = state.runtime.config
  if config.enabled == false then
    return false
  end
  if vim.o.laststatus == 0 then
    return false
  end
  if #vim.api.nvim_list_uis() == 0 then
    return false
  end
  return true
end

---@return string
function M.current_frame()
  ---@type string[]
  local frames = state.runtime.config.frames
  if #frames == 0 then
    return "."
  end
  return frames[state.runtime.frame_index] or frames[1] or "."
end

---@param animation_name string
---@return string
function M.current_mode_marker(animation_name)
  ---@type string[]|nil
  local frames = state.mode_animations[animation_name]
  if frames == nil or #frames == 0 then
    frames = state.mode_animations.spin
  end
  if frames == nil or #frames == 0 then
    return "|"
  end
  ---@type integer
  local index = ((state.runtime.frame_index - 1) % #frames) + 1
  return frames[index] or frames[1] or "|"
end

---@return string[]
function M.list_animations()
  return vim.deepcopy(state.animation_names)
end

---@return string
function M.current_animation()
  return state.runtime.config.animation
end

---@param name string
---@param opts? retroline.SetAnimationOpts
---@param restart_if_running? fun(): nil
---@return boolean
function M.set_animation(name, opts, restart_if_running)
  ---@type retroline.AnimationPreset|nil
  local preset = state.animations[name]
  if preset == nil then
    return false
  end

  ---@type retroline.Config
  local config = state.runtime.config
  config.animation = name
  config.frames = vim.deepcopy(preset.frames)
  state.runtime.frame_index = 1

  ---@type boolean
  local preserve_interval = opts ~= nil and opts.preserve_interval == true
  if preserve_interval == false then
    config.interval = preset.interval
  end

  if restart_if_running ~= nil then
    restart_if_running()
  end
  return true
end

---@param restart_if_running? fun(): nil
---@return string
function M.next_animation(restart_if_running)
  ---@type string
  local current = state.runtime.config.animation
  ---@type integer
  local current_index = 1
  for index, name in ipairs(state.animation_names) do
    if name == current then
      current_index = index
      break
    end
  end

  ---@type integer
  local next_index = (current_index % #state.animation_names) + 1
  ---@type string
  local next_name = state.animation_names[next_index]
  M.set_animation(next_name, nil, restart_if_running)
  return next_name
end

---@param merged retroline.Config
---@param opts retroline.Config|nil
---@return retroline.Config
function M.resolve_setup_config(merged, opts)
  ---@type retroline.AnimationPreset|nil
  local preset = state.animations[merged.animation]
  if preset == nil then
    merged.animation = state.defaults.animation
    preset = state.animations[state.defaults.animation]
  end

  ---@type boolean
  local has_frames = opts ~= nil and type(opts.frames) == "table" and #opts.frames > 0
  if has_frames == false and preset ~= nil then
    merged.frames = vim.deepcopy(preset.frames)
  end

  ---@type boolean
  local has_interval = opts ~= nil and type(opts.interval) == "number"
  if has_interval == false and preset ~= nil then
    merged.interval = preset.interval
  end

  if merged.interval < 16 then
    merged.interval = 16
  end
  if #merged.frames == 0 then
    merged.frames = vim.deepcopy(state.defaults.frames)
  end
  return merged
end

return M
