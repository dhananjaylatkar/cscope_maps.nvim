local tree = require("cscope.stack_view.tree")
local fn = vim.fn
local api = vim.api

local M = {}

M.get_pos = function(lnum)
	local line = fn.getline(lnum)
        local indent_len = #line
	line = vim.trim(line)
        indent_len = indent_len - #line

	local line_split = vim.split(line, "%s+")
	local symbol = line_split[2]
	local fname = ""
	local lnum = 0

	if #line_split == 3 then
		local file_loc = vim.split(line_split[3], ":")
		fname = file_loc[1]:sub(2)
		lnum = file_loc[2]:sub(1, -2)
	end

	local indicator_s = indent_len
	local indicator_e = indicator_s+2

	local symbol_s = indicator_e+1
	local symbol_e = symbol_s + #symbol

	local bo_s = symbol_e+1
	local bo_e = bo_s+1

	local fname_s = symbol_e+2
	local fname_e = fname_s + #fname

	local delim_s = fname_e
	local delim_e = fname_e+1

	local lnum_s = fname_e+1
	local lnum_e = lnum_s+#lnum

	local bc_s = lnum_e
	local bc_e = bc_s+1

	return indicator_s, indicator_e, symbol_s, symbol_e, bo_s, bo_e, fname_s, fname_e, delim_s, delim_e, lnum_s, lnum_e, bc_s, bc_e
end

M.refresh = function(buf, root)
	local ancestors = tree.get_ancestors(root, fn.line("."))

	local ns = api.nvim_create_namespace("CsStackViewHighlight")

	api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, a in ipairs(ancestors) do
		buf_lnum = a - 1
		if a == 1 then
			api.nvim_buf_add_highlight(buf, ns, "Function", buf_lnum, 0, -1)
		else
			local indicator_s, indicator_e, symbol_s, symbol_e, bo_s, bo_e, fname_s, fname_e, delim_s, delim_e, lnum_s, lnum_e, bc_s, bc_e = M.get_pos(a)
			api.nvim_buf_add_highlight(buf, ns, "Operator", buf_lnum,  indicator_s, indicator_e)
			api.nvim_buf_add_highlight(buf, ns, "Function", buf_lnum,  symbol_s, symbol_e)
			api.nvim_buf_add_highlight(buf, ns, "Delimiter", buf_lnum,  bo_s, bo_e)
			api.nvim_buf_add_highlight(buf, ns, "String", buf_lnum,  fname_s, fname_e)
			api.nvim_buf_add_highlight(buf, ns, "Delimiter", buf_lnum,  delim_s, delim_e)
			api.nvim_buf_add_highlight(buf, ns, "Number", buf_lnum,  lnum_s, lnum_e)
			api.nvim_buf_add_highlight(buf, ns, "Delimiter", buf_lnum,  bc_s, bc_e)
		end
	end

end

return M
