--- A log of what the source did, off unless `log_level` says otherwise
local M = {}

---@return string
function M.path()
	return vim.fs.joinpath(vim.fn.stdpath("log") --[[@as string]], "blink-cmp-kitty.log")
end

---@param level integer
---@param msg string
---@param ... any Formatted into `msg`
function M.log(level, msg, ...)
	if level < require("blink-cmp-kitty.config").options.log_level then
		return
	end
	-- Appended directly, never through a shell: text read from a window
	-- would run as part of the command
	local file = io.open(M.path(), "a")
	if not file then
		return
	end
	local names = { [0] = "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
	file:write(("%s %s %s\n"):format(os.date("%F %T"), names[level] or level, msg:format(...)))
	file:close()
end

function M.debug(...)
	M.log(vim.log.levels.DEBUG, ...)
end

function M.warn(...)
	M.log(vim.log.levels.WARN, ...)
end

function M.error(...)
	M.log(vim.log.levels.ERROR, ...)
end

return M
