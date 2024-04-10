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

	if vim.bo.filetype == ft then
		lnum = fn.line(".")
		indent = fn.indent(lnum) + #down_indicator
	end

	return lnum, indent
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

-- test func for DOWN
M.run = function(symbol)
	local res, lnum, indent = M.down(symbol)
	if not res then
		return
	end

	local lines = {}

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
	end

	M.update_buf(lnum, lnum, lines)
	api.nvim_win_set_cursor(0, {lnum+1, indent})
end

return M
