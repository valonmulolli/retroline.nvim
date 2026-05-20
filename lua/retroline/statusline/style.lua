---@class retroline.StatuslineStyleModule
---@field section_delims fun(style: string): string, string
---@field retro_chip fun(text: string): string
---@field wrap fun(group: string, text: string): string

---@type retroline.HighlightsModule
local highlights = require("retroline.highlights")

---@type retroline.StatuslineStyleModule
local M = {}

---@param style string
---@return string, string
function M.section_delims(style)
  if style == "square" then
    return "[", "]"
  end
  if style == "none" then
    return "", ""
  end
  return "(", ")"
end

---@param text string
---@return string
function M.retro_chip(text)
  if text:match("^%[.+%]$") ~= nil then
    return text
  end
  return "[" .. text .. "]"
end

---@param group string
---@param text string
---@return string
function M.wrap(group, text)
  return highlights.wrap(group, text)
end

return M
