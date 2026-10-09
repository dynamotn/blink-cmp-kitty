local cache = require("blink-cmp-kitty.cache")
local config = require("blink-cmp-kitty.config")
local kitty = require("blink-cmp-kitty.kitty")

---@module "blink.cmp"
---@class blink.cmp.kittySource: blink.cmp.Source
---@field opts blink-cmp-kitty.Opts
local source = {}

---@param opts? blink-cmp-kitty.Opts
---@return blink.cmp.kittySource
function source.new(opts)
	config.set(opts)
	local self = setmetatable({ opts = config.options }, { __index = source })
	-- Read once now, so the first completion has words to offer
	cache.refresh({ force = true })
	return self
end

---@return boolean
function source:enabled()
	return self.opts.enabled and kitty.available()
end

---@return string[]
function source:get_trigger_characters()
	return self.opts.trigger_chars
end

---@param context blink.cmp.Context
---@return boolean
function source:triggered(context)
	if not self.opts.triggered_only then
		return true
	end
	local before = context.line:sub(context.bounds.start_col - 1, context.bounds.start_col - 1)
	return vim.list_contains(self:get_trigger_characters(), before)
end

---@param context blink.cmp.Context
---@return lsp.CompletionItem[]
function source:get_completion_items(context)
	local kinds = require("blink.cmp.types").CompletionItemKind
	return vim.iter(cache.list())
		:map(function(entry)
			---@type lsp.CompletionItem
			local item = {
				label = entry.word,
				kind = entry.kind == "value" and kinds.Value or kinds.Text,
				insertText = entry.word,
			}
			if self.opts.triggered_only then
				-- Over the trigger character too, which the word replaces
				item.textEdit = {
					newText = entry.word,
					range = {
						start = { line = context.cursor[1] - 1, character = context.bounds.start_col - 2 },
						["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] },
					},
				}
			end
			return item
		end)
		:totable()
end

--- Answered from the words kept at once; a read of the windows starts in
--- the background when they are due
---@param context blink.cmp.Context
---@param callback fun(response: blink.cmp.CompletionResponse)
function source:get_completions(context, callback)
	cache.refresh()
	callback({
		items = self:triggered(context) and self:get_completion_items(context) or {},
		is_incomplete_backward = false,
		is_incomplete_forward = false,
	})
end

return source
