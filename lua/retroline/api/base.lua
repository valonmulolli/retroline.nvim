---@class retroline.ApiBaseModule
---@field start fun(): nil
---@field stop fun(): nil
---@field toggle fun(): nil
---@field component fun(): string
---@field mode_component fun(opts?: retroline.ModeOpts): string
---@field path_component fun(opts?: retroline.PathOpts): string
---@field diagnostic_component fun(opts?: retroline.DiagnosticOpts): string
---@field statusline fun(): string
---@field enable_statusline fun(): nil
---@field disable_statusline fun(): nil
---@field is_running fun(): boolean

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
---@type retroline.LifecycleModule
local lifecycle = require("retroline.lifecycle")

---@type retroline.ApiBaseModule
local M = {}

---@return nil
function M.start()
  lifecycle.start()
end

---@return nil
function M.stop()
  lifecycle.stop()
end

---@return nil
function M.toggle()
  lifecycle.toggle()
end

---@return string
function M.component()
  return animations.current_frame()
end

---@param opts? retroline.ModeOpts
---@return string
function M.mode_component(opts)
  return mode.component(opts)
end

---@param opts? retroline.PathOpts
---@return string
function M.path_component(opts)
  return path.component(opts)
end

---@param opts? retroline.DiagnosticOpts
---@return string
function M.diagnostic_component(opts)
  return diagnostics.component(opts)
end

---@return string
function M.statusline()
  return statusline.render()
end

---@return nil
function M.enable_statusline()
  if state.runtime.config.enabled == false then
    return
  end
  statusline_manager.enable()
end

---@return nil
function M.disable_statusline()
  statusline_manager.disable()
end

---@return boolean
function M.is_running()
  return lifecycle.is_running()
end

return M
