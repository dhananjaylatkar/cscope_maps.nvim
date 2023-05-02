------------------------------------
-- CSCOPE settings for nvim in lua
------------------------------------
local M = {}

-- Configurable options
M.opts = {
	disable_maps = false,
	cscope = {
		db_file = "./cscope.out",
		use_telescope = false,
	},
}

local inbuilt_cscope_opts = function()
	-- use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
	vim.opt.cscopetag = true
	-- check cscope for definition of a symbol before checking ctags: set to 1
	-- if you want the reverse search order.
	vim.opt.csto = 0
	-- show msg when cscope db added
	vim.opt.cscopeverbose = true
	-- results in quickfix window
	vim.opt.cscopequickfix = "s-,g-,c-,t-,e-,f-,i-,d-,a-"
	-- add cscope database in current directory
	vim.api.nvim_command("cs add " .. M.opts.cscope.db_file)
end

local ver = vim.version()

local is_supported_version = function()
	-- cscope is removed from nvim 0.9+
	return ver.major == 0 and ver.minor < 9
end

-- define key table for input strings
local sym_map = {
	["s"] = "Find this symbol",
	["g"] = "Find this global defination",
	["c"] = "Find functions calling this function",
	["t"] = "Find this text string",
	["e"] = "Find this egrep pattern",
	["f"] = "Find this file",
	["i"] = "Find files #including this file",
	["d"] = "Find functions called by this function",
	["a"] = "Find places where this symbol is assigned a value",
}
local keymap_opts = { noremap = true, silent = true }

local keymap_wo_wk = function()
	-- Without which-key
	vim.api.nvim_set_keymap(
		"n",
		"<leader>cs",
		[[<cmd>lua require('cscope_maps').cscope_prompt('s', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>cg",
		[[<cmd>lua require('cscope_maps').cscope_prompt('g', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>cc",
		[[<cmd>lua require('cscope_maps').cscope_prompt('c', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>ct",
		[[<cmd>lua require('cscope_maps').cscope_prompt('t', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>ce",
		[[<cmd>lua require('cscope_maps').cscope_prompt('e', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>cf",
		[[<cmd>lua require('cscope_maps').cscope_prompt('f', vim.fn.expand("<cfile>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>ci",
		[[<cmd>lua require('cscope_maps').cscope_prompt('i', vim.fn.expand("<cfile>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>cd",
		[[<cmd>lua require('cscope_maps').cscope_prompt('d', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
	vim.api.nvim_set_keymap(
		"n",
		"<leader>ca",
		[[<cmd>lua require('cscope_maps').cscope_prompt('a', vim.fn.expand("<cword>"))<cr>]],
		keymap_opts
	)
end

local keymap_w_wk = function(wk)
	-- With which-key
	wk.register({
		["<leader>"] = {
			c = {
				name = "+code",
				s = { "<cmd>lua require('cscope_maps').cscope_prompt('s', vim.fn.expand('<cword>'))<cr>", sym_map["s"] },
				g = { "<cmd>lua require('cscope_maps').cscope_prompt('g', vim.fn.expand('<cword>'))<cr>", sym_map["g"] },
				c = { "<cmd>lua require('cscope_maps').cscope_prompt('c', vim.fn.expand('<cword>'))<cr>", sym_map["c"] },
				t = { "<cmd>lua require('cscope_maps').cscope_prompt('t', vim.fn.expand('<cword>'))<cr>", sym_map["t"] },
				e = { "<cmd>lua require('cscope_maps').cscope_prompt('e', vim.fn.expand('<cword>'))<cr>", sym_map["e"] },
				f = { "<cmd>lua require('cscope_maps').cscope_prompt('f', vim.fn.expand('<cfile>'))<cr>", sym_map["f"] },
				i = { "<cmd>lua require('cscope_maps').cscope_prompt('i', vim.fn.expand('<cfile>'))<cr>", sym_map["i"] },
				d = { "<cmd>lua require('cscope_maps').cscope_prompt('d', vim.fn.expand('<cword>'))<cr>", sym_map["d"] },
				a = { "<cmd>lua require('cscope_maps').cscope_prompt('a', vim.fn.expand('<cword>'))<cr>", sym_map["a"] },
			},
		},
	}, keymap_opts)
end

M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	local cscope = "Cscope"

	if is_supported_version() then
		if vim.loop.fs_stat(M.opts.cscope.db_file, "r") ~= nil then
			inbuilt_cscope_opts()
		end
		cscope = "cscope"
	else
		-- Use cscope lua port
		require("cscope.cscope").setup(M.opts.cscope)
	end

	-- function to print xcscpoe.el like prompts
	M.cscope_prompt = function(operation, default_symbol)
		local prompt = sym_map[operation] .. " (default: '" .. default_symbol .. "'): "
		local cmd = cscope .. " find " .. operation
		vim.ui.input({ prompt = prompt }, function(new_symbol)
			if new_symbol and new_symbol ~= "" then
				cmd = cmd .. " " .. new_symbol
			else
				cmd = cmd .. " " .. default_symbol
			end
			vim.api.nvim_command(cmd)
			if is_supported_version() then
				vim.api.nvim_command("copen")
			end
		end)
	end

	if M.opts.disable_maps then
		-- No need to proceed
		return
	end

	-- Mappings
	local ok, wk = pcall(require, "which-key")
	if not ok then
		keymap_wo_wk()
	else
		-- which-key mappings
		keymap_w_wk(wk)
	end
end

return M
