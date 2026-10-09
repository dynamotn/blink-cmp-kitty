--- The words of a kitty window worth completing, and what kind each one is
local M = {}

---@alias blink-cmp-kitty.Kind "text"|"value"

--- Each matcher, in order: a word found by a later one takes its kind
---@type { name: string, pattern: string, kind: blink-cmp-kitty.Kind, keep?: fun(word: string): boolean }[]
M.MATCHERS = {
	{ name = "alphanumeric", pattern = "[%a%d][%a%d][%a%d]+", kind = "text" },
	{
		name = "kebab_case",
		pattern = "%w[%w-]+%w",
		kind = "text",
		keep = function(word)
			return word:find("-", 1, true) ~= nil
		end,
	},
	{
		name = "snake_case",
		pattern = "%w[%w_]+%w",
		kind = "text",
		keep = function(word)
			return word:find("_", 1, true) ~= nil
		end,
	},
	{
		name = "dot_case",
		pattern = "%w[%w.]+%w",
		kind = "text",
		keep = function(word)
			return word:find(".", 1, true) ~= nil
		end,
	},
	{ name = "email", pattern = "[%w._-]+@[%w_-]+%.[%w.]+", kind = "value" },
	{ name = "url", pattern = "%a[%w+.-]*://[%w/._~%%:?#@!$&'()*+,;=-]+", kind = "value" },
	{ name = "option", pattern = "%-%-%w[%w_-]*%w", kind = "value" },
}

--- The words of `text`, each with its kind
---@param text string
---@param found? table<string, blink-cmp-kitty.Kind> Added to, when given
---@return table<string, blink-cmp-kitty.Kind>
function M.extract(text, found)
	found = found or {}
	for _, matcher in ipairs(M.MATCHERS) do
		for word in text:gmatch(matcher.pattern) do
			-- A sentence's full stop or a URL's closing bracket is not part of it
			if matcher.kind == "value" then
				word = word:gsub("[.,;:)]+$", "")
			end
			if #word > 0 and (not matcher.keep or matcher.keep(word)) then
				found[word] = matcher.kind
			end
		end
	end
	return found
end

return M
