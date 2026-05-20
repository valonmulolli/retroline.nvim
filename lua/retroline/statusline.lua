---@class retroline.StatuslineModule
---@field normalize_opts fun(opts: retroline.StatuslineOpts|nil): retroline.StatuslineOpts
---@field render fun(): string

---@type retroline.StatuslineOptionsModule
local options = require("retroline.statusline.options")
---@type retroline.StatuslineRenderModule
local render = require("retroline.statusline.render")

---@type retroline.StatuslineModule
local M = {}

---@param opts retroline.StatuslineOpts|nil
---@return retroline.StatuslineOpts
function M.normalize_opts(opts)
  return options.normalize_opts(opts)
end

---@return string
function M.render()
  return render.render()
end

return M
