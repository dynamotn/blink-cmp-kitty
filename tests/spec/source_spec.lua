local h = require("tests.helpers")

describe("source", function()
	local source, cache, dir, cleanup, env
	before_each(function()
		h.reset()
		dir, cleanup = h.tmpdir()
		env = { id = vim.env.KITTY_WINDOW_ID, listen = vim.env.KITTY_LISTEN_ON }
		vim.env.KITTY_WINDOW_ID, vim.env.KITTY_LISTEN_ON = "1", nil
		cache = require("blink-cmp-kitty.cache")
		source = require("blink-cmp-kitty")
		-- Never read anything: the specs fill the words themselves
		cache.refresh = function()
			return false
		end
	end)
	after_each(function()
		vim.env.KITTY_WINDOW_ID, vim.env.KITTY_LISTEN_ON = env.id, env.listen
		cleanup()
	end)

	--- The response to a completion at the end of `line`, the word typed
	--- starting at `start_col`
	local function complete(src, line, start_col)
		local response
		src:get_completions({
			line = line,
			cursor = { 1, #line },
			bounds = { start_col = start_col },
		}, function(r)
			response = r
		end)
		return response
	end

	it("answers at once from the words kept, each with its kind", function()
		local src = source.new({ executable = h.script(dir, "kitten", { "true" }) })
		cache.add({ apple = "text", ["https://x.dev"] = "value" }, os.time())
		local response = complete(src, "ap", 1)
		local kinds = require("blink.cmp.types").CompletionItemKind
		assert.is_false(response.is_incomplete_forward)
		assert.same(
			{ "apple", "https://x.dev" },
			vim.tbl_map(function(i)
				return i.label
			end, response.items)
		)
		assert.equal(kinds.Text, response.items[1].kind)
		assert.equal(kinds.Value, response.items[2].kind)
	end)

	it("offers words only after a trigger character, when asked to", function()
		local src = source.new({ triggered_only = true, executable = h.script(dir, "kitten", { "true" }) })
		cache.add({ apple = "text" }, os.time())
		assert.same({}, complete(src, "x ap", 3).items)
		local items = complete(src, "x.ap", 3).items
		assert.equal(1, #items)
		-- The trigger character goes with the word it brought
		assert.same({ line = 0, character = 1 }, items[1].textEdit.range.start)
	end)

	it("is off when told so, or outside kitty", function()
		local exe = h.script(dir, "kitten", { "true" })
		assert.is_true(source.new({ executable = exe }):enabled())
		assert.is_false(source.new({ executable = exe, enabled = false }):enabled())
		vim.env.KITTY_WINDOW_ID = nil
		assert.is_false(source.new({ executable = exe }):enabled())
	end)
end)
