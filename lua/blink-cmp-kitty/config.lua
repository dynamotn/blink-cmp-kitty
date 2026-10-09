--- The options of the source, shared by every part of it
local M = {}

---@class blink-cmp-kitty.Opts
---@field enabled boolean
---@field triggered_only boolean Complete only after one of `trigger_chars`
---@field trigger_chars string[]
---@field executable? string `kitten` when installed, else `kitty`
---@field extent string What `get-text` reads of a window: `all`, `screen`, ...
---@field include_os_window fun(os_window: table): boolean
---@field include_tab fun(tab: table): boolean
---@field include_window fun(window: table): boolean
---@field min_update_period integer Seconds between two reads of the windows
---@field item_lifetime integer Seconds a word stays once its window drops it
---@field timeout integer Milliseconds a kitty command may take
---@field max_bytes integer Bytes read of one window at most
---@field log_level integer A `vim.log.levels` value; `OFF` writes nothing

---@type blink-cmp-kitty.Opts
M.defaults = {
	enabled = true,
	triggered_only = false,
	trigger_chars = { "." },
	executable = nil,
	extent = "all",
	include_os_window = function()
		return true
	end,
	include_tab = function()
		return true
	end,
	-- This Neovim's own window: its words come from the `buffer` source
	include_window = function(window)
		return not window.is_self
	end,
	min_update_period = 5,
	item_lifetime = 60,
	timeout = 2000,
	max_bytes = 1024 * 1024,
	log_level = vim.log.levels.OFF,
}

---@type blink-cmp-kitty.Opts
M.options = vim.deepcopy(M.defaults)

--- Take `opts` over the defaults; `false` is a value like any other
---@param opts? table
function M.set(opts)
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
