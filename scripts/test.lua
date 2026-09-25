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
local path = require("retroline.path")

test("default setup renders the built-in statusline", function()
  retroline.setup()

  local config = state.runtime.config
  assert_eq(config.animation, "dots", "default status animation should be dots")
  assert_eq(config.interval, 150, "default status animation interval should be 150ms")
  assert_eq(config.mode.animation, "spin", "default mode animation should be spin")
  assert_eq(config.path.style, "relative", "default path style should be relative")
  assert_eq(config.diagnostic.animation, "ascii_alert", "default diagnostic animation should be ascii_alert")
  assert_eq(config.statusline.style, "rounded", "default statusline style should be rounded")
  assert_eq(config.statusline.adaptive, true, "adaptive layout should be enabled by default")

  local buf = vim.api.nvim_get_current_buf()
  local previous_name = vim.api.nvim_buf_get_name(buf)
  local ok, output = pcall(function()
    vim.api.nvim_buf_set_name(buf, "retroline-defaults.lua")
    retroline.enable_statusline()
    local statusline = vim.o.statusline
    assert_eq(statusline, "%!v:lua.require('retroline').statusline()", "built-in statusline expression should be installed")
    return vim.api.nvim_eval_statusline(statusline, {
      winid = vim.api.nvim_get_current_win(),
    }).str
  end)
  vim.api.nvim_buf_set_name(buf, previous_name)

  assert_true(ok, "default statusline should evaluate: " .. tostring(output))
  assert_eq(vim.o.laststatus, 3, "built-in statusline should enable global statusline")
  assert_true(
    string.find(output, "retroline-defaults.lua", 1, true) ~= nil,
    "default statusline should render the current filename"
  )
end)

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

test("retro setup preserves user frames when explicitly provided", function()
  retroline.setup({
    frames = { ">>>", "<<<" },
    animation = "line",
    statusline = {
      retro = true,
    },
  })

  assert_eq(
    state.runtime.config.animation,
    "line",
    "user-provided animation name should be preserved in retro mode"
  )
  assert_eq(state.runtime.config.frames[1], ">>>", "user-provided frames should not be overwritten by retro preset")
  assert_eq(state.runtime.config.mode.animation, "retro_cursor", "retro mode animation defaults should still apply")
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

test("skip_filetypes suppresses animation in configured buffers", function()
  retroline.setup({
    skip_filetypes = { "retroline-skip-test" },
  })

  local animations = require("retroline.animations")
  local original_filetype = vim.bo.filetype
  local original_laststatus = vim.o.laststatus
  local original_list_uis = vim.api.nvim_list_uis
  vim.o.laststatus = 2
  vim.api.nvim_list_uis = function()
    return { {} }
  end

  vim.bo.filetype = "retroline-skip-test"
  local skipped = animations.should_animate()
  vim.bo.filetype = "lua"
  local allowed = animations.should_animate()

  vim.bo.filetype = original_filetype
  vim.o.laststatus = original_laststatus
  vim.api.nvim_list_uis = original_list_uis

  assert_eq(skipped, false, "configured filetype should suppress animation")
  assert_eq(allowed, true, "other filetypes should still animate")
end)

test("custom animation registrations validate presets", function()
  retroline.setup()

  assert_true(
    retroline.add_animation("retroline_test_animation", { frames = { "one", "two" }, interval = 80 }),
    "valid status animation should register"
  )
  assert_eq(
    retroline.add_animation("retroline_bad_frames", { frames = { "one", 2 }, interval = 80 }),
    false,
    "non-string status frames should be rejected"
  )
  assert_eq(
    retroline.add_animation("retroline_bad_interval", { frames = { "one" }, interval = math.huge }),
    false,
    "non-finite status intervals should be rejected"
  )
  assert_eq(
    retroline.add_animation("retroline_nan_interval", { frames = { "one" }, interval = 0 / 0 }),
    false,
    "NaN status intervals should be rejected"
  )
  assert_eq(
    retroline.add_mode_animation("retroline_bad_mode", { "one", false }),
    false,
    "non-string mode frames should be rejected"
  )
  assert_true(
    retroline.add_mode_animation("retroline_test_mode", { "%f" }),
    "valid mode animation should register"
  )
  assert_true(
    retroline.add_animation("retroline_test_percent_animation", { frames = { "%p" }, interval = 80 }),
    "valid percent-containing status animation should register"
  )
  assert_eq(
    retroline.add_diagnostic_animation("retroline_bad_diagnostic", {
      ERROR = { "E" },
      WARN = { 1 },
      INFO = { "I" },
      HINT = { "H" },
      OK = { "OK" },
    }),
    false,
    "non-string diagnostic frames should be rejected"
  )
  assert_true(
    retroline.add_diagnostic_animation("retroline_test_diagnostic", {
      ERROR = { "E" },
      WARN = { "W" },
      INFO = { "I" },
      HINT = { "H" },
      OK = { "OK" },
    }),
    "valid diagnostic animation should register"
  )
  assert_eq(
    retroline.add_diagnostic_animation("retroline_bad_empty_diagnostic", {
      ERROR = { "E" },
      WARN = { "W" },
      INFO = { "I" },
      HINT = { "H" },
      OK = {},
    }),
    false,
    "empty severity frames should be rejected"
  )
end)

test("components escape literal statusline percent directives", function()
  retroline.setup({
    path = { style = "filename" },
    diagnostic = { animate = false, empty = "%f" },
  })

  local buf = vim.api.nvim_get_current_buf()
  local previous_name = vim.api.nvim_buf_get_name(buf)
  vim.api.nvim_buf_set_name(buf, "retroline-percent%l.txt")

  local path_text = retroline.path_component()
  local mode_text = retroline.mode_component({ animation = "retroline_test_mode" })
  local diagnostic_text = retroline.diagnostic_component()
  retroline.set_animation("retroline_test_percent_animation")
  local animation_text = retroline.component()
  animation_text = retroline.component()
  retroline.enable_statusline()
  local rendered = vim.api.nvim_eval_statusline("%!v:lua.require('retroline').statusline()", {
    winid = vim.api.nvim_get_current_win(),
  }).str

  vim.api.nvim_buf_set_name(buf, previous_name)

  assert_true(string.find(path_text, "retroline-percent%%l.txt", 1, true) ~= nil, "path percent should be escaped")
  assert_true(string.find(mode_text, "N%%f", 1, true) ~= nil, "mode frame percent should be escaped")
  assert_true(string.find(diagnostic_text, "%%f", 1, true) ~= nil, "diagnostic percent should be escaped")
  assert_true(string.find(animation_text, "%%p", 1, true) ~= nil, "status frame percent should be escaped")
  assert_true(
    string.find(rendered, "percent%l.txt", 1, true) ~= nil,
    "evaluated statusline should show percent directives literally"
  )
end)

test("path: short path passes through unchanged", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 60, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local p = "src/main.lua"
  assert_eq(shorten(p, opts), p, "path under max_length should pass through")
end)

test("path: tier 1 shorten middle segments", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 35, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("src/lib/utils/deep/very_deep/nested/helper.lua", opts)
  assert_true(string.find(result, "s/", 1, true) ~= nil, "tier 1 should shorten first segment")
  assert_true(string.find(result, "l/", 1, true) ~= nil, "tier 1 should shorten second segment")
  assert_true(string.find(result, "u/", 1, true) ~= nil, "tier 1 should shorten third segment")
  assert_true(string.find(result, "nested/helper.lua", 1, true) ~= nil, "tier 1 should keep last 2 full segments")
end)

test("path: tier 2 truncated tail with prefix", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 21, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("src/lib/utils/deep/very_deep/nested/helper.lua", opts)
  assert_true(
    string.find(result, ".../nested/helper.lua", 1, true) ~= nil,
    "tier 2 should use truncation prefix with tail"
  )
end)

test("path: tier 3 tail only without prefix", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 18, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("src/lib/utils/deep/very_deep/nested/helper.lua", opts)
  assert_true(string.find(result, "nested/helper.lua", 1, true) ~= nil, "tier 3 should return tail segments alone")
  assert_true(string.sub(result, 1, 1) ~= ".", "tier 3 tail should start with the first tail segment character")
end)

test("path: tier 4 hard truncation", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 10, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("src/lib/utils/deep/very_deep/nested/helper.lua", opts)
  assert_eq(vim.fn.strdisplaywidth(result), 10, "tier 4 should hard-truncate to max_length display width")
end)

test("path: home-relative path preserves tilde prefix", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 40, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("~/verylonghomefolder/projectname/src/longfilename.lua", opts)
  assert_eq(result, "~/v/p/src/longfilename.lua", "shortened home path should retain one tilde prefix")
end)

test("path: drive prefix is not duplicated while shortening", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 40, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("C:/verylonghomefolder/projectname/src/longfilename.lua", opts)
  assert_eq(result, "C:/v/p/src/longfilename.lua", "shortened drive path should retain one drive prefix")
end)

test("path: absolute root prefix is preserved", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 40, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("/verylonghomefolder/projectname/src/longfilename.lua", opts)
  assert_eq(result, "/v/p/src/longfilename.lua", "shortened absolute path should preserve its root")
end)

test("path: single segment hard-truncates to max_length", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 10, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("verylongfilename.lua", opts)
  assert_eq(vim.fn.strdisplaywidth(result), 10, "single segment longer than max_length should be hard-truncated")
end)

test("path: empty segments do not crash", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 20, shorten_len = 1, keep_segments = 2, trunc_prefix = ".../" }
  local result = shorten("/", opts)
  assert_true(type(result) == "string", "root path should produce a string")
end)

test("path: CJK characters measured by display width", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 20, shorten_len = 1, keep_segments = 1, trunc_prefix = ".../" }
  -- CJK chars are 2 cells wide each
  local result = shorten("src/中文目录/deep/nested.lua", opts)
  assert_eq(result, "s/中/d/nested.lua", "shortened CJK segment should retain a complete character")
end)

test("path: CJK hard truncation respects display width and character boundaries", function()
  local shorten = path._smart_shorten_path
  local opts = { max_length = 8, shorten_len = 1, keep_segments = 1, trunc_prefix = ".../" }
  local result = shorten("src/deep/非常长文件.lua", opts)
  assert_eq(result, "文件.lua", "hard truncation should keep whole trailing CJK characters")
  assert_eq(vim.fn.strdisplaywidth(result), 8, "hard truncation should fit by display width")
end)

---@type integer
local passed = 0
---@type integer
local failed = 0

for _, item in ipairs(tests) do
  local ok, err = pcall(item.fn)
  pcall(function()
    retroline.disable_statusline()
    vim.go.statusline = ""
    vim.opt.laststatus = 2
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
