local helper = require("cscope_maps.utils.helper")
local cs = require("cscope")
local M = {}

---@class CsMapsConfig
---@field disable_maps? boolean
---@field skip_input_prompt? boolean
---@field prefix? string
---@field cscope? CsConfig
M.opts = {
	disable_maps = false, -- "true" disables default keymaps
	skip_input_prompt = false, -- "true" doesn't ask for input
	prefix = "<leader>c", -- prefix to trigger maps
	cscope = {}, -- defaults are in cscope.lua
}

-- function to print xcscpoe.el like prompts
M.cscope_prompt = function(operation)
	local default_symbol = cs.default_sym(operation:sub(1, 1))
	if M.opts.skip_input_prompt then
		vim.cmd.Cscope({ args = { "find", operation, default_symbol } })
	else
		local prompt = string.format("%s (default: '%s'): ", helper.sym_map[operation], default_symbol)
		vim.ui.input({ prompt = prompt }, function(new_symbol)
			if new_symbol == nil then
				return
			end
			if new_symbol ~= "" then
				vim.cmd.Cscope({ args = { "find", operation, new_symbol } })
			else
				vim.cmd.Cscope({ args = { "find", operation, default_symbol } })
			end
		end)
	end
end

---Initialization api
---@param opts CsMapsConfig
M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	vim.api.nvim_create_user_command("CsPrompt", function(opts)
		M.cscope_prompt(opts.fargs[1])
	end, {
		nargs = "*",
		complete = function()
			return vim.tbl_keys(cs.op_s_n)
		end,
	})

	if not M.opts.disable_maps then
		-- Mappings
		helper.default_keymaps(M.opts.prefix)
	end

	cs.setup(M.opts.cscope)
	require("cscope.stack_view").setup()
end

return M
