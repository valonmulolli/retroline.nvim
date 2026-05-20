vim.opt.shadafile = "NONE"

---@type {name: string, fn: fun()}[]
local tests = {}

---@param ok boolean
---@param message string
local function assert_true(ok, message)
  if ok ~= true then
    error(message, 2)
  end
end

---@param value any
---@param expected any
---@param message string
local function assert_eq(value, expected, message)
  if value ~= expected then
    error(message .. " (expected=" .. tostring(expected) .. ", got=" .. tostring(value) .. ")", 2)
  end
end

---@param name string
---@param fn fun()
local function test(name, fn)
  table.insert(tests, { name = name, fn = fn })
end

local retroline = require("retroline")
local state = require("retroline.state")

test("setup tolerates invalid path numeric types", function()
  retroline.setup({
    path = {
      max_length = "x",
      shorten_len = {},
      keep_segments = false,
    },
  })

  assert_eq(type(state.runtime.config.path.max_length), "number", "max_length should normalize to number")
  assert_eq(type(state.runtime.config.path.shorten_len), "number", "shorten_len should normalize to number")
  assert_eq(type(state.runtime.config.path.keep_segments), "number", "keep_segments should normalize to number")
end)

test("setup normalizes invalid skip_filetypes", function()
  retroline.setup({
    skip_filetypes = "oops",
  })

  local value = state.runtime.config.skip_filetypes
  assert_eq(type(value), "table", "skip_filetypes should normalize to table")
  assert_true(#value > 0, "skip_filetypes should fall back to defaults")
end)

test("lifecycle autocmds include activity wake events", function()
  retroline.setup()

  local seen = {}
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "RetrolineLifecycle" })) do
    seen[autocmd.event] = true
  end

  assert_true(seen.CursorMoved == true, "CursorMoved autocmd missing")
  assert_true(seen.TextChanged == true, "TextChanged autocmd missing")
  assert_true(seen.WinScrolled == true, "WinScrolled autocmd missing")
end)

test("idle timer wakes on CursorMoved activity", function()
  local animations = require("retroline.animations")
  local original_should_animate = animations.should_animate
  animations.should_animate = function()
    return true
  end

  local ok, err = pcall(function()
    retroline.setup({
      interval = 40,
      performance = {
        idle_timeout = 120,
        stop_timer_on_idle = true,
      },
    })

    retroline.stop()
    assert_true(retroline.is_running() == false, "timer should be stopped before wake test")

    vim.api.nvim_exec_autocmds("CursorMoved", { modeline = false })
    vim.wait(80)
    assert_true(retroline.is_running() == true, "timer should restart on CursorMoved activity")
  end)

  animations.should_animate = original_should_animate
  if not ok then
    error(err, 0)
  end
end)

test("statusline renders the evaluated window buffer", function()
  retroline.setup()
  retroline.enable_statusline()

  vim.cmd("edit one.txt")
  local win1 = vim.api.nvim_get_current_win()

  vim.cmd("vsplit two.txt")
  local win2 = vim.api.nvim_get_current_win()

  local expr = "%!v:lua.require('retroline').statusline()"
  local s1 = vim.api.nvim_eval_statusline(expr, { winid = win1 }).str
  local s2 = vim.api.nvim_eval_statusline(expr, { winid = win2 }).str

  assert_true(string.find(s1, "one.txt", 1, true) ~= nil, "win1 should render one.txt")
  assert_true(string.find(s2, "two.txt", 1, true) ~= nil, "win2 should render two.txt")
end)

test("window-local statusline mode preserves global statusline", function()
  vim.go.statusline = "PLAIN"
  vim.opt.laststatus = 2

  retroline.setup({
    statusline = {
      global = false,
    },
  })
  retroline.enable_statusline()

  assert_eq(vim.go.statusline, "PLAIN", "global statusline should remain unchanged in local mode")
  assert_eq(
    vim.api.nvim_get_option_value("statusline", { win = vim.api.nvim_get_current_win() }),
    "%!v:lua.require('retroline').statusline()",
    "current window should get retroline statusline"
  )

  vim.cmd("vsplit local-statusline.txt")
  assert_eq(
    vim.api.nvim_get_option_value("statusline", { win = vim.api.nvim_get_current_win() }),
    "%!v:lua.require('retroline').statusline()",
    "new windows should inherit retroline local statusline"
  )
end)

test("disable_statusline restores previous statusline state", function()
  vim.go.statusline = "PLAIN"
  vim.opt.laststatus = 2

  retroline.setup()
  retroline.enable_statusline()
  retroline.disable_statusline()

  assert_eq(vim.go.statusline, "PLAIN", "global statusline should be restored after disable")
  assert_eq(vim.o.laststatus, 2, "laststatus should be restored after disable")
end)

test("setup with enabled=false disables installed statusline", function()
  vim.go.statusline = "PLAIN"

  retroline.setup()
  retroline.enable_statusline()
  retroline.setup({ enabled = false })

  assert_eq(vim.go.statusline, "PLAIN", "setup(enabled=false) should restore previous statusline")
end)

test("enable_statusline respects enabled=false", function()
  vim.go.statusline = "PLAIN"

  retroline.setup({ enabled = false })
  retroline.enable_statusline()

  assert_eq(vim.go.statusline, "PLAIN", "enable_statusline should be a no-op when disabled")
end)

test("path component respects configured sidebar labels", function()
  retroline.setup({
    statusline = {
      sidebar_labels = {
        oil = "Files",
      },
    },
  })

  vim.bo.filetype = "oil"
  assert_eq(retroline.path_component(), "[Files]", "path component should use configured sidebar label")
end)

test("retro setup prefers retro animation presets", function()
  retroline.setup({
    statusline = {
      retro = true,
    },
  })

  assert_eq(state.runtime.config.animation, "retro_scan", "retro mode should prefer retro status animation")
  assert_eq(state.runtime.config.mode.animation, "retro_cursor", "retro mode should prefer retro mode animation")
  assert_eq(
    state.runtime.config.diagnostic.animation,
    "retro_alarm",
    "retro mode should prefer retro diagnostic animation"
  )
end)

test("diagnostic animation can target only errors", function()
  retroline.setup({
    diagnostic = {
      animate = true,
      animate_severities = { "ERROR" },
      show_zero = false,
    },
  })

  local diagnostics = require("retroline.diagnostics")
  local buf = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("retroline-tests-errors-only")

  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 0, message = "bad", severity = vim.diagnostic.severity.ERROR },
    { lnum = 0, col = 0, message = "warn", severity = vim.diagnostic.severity.WARN },
  })
  diagnostics.refresh_buffer(buf)

  local outputs = {}
  for i = 1, 2 do
    state.runtime.frame_index = i
    outputs[i] = diagnostics.component_for_buffer(buf)
  end

  assert_true(outputs[1] ~= outputs[2], "error-only animation should still change output across frames")
  assert_true(string.find(outputs[1], "W1", 1, true) ~= nil, "warn text should still be present")
  assert_true(string.find(outputs[2], "W1", 1, true) ~= nil, "warn text should still be present")
  assert_true(
    string.find(outputs[1], "[??]", 1, true) == nil and string.find(outputs[2], "<~~>", 1, true) == nil,
    "warn segment should remain static when only ERROR is animated"
  )
end)

test("retro preset catalogs include hardware-flavored entries", function()
  assert_true(vim.tbl_contains(retroline.list_animations(), "retro_modem"), "retro_modem should be listed")
  assert_true(vim.tbl_contains(retroline.list_animations(), "retro_probe"), "retro_probe should be listed")
  assert_true(vim.tbl_contains(retroline.list_mode_animations(), "retro_prompt"), "retro_prompt should be listed")
  assert_true(vim.tbl_contains(retroline.list_mode_animations(), "retro_gate"), "retro_gate should be listed")
  assert_true(
    vim.tbl_contains(retroline.list_diagnostic_animations(), "retro_panel"),
    "retro_panel should be listed"
  )
end)

test("retro palette applies configured chip colors", function()
  retroline.setup({
    statusline = {
      retro = true,
    },
  })

  local insert = vim.api.nvim_get_hl(0, { name = "RetrolineModeInsert", link = false })
  local path = vim.api.nvim_get_hl(0, { name = "RetrolinePath", link = false })
  local err = vim.api.nvim_get_hl(0, { name = "RetrolineDiagError", link = false })
  local warn = vim.api.nvim_get_hl(0, { name = "RetrolineDiagWarn", link = false })

  assert_eq(insert.bg, tonumber("9fe870", 16), "retro insert chip should use the configured green")
  assert_eq(path.bg, tonumber("27251e", 16), "retro path chip should use the configured background")
  assert_eq(err.fg, tonumber("ff5f5f", 16), "retro error diagnostics should use the configured red")
  assert_eq(warn.fg, tonumber("9fe870", 16), "retro warn diagnostics should use the configured green")
end)

test("retro layout keeps compact mode longer", function()
  local options = require("retroline.statusline.options")
  local opts = options.normalize_opts({
    retro = true,
  })

  assert_eq(options.resolve_layout(opts, 70), "compact", "retro layout should stay compact at width 70")
  assert_eq(options.resolve_layout(opts, 60), "minimal", "retro layout should still collapse when very narrow")
end)

test("retro minimal layout keeps labeled chips", function()
  retroline.setup({
    statusline = {
      retro = true,
      minimal_width = 999,
      compact_width = 1000,
    },
  })
  retroline.enable_statusline()

  vim.cmd("edit three.txt")

  local expr = "%!v:lua.require('retroline').statusline()"
  local output = vim.api.nvim_eval_statusline(expr, { winid = vim.api.nvim_get_current_win() }).str

  assert_true(string.find(output, "[M:N]", 1, true) ~= nil, "retro minimal layout should label mode chip")
  assert_true(string.find(output, "[F:three.txt]", 1, true) ~= nil, "retro minimal layout should label file chip")
  assert_true(string.find(output, "[L:0]", 1, true) ~= nil, "retro minimal layout should label line chip")
end)

---@type integer
local passed = 0
---@type integer
local failed = 0

for _, item in ipairs(tests) do
  local ok, err = pcall(item.fn)
  pcall(function()
    retroline.disable_statusline()
  end)
  if ok then
    passed = passed + 1
    print("ok - " .. item.name)
  else
    failed = failed + 1
    print("not ok - " .. item.name)
    print(err)
  end
end

retroline.stop()

if failed > 0 then
  error("tests failed: " .. tostring(failed) .. " failed, " .. tostring(passed) .. " passed")
end

print("tests passed: " .. tostring(passed))
vim.cmd("qa!")
