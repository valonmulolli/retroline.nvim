---@class retroline.UtilModule
---@field now_ms fun(): integer
---@field starts_with fun(value: string, prefix: string): boolean
---@field contains fun(value: string, items: string[]): boolean
---@field escape_statusline fun(text: string): string

---@type retroline.UtilModule
local M = {}

---@return integer
function M.now_ms()
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
function M.starts_with(value, prefix)
  return string.sub(value, 1, #prefix) == prefix
end

---@param value string
---@param items string[]
---@return boolean
function M.contains(value, items)
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

---@param text string
---@return string
function M.escape_statusline(text)
  return (text:gsub("%%", "%%%%"))
end

return M
