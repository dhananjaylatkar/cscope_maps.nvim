local config = require("fzf-lua.config")
local make_entry = require("fzf-lua.make_entry")

local M = {}

local prepare = function(parsed_output)
	local res = {}

	for _, entry in ipairs(parsed_output) do
		local _entry = ("%s:%s:%s"):format(
			make_entry.file(entry["filename"], { file_icons = true, color_icons = true }),
			entry["lnum"],
			entry["text"]
		)

		table.insert(res, _entry)
	end
	return res
end

M.run = function(opts)
	local entries = prepare(opts.cscope.parsed_output)
	local _config = { prompt = opts.cscope.prompt_title .. "> " }
	_config = config.normalize_opts(_config, config.globals.files)
	require("fzf-lua").fzf_exec(entries, _config)
end

return M
