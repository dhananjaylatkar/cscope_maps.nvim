local M = {}

M.ver = vim.version()

M.init_inbuilt_cscope = function()
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

M.is_inbuilt_cscope = function()
	-- cscope is removed from nvim 0.9+
	return M.ver.major == 0 and M.ver.minor < 9
end

M.run_cscope_command = function(cmd)
	vim.api.nvim_command(cmd)
	if M.is_inbuilt_cscope() then
		vim.api.nvim_command("copen")
	end
end

-- define key table for input strings
M.sym_map = {
	s = "Find this symbol",
	g = "Find this global defination",
	c = "Find functions calling this function",
	t = "Find this text string",
	e = "Find this egrep pattern",
	f = "Find this file",
	i = "Find files #including this file",
	d = "Find functions called by this function",
	a = "Find places where this symbol is assigned a value",
	b = "Build database",
}
M.keymap_opts = { noremap = true, silent = true }

M.get_cscope_prompt_cmd = function(operation, selection)
	local sel = "cword" -- word under cursor
	if selection == "f" then -- file under cursor
		sel = "cfile"
	end

	return string.format(
		[[<cmd>lua require('cscope_maps').cscope_prompt('%s', vim.fn.expand("<%s>"))<cr>]],
		operation,
		sel
	)
end

M.keymap_wo_wk = function()
	-- Without which-key
	vim.api.nvim_set_keymap("n", "<leader>cs", M.get_cscope_prompt_cmd("s", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>cg", M.get_cscope_prompt_cmd("g", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>cc", M.get_cscope_prompt_cmd("c", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>ct", M.get_cscope_prompt_cmd("t", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>ce", M.get_cscope_prompt_cmd("e", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>cf", M.get_cscope_prompt_cmd("f", "f"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>ci", M.get_cscope_prompt_cmd("i", "f"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>cd", M.get_cscope_prompt_cmd("d", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>ca", M.get_cscope_prompt_cmd("a", "w"), M.keymap_opts)
	vim.api.nvim_set_keymap("n", "<leader>cb", "<cmd>Cscope build<cr>", M.keymap_opts)
end

M.keymap_w_wk = function(wk)
	-- With which-key
	wk.register({
		["<leader>"] = {
			c = {
				name = "+cscope",
				s = { M.get_cscope_prompt_cmd("s", "w"), M.sym_map.s },
				g = { M.get_cscope_prompt_cmd("g", "w"), M.sym_map.g },
				c = { M.get_cscope_prompt_cmd("c", "w"), M.sym_map.c },
				t = { M.get_cscope_prompt_cmd("t", "w"), M.sym_map.t },
				e = { M.get_cscope_prompt_cmd("e", "w"), M.sym_map.e },
				f = { M.get_cscope_prompt_cmd("f", "f"), M.sym_map.f },
				i = { M.get_cscope_prompt_cmd("i", "f"), M.sym_map.i },
				d = { M.get_cscope_prompt_cmd("d", "w"), M.sym_map.d },
				a = { M.get_cscope_prompt_cmd("a", "w"), M.sym_map.a },
				b = { "<cmd>Cscope build<cr>", M.sym_map.b },
			},
		},
	}, M.keymap_opts)
end

M.init_keymaps = function()
	vim.api.nvim_set_keymap("n", "<C-]>", [[<cmd>exe "Cstag" expand("<cword>")<cr>]], M.keymap_opts)

	local ok, wk = pcall(require, "which-key")
	if not ok then
		M.keymap_wo_wk()
	else
		-- which-key mappings
		M.keymap_w_wk(wk)
	end
end

return M
