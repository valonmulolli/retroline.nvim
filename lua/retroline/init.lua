---@class retroline.Module
---@field setup fun(opts?: retroline.Config): nil
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

---@type retroline.ApiBaseModule
local base_api = require("retroline.api.base")
---@type retroline.ApiPresetModule
local preset_api = require("retroline.api.presets")
---@type retroline.SetupModule
local setup = require("retroline.setup")

---@type retroline.Module
local M = {}

---@param target table<string, any>
---@param source table<string, any>
---@return nil
local function extend(target, source)
  for key, value in pairs(source) do
    target[key] = value
  end
end

extend(M, base_api)
extend(M, preset_api)
M.setup = setup.setup

return M
