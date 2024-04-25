local cs = require("cscope")
local tree = require("cscope.stack_view.tree")
local hl = require("cscope.stack_view.highlight")
local RC = require("utils.ret_codes")
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

M.cache = { buf = nil, win = nil }
M.dir_map = {
	down = {
		indicator = "<- ",
		cs_func = function(symbol)
			local _, res = cs.cscope_get_result(cs.op_s_n.c, "c", symbol)
			return res
		end,
	},
	up = {
		indicator = "-> ",
		cs_func = function(symbol)
			local _, res = cs.cscope_get_result(cs.op_s_n.d, "d", symbol)
			return res
		end,
	},
}

local ft = "CsStackView"
local api = vim.api
local fn = vim.fn
local root = nil
local buf_lines = nil
local cur_dir = nil
local buf_last_pos = nil

M.buf_lock = function()
	api.nvim_buf_set_option(M.cache.buf, "readonly", true)
	api.nvim_buf_set_option(M.cache.buf, "modifiable", false)
end

M.buf_unlock = function()
	api.nvim_buf_set_option(M.cache.buf, "readonly", false)
	api.nvim_buf_set_option(M.cache.buf, "modifiable", true)
end

M.buf_open = function()
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
	api.nvim_win_set_option(M.cache.win, "cursorline", true)
end

M.buf_close = function()
	if M.cache.buf ~= nil and api.nvim_buf_is_valid(M.cache.buf) then
		api.nvim_buf_delete(M.cache.buf, { force = true })
	end

	if M.cache.win ~= nil and api.nvim_win_is_valid(M.cache.win) then
		api.nvim_win_close(M.cache.win, true)
	end

	M.cache.buf = nil
	M.cache.win = nil
end

M.buf_update = function()
	if root == nil then
		return
	end

	-- print(vim.inspect(root))
	buf_lines = {}
	M.buf_create_lines(root)
	-- print(vim.inspect(buf_lines))
	M.buf_open()

	M.buf_unlock()
	api.nvim_buf_set_lines(M.cache.buf, 0, -1, false, buf_lines)
	if buf_last_pos ~= nil then
		api.nvim_win_set_cursor(M.cache.win, { buf_last_pos, 0 })
		buf_last_pos = nil
	end
	M.buf_lock()

	local keymap_opt = { buffer = M.cache.buf, silent = true }
	vim.keymap.set("n", "q", M.toggle_win, keymap_opt)
	vim.keymap.set("n", "<esc>", M.toggle_win, keymap_opt)
	vim.keymap.set("n", "<tab>", M.toggle_children, keymap_opt)
	vim.keymap.set("n", "<cr>", M.enter_action, keymap_opt)

	local augroup = api.nvim_create_augroup("CscopeMaps", {})
	api.nvim_create_autocmd({ "BufLeave" }, {
		group = augroup,
		buffer = M.cache.buf,
		callback = M.buf_close,
	})
	hl.refresh(M.cache.buf, root)
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

	return symbol, filename, lnum
end

M.buf_create_lines = function(node)
	local item = ""
	if node.is_root then
		item = node.data.symbol
	else
		item = string.format(
			"%s%s%s [%s:%s]",
			string.rep(" ", node.depth * #M.dir_map[cur_dir].indicator),
			M.dir_map[cur_dir].indicator,
			node.data.symbol,
			node.data.filename,
			node.data.lnum
		)
	end

	table.insert(buf_lines, item)
        node.id = #buf_lines

	if not node.children then
		return
	end

	for _, c in ipairs(node.children) do
		M.buf_create_lines(c)
	end
end

M.toggle_children = function()
	if vim.bo.filetype ~= ft then
		return
	end

	if cur_dir == nil then
		return
	end

	if root == nil then
		return
	end

        local cur_line = fn.line(".")

	if cur_line == 1 then
		return
	end

	local psymbol, pfilename, plnum = M.line_to_data(fn.getline("."))
        local parent_id = cur_line
	local cs_res = M.dir_map[cur_dir].cs_func(psymbol)

	if not cs_res then
		return
	end

	-- update children list
	local children = {}
	for _, r in ipairs(cs_res) do
		local node = tree.create_node(r.ctx:sub(3, -3), r.filename, r.lnum)
		table.insert(children, node)
	end

	root = tree.update_node(root, parent_id, children)
	M.buf_update()
end

M.open = function(dir, symbol)
	if vim.bo.filetype == ft then
		return
	end

	M.buf_close()
	root = nil
	buf_last_pos = nil

	if not vim.tbl_contains(vim.tbl_keys(M.dir_map), dir) then
		return
	end

	local cs_res = M.dir_map[dir].cs_func(symbol)

	if not cs_res then
		return
	end

	cur_dir = dir

	-- update children list
	local children = {}
	for _, r in ipairs(cs_res) do
		local node = tree.create_node(r.ctx:sub(3, -3), r.filename, r.lnum)
		table.insert(children, node)
	end

	root = tree.create_node(symbol, "", 0)
	root.children = children
	root.is_root = true

	M.buf_update()
end

M.toggle_win = function()
	if vim.bo.filetype == ft then
		buf_last_pos = fn.line(".")
		M.buf_close()
		return
	end
	M.buf_update()
end

M.enter_action = function()
	if vim.bo.filetype ~= ft then
		return
	end

	if fn.line(".") == 1 then
		return
	end

	local _, pfilename, plnum = M.line_to_data(fn.getline("."))
	M.toggle_win()
	api.nvim_command("edit +" .. plnum .. " " .. pfilename)
end

-- :Cs stack_view toggle
-- :Cs stack_view open down|up symbol

return M
