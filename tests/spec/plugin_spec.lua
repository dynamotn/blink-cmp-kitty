local h = require("tests.helpers")

describe("plugin", function()
	before_each(function()
		h.reset()
		vim.cmd("runtime plugin/blink-cmp-kitty.lua")
	end)

	it("defines its commands", function()
		local commands = vim.api.nvim_get_commands({})
		for _, name in ipairs({ "BlinkCmpKittyLs", "BlinkCmpKittyItems", "BlinkCmpKittyRefresh" }) do
			assert.is_not_nil(commands[name], name)
		end
	end)

	it("reads nothing on entering a window until the source is in use", function()
		vim.cmd("new")
		vim.cmd("close")
		assert.is_nil(package.loaded["blink-cmp-kitty.cache"])
	end)
end)
