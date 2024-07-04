local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local config = require("telescope.config")
local utils = require("telescope.utils")
local cs_utils = require("cscope_maps.utils")

local entry_maker = function(entry)
	return {
		value = entry,
		display = function()
			local display_filename = cs_utils.get_rel_path(vim.fn.getcwd(), entry["filename"])
			local coordinates = string.format(":%s:", entry["lnum"])
			local display_string = "%s%s%s"
			local display, hl_group, icon = utils.transform_devicons(
				entry["filename"],
				string.format(display_string, display_filename, coordinates, entry["text"]),
				false
			)

			if hl_group then
				return display, { { { 1, #icon }, hl_group } }
			else
				return display
			end
		end,
		ordinal = entry["filename"] .. entry["text"],
		path = entry["filename"],
		lnum = tonumber(entry["lnum"]),
	}
end

local finder = nil
local prompt_title = nil

local prepare = function(cscope_parsed_output, telescope_title)
	finder = finders.new_table({
		results = cscope_parsed_output,
		entry_maker = entry_maker,
	})

	prompt_title = telescope_title
end

M.run = function(opts)
	opts = opts or {}
	opts.entry_maker = entry_maker
	-- print(vim.inspect(opts.cscope))
	prepare(opts.cscope.parsed_output, opts.cscope.prompt_title)

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
