local h = require("tests.helpers")

describe("config", function()
	local config
	before_each(function()
		h.reset()
		config = require("blink-cmp-kitty.config")
	end)

	it("starts from the defaults", function()
		config.set()
		assert.is_true(config.options.enabled)
		assert.equal("all", config.options.extent)
		assert.is_false(config.options.include_window({ is_self = true }))
		assert.is_true(config.options.include_window({ is_self = false }))
	end)

	it("takes false for an answer, and keeps what is not given", function()
		config.set({ enabled = false })
		assert.is_false(config.options.enabled)
		assert.equal(5, config.options.min_update_period)
	end)
end)
