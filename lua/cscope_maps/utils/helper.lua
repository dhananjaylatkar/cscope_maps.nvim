local M = {}

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

M.default_keymaps = function(prefix)
	local map = vim.keymap.set
	local sym_map = M.sym_map
	if MiniClue then
		table.insert(MiniClue.config.clues, { mode = "n", keys = prefix, desc = "+cscope" })
	else
		local ok, wk = pcall(require, "which-key")
		if ok then
			if wk.add then
				wk.add({ { prefix, group = "+cscope" } })
			else
				wk.register({ [prefix] = { name = "+cscope" } })
			end
		end
	end
	map({ "n", "v" }, prefix .. "s", "<cmd>CsPrompt s<cr>", { desc = sym_map.s })
	map({ "n", "v" }, prefix .. "g", "<cmd>CsPrompt g<cr>", { desc = sym_map.g })
	map({ "n", "v" }, prefix .. "c", "<cmd>CsPrompt c<cr>", { desc = sym_map.c })
	map({ "n", "v" }, prefix .. "t", "<cmd>CsPrompt t<cr>", { desc = sym_map.t })
	map({ "n", "v" }, prefix .. "e", "<cmd>CsPrompt e<cr>", { desc = sym_map.e })
	map({ "n", "v" }, prefix .. "f", "<cmd>CsPrompt f<cr>", { desc = sym_map.f })
	map({ "n", "v" }, prefix .. "i", "<cmd>CsPrompt i<cr>", { desc = sym_map.i })
	map({ "n", "v" }, prefix .. "d", "<cmd>CsPrompt d<cr>", { desc = sym_map.d })
	map({ "n", "v" }, prefix .. "a", "<cmd>CsPrompt a<cr>", { desc = sym_map.a })
	map({ "n", "v" }, prefix .. "b", "<cmd>Cs db build<cr>", { desc = sym_map.b })
end

return M
