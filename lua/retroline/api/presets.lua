---@class retroline.ApiPresetModule
---@field set_animation fun(name: string, opts?: retroline.SetAnimationOpts): boolean
---@field next_animation fun(): string
---@field current_animation fun(): string
---@field list_animations fun(): string[]
---@field set_mode_animation fun(name: string): boolean
---@field next_mode_animation fun(): string
---@field current_mode_animation fun(): string
---@field list_mode_animations fun(): string[]
---@field set_diagnostic_animation fun(name: string): boolean
---@field next_diagnostic_animation fun(): string
---@field current_diagnostic_animation fun(): string
---@field list_diagnostic_animations fun(): string[]

---@type retroline.StateModule
local state = require("retroline.state")
---@type retroline.AnimationModule
local animations = require("retroline.animations")
---@type retroline.LifecycleModule
local lifecycle = require("retroline.lifecycle")

---@type retroline.ApiPresetModule
local M = {}

---@param items string[]
---@param current string
---@return string
local function next_name_in(items, current)
  ---@type integer
  local current_index = 1
  for index, name in ipairs(items) do
    if name == current then
      current_index = index
      break
    end
  end
  ---@type integer
  local next_index = (current_index % #items) + 1
  return items[next_index]
end

---@param name string
---@param opts? retroline.SetAnimationOpts
---@return boolean
function M.set_animation(name, opts)
  return animations.set_animation(name, opts, lifecycle.restart_if_running)
end

---@return string
function M.next_animation()
  return animations.next_animation(lifecycle.restart_if_running)
end

---@return string
function M.current_animation()
  return animations.current_animation()
end

---@return string[]
function M.list_animations()
  return animations.list_animations()
end

---@param name string
---@return boolean
function M.set_mode_animation(name)
  if state.mode_animations[name] == nil then
    return false
  end
  state.runtime.config.mode.animation = name
  pcall(vim.cmd, "redrawstatus")
  return true
end

---@return string
function M.current_mode_animation()
  return state.runtime.config.mode.animation
end

---@return string[]
function M.list_mode_animations()
  return vim.deepcopy(state.mode_animation_names)
end

---@return string
function M.next_mode_animation()
  ---@type string
  local current = M.current_mode_animation()
  ---@type string
  local next_name = next_name_in(state.mode_animation_names, current)
  M.set_mode_animation(next_name)
  return next_name
end

---@param name string
---@return boolean
function M.set_diagnostic_animation(name)
  if state.diagnostic_animations[name] == nil then
    return false
  end
  state.runtime.config.diagnostic.animation = name
  pcall(vim.cmd, "redrawstatus")
  return true
end

---@return string
function M.current_diagnostic_animation()
  return state.runtime.config.diagnostic.animation
end

---@return string[]
function M.list_diagnostic_animations()
  return vim.deepcopy(state.diagnostic_animation_names)
end

---@return string
function M.next_diagnostic_animation()
  ---@type string
  local current = M.current_diagnostic_animation()
  ---@type string
  local next_name = next_name_in(state.diagnostic_animation_names, current)
  M.set_diagnostic_animation(next_name)
  return next_name
end

return M
