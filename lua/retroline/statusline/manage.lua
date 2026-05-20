---@class retroline.StatuslineManagerModule
---@field enable fun(): nil
---@field disable fun(): nil
---@field sync_window fun(winid?: integer): nil
---@field forget_window fun(winid: integer): nil
---@field is_enabled fun(): boolean

---@type retroline.StateModule
local state = require("retroline.state")

---@type retroline.StatuslineManagerModule
local M = {}

---@type string
local STATUSLINE_EXPR = "%!v:lua.require('retroline').statusline()"

---@param winid integer
---@return boolean
local function valid_win(winid)
  return winid ~= 0 and vim.api.nvim_win_is_valid(winid)
end

---@param winid integer
---@return string
local function get_win_statusline(winid)
  return vim.api.nvim_get_option_value("statusline", { win = winid })
end

---@param winid integer
---@param value string
---@return nil
local function set_win_statusline(winid, value)
  if valid_win(winid) == false then
    return
  end
  vim.api.nvim_set_option_value("statusline", value, { win = winid })
end

---@return nil
local function capture_previous_state()
  state.runtime.statusline_prev_global = vim.o.statusline
  state.runtime.statusline_prev_laststatus = vim.o.laststatus
  state.runtime.statusline_prev_windows = {}
end

---@param winid integer
---@return nil
local function apply_local_window(winid)
  if valid_win(winid) == false then
    return
  end
  if state.runtime.statusline_prev_windows[winid] == nil then
    state.runtime.statusline_prev_windows[winid] = get_win_statusline(winid)
  end
  set_win_statusline(winid, STATUSLINE_EXPR)
end

---@return boolean
function M.is_enabled()
  return state.runtime.statusline_enabled
end

---@param winid? integer
---@return nil
function M.sync_window(winid)
  if state.runtime.statusline_enabled == false or state.runtime.config.statusline.global then
    return
  end
  apply_local_window(winid or vim.api.nvim_get_current_win())
end

---@param winid integer
---@return nil
function M.forget_window(winid)
  state.runtime.statusline_prev_windows[winid] = nil
end

---@return nil
function M.enable()
  if state.runtime.statusline_enabled then
    M.disable()
  end

  capture_previous_state()
  state.runtime.statusline_enabled = true

  if state.runtime.config.statusline.global then
    vim.opt.laststatus = 3
    vim.o.statusline = STATUSLINE_EXPR
    return
  end

  vim.o.statusline = state.runtime.statusline_prev_global or vim.o.statusline
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    apply_local_window(winid)
  end
end

---@return nil
function M.disable()
  if state.runtime.statusline_enabled == false then
    return
  end

  for winid, value in pairs(state.runtime.statusline_prev_windows) do
    if valid_win(winid) then
      set_win_statusline(winid, value)
    end
  end

  if state.runtime.statusline_prev_global ~= nil then
    vim.o.statusline = state.runtime.statusline_prev_global
  end
  if state.runtime.statusline_prev_laststatus ~= nil then
    vim.opt.laststatus = state.runtime.statusline_prev_laststatus
  end

  state.runtime.statusline_enabled = false
  state.runtime.statusline_prev_global = nil
  state.runtime.statusline_prev_laststatus = nil
  state.runtime.statusline_prev_windows = {}
end

return M
