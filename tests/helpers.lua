local M = {}

--- A scratch directory, removed by the returned function
---@return string dir
---@return fun() cleanup
function M.tmpdir()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	return dir, function()
		vim.fn.delete(dir, "rf")
	end
end

--- Write an executable script `name` holding `lines` into `dir`
---@param dir string
---@param name string
---@param lines string[]
---@return string path
function M.script(dir, name, lines)
	local path = dir .. "/" .. name
	vim.fn.writefile(vim.list_extend({ "#!/bin/sh" }, lines), path)
	vim.fn.setfperm(path, "rwxr-xr-x")
	return path
end

--- Unload the modules of the plugin, so each spec starts from its defaults
function M.reset()
	for name in pairs(package.loaded) do
		if name:match("^blink%-cmp%-kitty") then
			package.loaded[name] = nil
		end
	end
end

return M
