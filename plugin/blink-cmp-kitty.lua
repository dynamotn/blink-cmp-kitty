-- The commands of blink-cmp-kitty, and a read of the windows on entering
-- one. Nothing loads until the source does, or a command is run.

---@param lines string[]
---@param filetype string
local function scratch(lines, filetype)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = filetype
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
end

vim.api.nvim_create_user_command("BlinkCmpKittyLs", function()
	local kitty = require("blink-cmp-kitty.kitty")
	if not kitty.available() then
		return vim.notify("kitty is not reachable", vim.log.levels.WARN, { title = "blink-cmp-kitty" })
	end
	kitty.run(kitty.argv("ls"), function(stdout, err)
		if not stdout then
			return vim.notify("kitty @ ls: " .. err, vim.log.levels.ERROR, { title = "blink-cmp-kitty" })
		end
		scratch(vim.split(stdout, "\n", { trimempty = true }), "json")
	end)
end, { desc = "What `kitty @ ls` says" })

vim.api.nvim_create_user_command("BlinkCmpKittyItems", function()
	local cache = require("blink-cmp-kitty.cache")
	local lines = {}
	for _, entry in ipairs(cache.list()) do
		table.insert(lines, ("%s\t%s"):format(entry.word, entry.kind))
	end
	if cache.last_error then
		table.insert(lines, 1, "last read failed: " .. cache.last_error)
	end
	scratch(lines, "")
end, { desc = "The words blink-cmp-kitty offers" })

vim.api.nvim_create_user_command("BlinkCmpKittyRefresh", function()
	require("blink-cmp-kitty.cache").refresh({ force = true })
end, { desc = "Read the kitty windows again" })

vim.api.nvim_create_autocmd({ "WinEnter", "BufNew" }, {
	group = vim.api.nvim_create_augroup("blink-cmp-kitty", { clear = true }),
	callback = function()
		-- Only once the source is in use: nothing is read for a Neovim that
		-- never completes from kitty
		if package.loaded["blink-cmp-kitty.cache"] then
			require("blink-cmp-kitty.cache").refresh({ force = true })
		end
	end,
})
