local M = {}

M.run = function(opts)
	opts = opts or {}
	local entries = {}

	for _, item in ipairs(opts.cscope.parsed_output) do
		local entry = {
			path = item.filename,
			lnum = tonumber(item.lnum),
			text = string.format("%s:%s:%s", item.filename, item.lnum, item.text),
		}
		table.insert(entries, entry)
	end

	MiniPick.start({
		source = {
			items = entries,
			name = opts.cscope.prompt_title,
			show = function(buf_id, items, query)
				MiniPick.default_show(buf_id, items, query, { show_icons = true })
			end,
		},
	})
end

return M
