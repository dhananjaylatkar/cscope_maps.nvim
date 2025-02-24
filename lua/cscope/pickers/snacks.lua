local M = {}

local prepare = function(items)
	local res = {}
	for i, item in ipairs(items) do
		table.insert(res, {
			file = item["filename"],
			score = i,
			text = item["text"],
			line = item["text"],
			pos = { tonumber(item["lnum"]), 0 },
		})
	end

	return res
end

M.run = function(opts)
	Snacks.picker({
		items = prepare(opts.cscope.parsed_output),
		title = opts.cscope.prompt_title,
	})
end

return M
