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
	local snacks_opts = opts.cscope.picker_opts.snacks or {}
	snacks_opts.items = prepare(opts.cscope.parsed_output)
	snacks_opts.title = opts.cscope.prompt_title
	Snacks.picker(snacks_opts)
end

return M
