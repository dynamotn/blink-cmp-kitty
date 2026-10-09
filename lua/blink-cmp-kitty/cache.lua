--- The words read from kitty, kept between completions
---
--- A completion never waits on kitty: it is answered from here at once, and
--- a read of the windows is started in the background when the last one is
--- older than `min_update_period`. A word stays `item_lifetime` seconds
--- after the last read that found it, so a window scrolled or closed a
--- moment ago still completes.
local config = require("blink-cmp-kitty.config")
local kitty = require("blink-cmp-kitty.kitty")
local log = require("blink-cmp-kitty.log")
local words = require("blink-cmp-kitty.words")

local M = {}

---@class blink-cmp-kitty.Entry
---@field kind blink-cmp-kitty.Kind
---@field expires integer `os.time()` it is dropped at

---@type table<string, blink-cmp-kitty.Entry>
M.items = {}

--- `os.time()` the last read started at
M.last_update = 0

--- Whether a read is running; a second one waits for the next request
M.updating = false

--- Why the last read failed, for `:BlinkCmpKittyItems`
---@type string?
M.last_error = nil

--- Keep `found` for `item_lifetime` from `now`
---@param found table<string, blink-cmp-kitty.Kind>
---@param now integer
function M.add(found, now)
	local expires = now + config.options.item_lifetime
	for word, kind in pairs(found) do
		M.items[word] = { kind = kind, expires = expires }
	end
end

--- Drop what has outlived its lifetime
---@param now integer
function M.prune(now)
	for word, entry in pairs(M.items) do
		if entry.expires < now then
			M.items[word] = nil
		end
	end
end

--- Every word kept, sorted, with its kind
---@return { word: string, kind: blink-cmp-kitty.Kind }[]
function M.list()
	local list = {}
	for word, entry in pairs(M.items) do
		table.insert(list, { word = word, kind = entry.kind })
	end
	table.sort(list, function(a, b)
		return a.word < b.word
	end)
	return list
end

---@param now integer
---@return boolean
function M.due(now)
	return now - M.last_update >= config.options.min_update_period
end

--- Read every window kitty lists, one after the other, in the background
---
--- Without `force`, only once `min_update_period` has passed; with it (on
--- entering a window), whenever no read is running.
---@param opts? { force?: boolean, on_done?: fun() }
---@return boolean started Whether a read started, and `on_done` will be called
function M.refresh(opts)
	opts = opts or {}
	local now = os.time()
	if M.updating or not kitty.available() or (not opts.force and not M.due(now)) then
		return false
	end
	M.updating, M.last_update = true, now

	local function finish(err)
		M.last_error = err
		M.prune(os.time())
		M.updating = false
		log.debug("%d words kept", vim.tbl_count(M.items))
		if opts.on_done then
			opts.on_done()
		end
	end

	kitty.ls(function(ls, err)
		if not ls then
			return finish(err)
		end
		local ids = kitty.window_ids(ls)
		local index = 0
		local function next_window()
			index = index + 1
			if index > #ids then
				return finish(nil)
			end
			kitty.text(ids[index], function(text)
				if text then
					M.add(words.extract(text), os.time())
				end
				next_window()
			end)
		end
		next_window()
	end)
	return true
end

--- Forget every word, and when the last read ran
function M.clear()
	M.items, M.last_update, M.last_error = {}, 0, nil
end

return M
