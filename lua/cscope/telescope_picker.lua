local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local config = require("telescope.config")

local entry_maker = function(entry)
	return {
		value = entry,
		display = string.gsub(entry["filename"], vim.loop.cwd() .. "/", "")
			.. ":"
			.. entry["lnum"]
			.. " | "
			.. entry["text"],
		ordinal = entry["filename"],
		path = entry["filename"],
		lnum = tonumber(entry["lnum"]),
	}
end

local finder = nil
local prompt_title = nil

M.prepare = function(cscope_parsed_output, telescope_title)
	finder = finders.new_table({
		results = cscope_parsed_output,
		entry_maker = entry_maker,
	})

	prompt_title = telescope_title
end

M.run = function(opts)
	opts = opts or {}
	opts.entry_maker = entry_maker

	pickers
		.new(opts, {
			prompt_title = prompt_title,
			finder = finder,
			previewer = config.values.grep_previewer(opts),
			sorter = config.values.generic_sorter(opts),
		})
		:find()
end

return M
