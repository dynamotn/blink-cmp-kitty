local h = require("tests.helpers")

local LS = vim.json.encode({
	{
		id = 1,
		tabs = {
			{
				id = 1,
				windows = { { id = 7, is_self = false }, { id = 8, is_self = true }, { id = 9, is_self = false } },
			},
		},
	},
})

describe("cache", function()
	local cache, config, dir, cleanup, env
	before_each(function()
		h.reset()
		config = require("blink-cmp-kitty.config")
		cache = require("blink-cmp-kitty.cache")
		dir, cleanup = h.tmpdir()
		env = vim.env.KITTY_WINDOW_ID
		vim.env.KITTY_WINDOW_ID = "8"
		vim.fn.writefile({ LS }, dir .. "/ls.json")
		-- A kitten that answers ls from a file, and a window by its id,
		-- logging each call, one at a time or not
		config.set({
			executable = h.script(dir, "kitten", {
				'echo "start $*" >> "' .. dir .. '/calls"',
				'case "$*" in',
				'  *" ls") cat "' .. dir .. '/ls.json";;',
				"  *id:7*) sleep 0.1; echo window_seven text here;;",
				"  *id:9*) echo nine-words and --nine;;",
				"esac",
				'echo "end $*" >> "' .. dir .. '/calls"',
			}),
		})
	end)
	after_each(function()
		vim.env.KITTY_WINDOW_ID = env
		cleanup()
	end)

	local function refresh(opts)
		local done = false
		local started = cache.refresh(vim.tbl_extend("force", opts or {}, {
			on_done = function()
				done = true
			end,
		}))
		if not started then
			return false
		end
		return vim.wait(5000, function()
			return done
		end)
	end

	it("reads every window but its own, one after the other", function()
		assert.is_true(refresh())
		local words = vim.tbl_map(function(e)
			return e.word
		end, cache.list())
		assert.is_true(vim.list_contains(words, "window_seven"))
		assert.is_true(vim.list_contains(words, "nine-words"))
		assert.equal("value", cache.items["--nine"].kind)
		local calls = vim.fn.readfile(dir .. "/calls")
		-- ls, then window 7 ended before window 9 started; never 8
		assert.is_truthy(calls[4]:find("^end .*id:7"))
		assert.is_truthy(calls[5]:find("^start .*id:9"))
		for _, call in ipairs(calls) do
			assert.is_nil(call:find("id:8", 1, true))
		end
	end)

	it("waits the update period, unless forced", function()
		assert.is_true(refresh())
		assert.is_false(refresh())
		assert.is_true(refresh({ force = true }))
	end)

	it("drops a word once its lifetime is over", function()
		cache.add({ old = "text" }, os.time() - 120)
		cache.add({ new = "text" }, os.time())
		cache.prune(os.time())
		assert.is_nil(cache.items.old)
		assert.is_not_nil(cache.items.new)
	end)

	it("is ready for the next read when kitty answers no JSON", function()
		vim.fn.writefile({ "garbage" }, dir .. "/ls.json")
		assert.is_true(refresh())
		assert.is_false(cache.updating)
		assert.equal("kitty @ ls answered no JSON", cache.last_error)
	end)
end)
