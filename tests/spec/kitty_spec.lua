local h = require("tests.helpers")

describe("kitty", function()
	local kitty, config, dir, cleanup, env
	before_each(function()
		h.reset()
		config = require("blink-cmp-kitty.config")
		kitty = require("blink-cmp-kitty.kitty")
		dir, cleanup = h.tmpdir()
		env = { id = vim.env.KITTY_WINDOW_ID, listen = vim.env.KITTY_LISTEN_ON }
		vim.env.KITTY_WINDOW_ID, vim.env.KITTY_LISTEN_ON = "1", nil
	end)
	after_each(function()
		vim.env.KITTY_WINDOW_ID, vim.env.KITTY_LISTEN_ON = env.id, env.listen
		cleanup()
	end)

	--- Run `argv` through `kitty.run` and wait for its answer
	local function run(argv)
		local answer
		kitty.run(argv, function(...)
			answer = vim.F.pack_len(...)
		end)
		assert.is_true(vim.wait(5000, function()
			return answer ~= nil
		end))
		return vim.F.unpack_len(answer)
	end

	it("asks the socket when one is known", function()
		config.set({ executable = h.script(dir, "kitten", { "true" }) })
		assert.same({ dir .. "/kitten", "@", "ls" }, kitty.argv("ls"))
		vim.env.KITTY_LISTEN_ON = "unix:/tmp/kitty"
		assert.same(
			{ dir .. "/kitten", "@", "--to", "unix:/tmp/kitty", "get-text", "--extent", "all" },
			kitty.argv("get-text", { "--extent", "all" })
		)
	end)

	it("is available inside kitty with a client to drive it", function()
		config.set({ executable = h.script(dir, "kitten", { "true" }) })
		assert.is_true(kitty.available())
		vim.env.KITTY_WINDOW_ID = nil
		assert.is_false(kitty.available())
		vim.env.KITTY_WINDOW_ID = "1"
		config.set({ executable = dir .. "/missing" })
		assert.is_false(kitty.available())
	end)

	it("is not available through a socket that is gone", function()
		config.set({ executable = h.script(dir, "kitten", { "true" }) })
		vim.env.KITTY_LISTEN_ON = "unix:" .. dir .. "/gone.sock"
		assert.is_false(kitty.available())
		local server = vim.uv.new_pipe(false)
		assert(server:bind(dir .. "/live.sock"))
		vim.env.KITTY_LISTEN_ON = "unix:" .. dir .. "/live.sock"
		assert.is_true(kitty.available())
		server:close()
		vim.env.KITTY_LISTEN_ON = "unix:@kitty"
		assert.is_true(kitty.available())
		vim.env.KITTY_LISTEN_ON = "tcp:localhost:12345"
		assert.is_true(kitty.available())
	end)

	it("answers at the deadline though a child keeps the output open", function()
		config.set({ timeout = 100 })
		local started = vim.uv.hrtime()
		local out, err = run({ h.script(dir, "holder", { "sleep 10 &", "sleep 10" }) })
		assert.is_nil(out)
		assert.equal("no answer within 100 ms", err)
		assert.is_true((vim.uv.hrtime() - started) / 1e6 < 3000)
	end)

	it("keeps the windows the options include", function()
		config.set({
			include_tab = function(tab)
				return tab.title ~= "skip"
			end,
		})
		local ls = {
			{
				tabs = {
					{ title = "work", windows = { { id = 1, is_self = true }, { id = 2 } } },
					{ title = "skip", windows = { { id = 3 } } },
				},
			},
			{ tabs = { { title = "other", windows = { { id = 4 } } } } },
		}
		assert.same({ 2, 4 }, kitty.window_ids(ls))
	end)

	it("answers on the main loop, never in the middle of the call", function()
		local answered, in_fast = false, nil
		kitty.run({ "sh", "-c", "echo hi" }, function()
			answered, in_fast = true, vim.in_fast_event()
		end)
		assert.is_false(answered)
		assert.is_true(vim.wait(5000, function()
			return answered
		end))
		assert.is_false(in_fast)
	end)

	it("says why a command failed or never started", function()
		local out, err = run({ "sh", "-c", "echo broken >&2; exit 3" })
		assert.is_nil(out)
		assert.equal("broken", err)
		out, err = run({ dir .. "/missing" })
		assert.is_nil(out)
		assert.is_truthy(err)
	end)

	it("gives up on kitty past the deadline", function()
		config.set({ timeout = 100 })
		local out, err = run({ "sleep", "5" })
		assert.is_nil(out)
		assert.equal("no answer within 100 ms", err)
	end)

	it("stops reading a window at the cap, and says it cut", function()
		config.set({ max_bytes = 1000 })
		local out, _, cut = run({ "yes" })
		assert.equal(1000, #out)
		assert.is_true(cut)
	end)

	it("decodes ls, and fails on what is not JSON", function()
		local exe = h.script(dir, "kitten", { [[echo '[{"tabs":[]}]']] })
		config.set({ executable = exe })
		local ls
		kitty.ls(function(answer)
			ls = answer
		end)
		assert.is_true(vim.wait(5000, function()
			return ls ~= nil
		end))
		assert.same({ { tabs = {} } }, ls)

		config.set({ executable = h.script(dir, "kitten2", { "echo nope" }) })
		local err
		kitty.ls(function(_, e)
			err = e
		end)
		assert.is_true(vim.wait(5000, function()
			return err ~= nil
		end))
		assert.equal("kitty @ ls answered no JSON", err)
	end)
end)
