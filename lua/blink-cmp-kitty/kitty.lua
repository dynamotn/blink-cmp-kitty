--- kitty's remote control, run in the background
---
--- `kitty @ ls` and a `get-text` per window take a while, and kitty may not
--- answer at all -- remote control off, a socket gone. Nothing here waits on
--- them: every command runs through `vim.system` with a callback, a deadline
--- and a cap on what it reads, and answers on the main loop.
local config = require("blink-cmp-kitty.config")
local log = require("blink-cmp-kitty.log")

local M = {}

--- The binary to drive kitty with: the option, else `kitten`, the lighter
--- client, else `kitty`
---@return string?
function M.executable()
	local exe = config.options.executable
	if exe then
		return vim.fn.executable(exe) == 1 and exe or nil
	end
	for _, name in ipairs({ "kitten", "kitty" }) do
		if vim.fn.executable(name) == 1 then
			return name
		end
	end
	return nil
end

--- Whether there is a kitty to ask: inside one, or with its socket known
---
--- The variables of a kitty outlive it in shells started from it (a
--- multiplexer session kept running): a socket on disk is checked to still
--- be there. An abstract socket (`unix:@name`) or TCP has nothing to check.
---@return boolean
function M.available()
	local listen_on = vim.env.KITTY_LISTEN_ON
	if listen_on and listen_on ~= "" then
		local path = listen_on:match("^unix:(.+)$")
		if path and path:sub(1, 1) ~= "@" then
			local stat = vim.uv.fs_stat(path)
			if not stat or stat.type ~= "socket" then
				return false
			end
		end
	elseif vim.env.KITTY_WINDOW_ID == nil then
		return false
	end
	return M.executable() ~= nil
end

--- The argv of `kitty @ <command> <args>`, to the socket when one is known
---@param command string
---@param args? string[]
---@return string[]
function M.argv(command, args)
	local argv = { M.executable() or "kitty", "@" }
	local listen_on = vim.env.KITTY_LISTEN_ON
	if listen_on and listen_on ~= "" then
		vim.list_extend(argv, { "--to", listen_on })
	end
	table.insert(argv, command)
	return vim.list_extend(argv, args or {})
end

--- Run `argv` and hand `on_done` its output on the main loop, or nil and why
--- not; output past `max_bytes` stops the command and is cut there
---@param argv string[]
---@param on_done fun(stdout: string?, err: string?, cut: boolean?)
---@return vim.SystemObj?
function M.run(argv, on_done)
	local max = config.options.max_bytes
	local chunks, size, cut, answered = {}, 0, false, false
	---@type vim.SystemObj?
	local process
	local function finish(...)
		if answered then
			return
		end
		answered = true
		local args = vim.F.pack_len(...)
		vim.schedule(function()
			on_done(vim.F.unpack_len(args))
		end)
	end
	local ok, started = pcall(vim.system, argv, {
		text = true,
		timeout = config.options.timeout,
		stdout = function(_, data)
			if not data or cut then
				return
			end
			size = size + #data
			if size > max then
				cut = true
				data = data:sub(1, #data - (size - max))
				if process then
					pcall(process.kill, process, "sigterm")
				end
			end
			table.insert(chunks, data)
		end,
	}, function(result)
		if cut then
			return finish(table.concat(chunks), nil, true)
		end
		if result.code ~= 0 then
			local err = vim.trim(result.stderr or "")
			if result.code == 124 then
				err = ("no answer within %d ms"):format(config.options.timeout)
			elseif err == "" then
				err = ("exited %d"):format(result.code)
			end
			log.warn("%s: %s", table.concat(argv, " "), err)
			return finish(nil, err)
		end
		finish(table.concat(chunks))
	end)
	if not ok then
		log.error("%s: %s", argv[1], tostring(started))
		finish(nil, tostring(started))
		return nil
	end
	process = started
	-- The exit is only reported once the output closes, and something the
	-- command started can hold it open past the deadline: give up on it then
	local guard = assert(vim.uv.new_timer())
	guard:start(config.options.timeout + 1000, 0, function()
		guard:close()
		if not answered then
			pcall(started.kill, started, "sigkill")
			log.warn("%s: no answer", table.concat(argv, " "))
			finish(nil, ("no answer within %d ms"):format(config.options.timeout))
		end
	end)
	return process
end

--- The ids of the windows of `ls`, the decoded `kitty @ ls`, that the
--- options include
---@param ls table
---@return integer[]
function M.window_ids(ls)
	local opts = config.options
	local ids = {}
	for _, os_window in ipairs(ls) do
		if opts.include_os_window(os_window) then
			for _, tab in ipairs(os_window.tabs or {}) do
				if opts.include_tab(tab) then
					for _, window in ipairs(tab.windows or {}) do
						if opts.include_window(window) then
							table.insert(ids, window.id)
						end
					end
				end
			end
		end
	end
	return ids
end

--- Hand `on_done` the decoded `kitty @ ls`, or nil and why not
---@param on_done fun(ls: table?, err: string?)
function M.ls(on_done)
	M.run(M.argv("ls"), function(stdout, err, cut)
		if not stdout or cut then
			return on_done(nil, err or "kitty @ ls answered more than can be read")
		end
		local ok, ls = pcall(vim.json.decode, stdout)
		if not ok or type(ls) ~= "table" then
			return on_done(nil, "kitty @ ls answered no JSON")
		end
		on_done(ls)
	end)
end

--- Hand `on_done` the text of window `id`, cut at `max_bytes`, or nil
---@param id integer
---@param on_done fun(text: string?, err: string?)
function M.text(id, on_done)
	M.run(M.argv("get-text", { "--match", "id:" .. id, "--extent", config.options.extent }), function(stdout, err)
		on_done(stdout, err)
	end)
end

return M
