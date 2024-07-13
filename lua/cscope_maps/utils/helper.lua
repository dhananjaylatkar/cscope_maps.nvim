local M = {}
local map = vim.keymap.set

M.ver = vim.version()

M.legacy_cscope = function()
	-- cscope is removed from nvim 0.9+
	return M.ver.major == 0 and M.ver.minor < 9
end

M.run_cscope_command = function(cmd)
	vim.api.nvim_command(cmd)
	if M.legacy_cscope() then
		print(cmd)
		vim.api.nvim_command("copen")
	end
end

-- define key table for input strings
M.sym_map = {
	s = "Find this symbol",
	g = "Find this global definition",
	c = "Find functions calling this function",
	t = "Find this text string",
	e = "Find this egrep pattern",
	f = "Find this file",
	i = "Find files #including this file",
	d = "Find functions called by this function",
	a = "Find places where this symbol is assigned a value",
	b = "Build database",
}

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

M.default_keymaps = function(prefix)
	local sym_map = M.sym_map
	local ok, wk = pcall(require, "which-key")
	if ok then
		if wk.add then
			wk.add({ { prefix, group = "+cscope" } })
		else
			wk.register({ [prefix] = { name = "+cscope" } })
		end
	end
	map("n", prefix .. "s", M.get_cscope_prompt_cmd("s", "w"), { desc = sym_map.s })
	map("n", prefix .. "g", M.get_cscope_prompt_cmd("g", "w"), { desc = sym_map.g })
	map("n", prefix .. "c", M.get_cscope_prompt_cmd("c", "w"), { desc = sym_map.c })
	map("n", prefix .. "t", M.get_cscope_prompt_cmd("t", "w"), { desc = sym_map.t })
	map("n", prefix .. "e", M.get_cscope_prompt_cmd("e", "w"), { desc = sym_map.e })
	map("n", prefix .. "f", M.get_cscope_prompt_cmd("f", "f"), { desc = sym_map.f })
	map("n", prefix .. "i", M.get_cscope_prompt_cmd("i", "f"), { desc = sym_map.i })
	map("n", prefix .. "d", M.get_cscope_prompt_cmd("d", "w"), { desc = sym_map.d })
	map("n", prefix .. "a", M.get_cscope_prompt_cmd("a", "w"), { desc = sym_map.a })
	map("n", prefix .. "b", "<cmd>Cscope db build<cr>", { desc = sym_map.b })
end

M.init_keymaps = function(prefix)
	if not M.legacy_cscope() then
		map("n", "<C-]>",
			[[<cmd>exe "Cstag" expand("<cword>")<cr>]],
			{ noremap = true, silent = true, desc = "ctag" })
	end

	M.default_keymaps(prefix)
end

return M
