---@class retroline.ModeModule
---@field normalize_opts fun(opts: retroline.ModeOpts|nil): retroline.ModeOpts
---@field current_mode fun(): string
---@field component fun(opts?: retroline.ModeOpts): string

---@type retroline.StateModule
local state = require("retroline.state")
---@type retroline.AnimationModule
local animations = require("retroline.animations")

---@type retroline.ModeModule
local M = {}

---@type string
local CTRL_V = "\22"
---@type string
local CTRL_S = "\19"

---@type table<string, table<string, string>>
local mode_labels = {
	short = {
		n = "N",
		no = "OP",
		nov = "OP",
		noV = "OP",
		["no" .. CTRL_V] = "OP",
		niI = "N",
		niR = "N",
		niV = "N",
		nt = "N",
		v = "V",
		vs = "V",
		V = "VL",
		Vs = "VL",
		[CTRL_V] = "VB",
		[CTRL_V .. "s"] = "VB",
		s = "S",
		S = "SL",
		[CTRL_S] = "SB",
		i = "I",
		ic = "I",
		ix = "I",
		R = "R",
		Rc = "R",
		Rx = "R",
		Rv = "VR",
		Rvc = "VR",
		Rvx = "VR",
		c = "C",
		cv = "EX",
		ce = "EX",
		r = "P",
		rm = "M",
		["r?"] = "?",
		["!"] = "SH",
		t = "T",
	},
	long = {
		n = "NORMAL",
		no = "OP-PENDING",
		nov = "OP-PENDING",
		noV = "OP-PENDING",
		["no" .. CTRL_V] = "OP-PENDING",
		niI = "NORMAL",
		niR = "NORMAL",
		niV = "NORMAL",
		nt = "NORMAL",
		v = "VISUAL",
		vs = "VISUAL",
		V = "V-LINE",
		Vs = "V-LINE",
		[CTRL_V] = "V-BLOCK",
		[CTRL_V .. "s"] = "V-BLOCK",
		s = "SELECT",
		S = "S-LINE",
		[CTRL_S] = "S-BLOCK",
		i = "INSERT",
		ic = "INSERT",
		ix = "INSERT",
		R = "REPLACE",
		Rc = "REPLACE",
		Rx = "REPLACE",
		Rv = "V-REPLACE",
		Rvc = "V-REPLACE",
		Rvx = "V-REPLACE",
		c = "COMMAND",
		cv = "EX",
		ce = "EX",
		r = "PROMPT",
		rm = "MORE",
		["r?"] = "CONFIRM",
		["!"] = "SHELL",
		t = "TERMINAL",
	},
}

---@type table<string, table<string, string>>
local mode_prefix = {
	short = {
		n = "N",
		v = "V",
		s = "S",
		i = "I",
		R = "R",
		c = "C",
		r = "P",
		t = "T",
		["!"] = "SH",
	},
	long = {
		n = "NORMAL",
		v = "VISUAL",
		s = "SELECT",
		i = "INSERT",
		R = "REPLACE",
		c = "COMMAND",
		r = "PROMPT",
		t = "TERMINAL",
		["!"] = "SHELL",
	},
}

---@param style string
---@param raw_mode string
---@return string
local function resolve_mode_label(style, raw_mode)
	---@type table<string, string>
	local exact = mode_labels[style] or mode_labels.short
	---@type string|nil
	local from_exact = exact[raw_mode]
	if from_exact ~= nil then
		return from_exact
	end

	---@type string
	local prefix = string.sub(raw_mode, 1, 1)
	---@type table<string, string>
	local fallback = mode_prefix[style] or mode_prefix.short
	---@type string|nil
	local from_prefix = fallback[prefix]
	if from_prefix ~= nil then
		return from_prefix
	end
	return "?"
end

---@return string
function M.current_mode()
	return vim.api.nvim_get_mode().mode
end

---@param opts retroline.ModeOpts|nil
---@return retroline.ModeOpts
function M.normalize_opts(opts)
	---@type retroline.ModeOpts
	local merged = vim.tbl_deep_extend("force", vim.deepcopy(state.defaults.mode), opts or {})
	if merged.style ~= "short" and merged.style ~= "long" then
		merged.style = "short"
	end
	if type(merged.animate) ~= "boolean" then
		merged.animate = true
	end
	if type(merged.animation) ~= "string" or state.mode_animations[merged.animation] == nil then
		merged.animation = "spin"
	end
	if type(merged.separator) ~= "string" then
		merged.separator = ""
	end
	return merged
end

---@param opts? retroline.ModeOpts
---@return string
function M.component(opts)
	---@type retroline.ModeOpts
	local merged = state.runtime.config.mode
	if opts ~= nil then
		merged = M.normalize_opts(vim.tbl_deep_extend("force", vim.deepcopy(state.runtime.config.mode), opts))
	end

	---@type string
	local raw_mode = M.current_mode()
	---@type string
	local label = resolve_mode_label(merged.style, raw_mode)
	if merged.animate == false then
		return label
	end

	---@type string
	local marker = animations.current_mode_marker(merged.animation)
	return label .. merged.separator .. marker
end

return M
