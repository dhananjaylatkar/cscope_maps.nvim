local RC = require("utils.ret_codes")
local cs = require("cscope")
local M = {}

-- m()
-- -> a()
-- -> b()
-- -> c()
--
-- a()
-- <- m()
--    <- n()
--
-- {a : {m : { { n : {} }, { o : {} } } }}
-- node = {data: {} children: {}}

-- callers --> DOWN the stack
-- called  --> UP the stack

local ft = "CsStackView"
local api = vim.api
local fn = vim.fn

-- TODO: move to user config
local down_indicator = "<- "
local up_indicator = "-> "

M.get_line_info = function()
	local lnum = 0
	local indent = 0
	local line = ""

	if vim.bo.filetype == ft then
		lnum = fn.line(".")
		indent = fn.indent(lnum) + #down_indicator
		line = fn.getline(".")
	end

	return lnum, indent, line
end

M.down = function(symbol)
	local rc, res = cs.cscope_get_result(cs.op_s_n.c, "c", symbol)

	if rc ~= RC.SUCCESS then
		return nil, 0
	end

	return res, M.get_line_info()
end

M.up = function(symbol)
	local rc, res = cs.cscope_get_result(cs.op_s_n.d, "d", symbol)

	if rc ~= RC.SUCCESS then
		return nil, 0
	end

	return res, M.get_line_info()
end

M.cache = { buf = nil, win = nil }

M.create_buf = function()
	local vim_height = vim.o.lines
	local vim_width = vim.o.columns

	local width = math.floor(vim_width * 0.8) + 3
	local height = math.floor(vim_height * 0.7)
	local col = vim_width * 0.1 - 1
	local row = vim_height * 0.15

	M.cache.buf = M.cache.buf or api.nvim_create_buf(false, true)
	M.cache.win = M.cache.win
		or api.nvim_open_win(M.cache.buf, true, {
			relative = "editor",
			title = ft,
			title_pos = "center",
			width = width,
			height = height,
			col = col,
			row = row,
			style = "minimal",
			focusable = false,
			border = "single",
		})
	api.nvim_buf_set_option(M.cache.buf, "filetype", ft)
end

M.buf_lock = function()
	api.nvim_buf_set_option(M.cache.buf, "readonly", true)
	api.nvim_buf_set_option(M.cache.buf, "modifiable", false)
end

M.buf_unlock = function()
	api.nvim_buf_set_option(M.cache.buf, "readonly", false)
	api.nvim_buf_set_option(M.cache.buf, "modifiable", true)
end

M.update_buf = function(l_start, l_end, lines)
	M.create_buf()

	M.buf_unlock()
	api.nvim_buf_set_lines(M.cache.buf, l_start, l_end, false, lines)
	M.buf_lock()
end

local tree = require("cscope.stack_view.tree")
local root = nil

M.add_to_tree = function(symbol, filename, lnum, children)
	if root == nil then
		root = tree.create_node(symbol, filename, lnum)
		root.children = children
		return
	end

	tree.update_children(root, symbol, filename, lnum, children)
end

M.line_to_data = function(line)
	line = vim.trim(line)
	local line_split = vim.split(line, "%s+")
	local symbol = line_split[2]
	local filename = ""
	local lnum = 0

	if #line_split == 3 then
		local file_loc = vim.split(line_split[3], ":")
		filename = file_loc[1]:sub(2)
		lnum = tonumber(file_loc[2]:sub(1, -2), 10)
	end

	print("line_to_data", symbol, filename, lnum)
	return symbol, filename, lnum
end

-- test func for DOWN
M.run = function(symbol)
	local res, lnum, indent, line = M.down(symbol)

	if not res then
		return
	end

	local psymbol, pfilename, plnum = M.line_to_data(line)

	if vim.bo.filetype ~= ft then
		-- we are not in CsStackView buff
		-- so use current filename and linenumber
		psymbol = symbol
		plnum = fn.line(".")
		pfilename = fn.expand("%")
	end

	local lines = {}
	local children = {}

	if M.cache.buf == nil then
		table.insert(lines, symbol)
	end

	for _, r in ipairs(res) do
		local item = string.format(
			"%s%s%s [%s:%d]",
			string.rep(" ", indent or 0),
			down_indicator,
			r.ctx:gsub("<", ""):gsub(">", ""),
			r.filename,
			r.lnum
		)
		table.insert(lines, item)
		local node = tree.create_node(r.ctx:gsub("<", ""):gsub(">", ""), r.filename, tonumber(r.lnum, 10))
		table.insert(children, node)
	end

	M.add_to_tree(psymbol, pfilename, plnum, children)

	M.update_buf(lnum, lnum, lines)
	if vim.bo.filetype == ft then
		api.nvim_win_set_cursor(0, { lnum + 1, indent })
	end
	print(vim.inspect(root))
end

return M
