local helper = require("cscope_maps.utils.helper")
local sv = require("cscope.stack_view")
local M = {}

-- Configurable options
M.opts = {
	disable_maps = false, -- "true" disables default keymaps
	skip_input_prompt = false, -- "true" doesn't ask for input
	prefix = "<leader>c", -- prefix to trigger maps
	cscope = {}, -- defaults are in cscope.lua
}

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	local cscope = "Cscope"

	if helper.legacy_cscope() then
		cscope = "cscope"
	end

	require("cscope").setup(M.opts.cscope)

	-- function to print xcscpoe.el like prompts
	M.cscope_prompt = function(operation, default_symbol)
		local cmd = cscope .. " find " .. operation
		if M.opts.skip_input_prompt then
			cmd = cmd .. " " .. default_symbol
			helper.run_cscope_command(cmd)
		else
			local prompt = helper.sym_map[operation] .. " (default: '" .. default_symbol .. "'): "
			vim.ui.input({ prompt = prompt }, function(new_symbol)
				if new_symbol == nil then
					return
				end
				if new_symbol ~= "" then
					cmd = cmd .. " " .. new_symbol
				else
					cmd = cmd .. " " .. default_symbol
				end
				helper.run_cscope_command(cmd)
			end)
		end
	end

	if not M.opts.disable_maps then
		-- Mappings
		helper.init_keymaps(M.opts.prefix)
	end

	sv.setup()
end

return M
