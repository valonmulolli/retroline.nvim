---@class retroline.StatuslineContextCache
---@field tick integer
---@field expires_at integer
---@field git string
---@field lsp string

---@class retroline.StatuslineContextModule
---@field context_for_buffer fun(bufnr: integer): string, string

---@type retroline.StatuslineContextModule
local M = {}

---@type table<integer, retroline.StatuslineContextCache>
local context_cache = {}

---@return integer
local function now_ms()
  ---@type table<string, any>|nil
  local uv = vim.uv or vim.loop
  if uv ~= nil and type(uv.now) == "function" then
    return uv.now()
  end
  return math.floor(vim.fn.reltimefloat(vim.fn.reltime()) * 1000)
end

---@param bufnr integer
---@return string
local function git_branch(bufnr)
  ---@type string
  local from_gitsigns = vim.b[bufnr].gitsigns_head or ""
  if from_gitsigns ~= "" then
    return from_gitsigns
  end

  ---@type table<string, any>|nil
  local minigit = vim.b[bufnr].minigit_summary
  if type(minigit) == "table" and type(minigit.head) == "string" then
    return minigit.head
  end
  return ""
end

---@param bufnr integer
---@return string
local function lsp_name(bufnr)
  ---@type vim.lsp.Client[]
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    return ""
  end
  ---@type string
  local first = clients[1].name or ""
  if first == "" then
    first = "lsp"
  end
  if #clients == 1 then
    return first
  end
  return first .. "+" .. tostring(#clients - 1)
end

---@param bufnr integer
---@return string, string
function M.context_for_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) == false then
    return "", ""
  end

  ---@type integer
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  ---@type integer
  local now = now_ms()
  ---@type retroline.StatuslineContextCache|nil
  local cached = context_cache[bufnr]
  if cached ~= nil and cached.tick == tick and now < cached.expires_at then
    return cached.git, cached.lsp
  end

  ---@type string
  local git = git_branch(bufnr)
  ---@type string
  local lsp = lsp_name(bufnr)

  context_cache[bufnr] = {
    tick = tick,
    expires_at = now + 800,
    git = git,
    lsp = lsp,
  }
  return git, lsp
end

return M
