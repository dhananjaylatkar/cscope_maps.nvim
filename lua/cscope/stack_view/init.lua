local cs = require("cscope")
local tree = require("cscope.stack_view.tree")
local hl = require("cscope.stack_view.hl")
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

M.cache = { sv = { buf = nil, win = nil }, pv = { buf = nil, win = nil } }
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

M.ft = "CsStackView"
local api = vim.api
local fn = vim.fn
local root = nil
local buf_lines = nil
local cur_dir = nil
local buf_last_pos = nil

M.buf_lock = function(buf)
	api.nvim_set_option_value("readonly", true, { buf = buf })
	api.nvim_set_option_value("modifiable", false, { buf = buf })
end

M.buf_unlock = function(buf)
	api.nvim_set_option_value("readonly", false, { buf = buf })
	api.nvim_set_option_value("modifiable", true, { buf = buf })
end

M.buf_open = function()
	local vim_height = vim.o.lines
	local vim_width = vim.o.columns

	local width = math.floor(vim_width * 0.8 / 2 + 3 / 2)
	local height = math.floor(vim_height * 0.7)
	local col = vim_width * 0.1 - 1
	local row = vim_height * 0.15

	M.cache.pv.buf = M.cache.pv.buf or api.nvim_create_buf(false, true)
	M.cache.pv.win = M.cache.pv.win
		or api.nvim_open_win(M.cache.pv.buf, true, {
			relative = "editor",
			title = "preview",
			title_pos = "center",
			width = width,
			height = height,
			col = col + 1 + width,
			row = row,
			style = "minimal",
			focusable = false,
			border = "single",
		})
	api.nvim_set_option_value("filetype", "c", { buf = M.cache.pv.buf })
	api.nvim_set_option_value("cursorline", true, { win = M.cache.pv.win })

	M.cache.sv.buf = M.cache.sv.buf or api.nvim_create_buf(false, true)
	M.cache.sv.win = M.cache.sv.win
		or api.nvim_open_win(M.cache.sv.buf, true, {
			relative = "editor",
			title = M.ft,
			title_pos = "center",
			width = width,
			height = height,
			col = col - 1,
			row = row,
			style = "minimal",
			focusable = false,
			border = "single",
		})
	api.nvim_set_option_value("filetype", M.ft, { buf = M.cache.sv.buf })
	api.nvim_set_option_value("cursorline", true, { win = M.cache.sv.win })
end

M.buf_close = function()
	if M.cache.sv.buf ~= nil and api.nvim_buf_is_valid(M.cache.sv.buf) then
		api.nvim_buf_delete(M.cache.sv.buf, { force = true })
	end

	if M.cache.sv.win ~= nil and api.nvim_win_is_valid(M.cache.sv.win) then
		api.nvim_win_close(M.cache.sv.win, true)
	end

	if M.cache.pv.buf ~= nil and api.nvim_buf_is_valid(M.cache.pv.buf) then
		api.nvim_buf_delete(M.cache.pv.buf, { force = true })
	end

	if M.cache.pv.win ~= nil and api.nvim_win_is_valid(M.cache.pv.win) then
		api.nvim_win_close(M.cache.pv.win, true)
	end

	M.cache.sv.buf = nil
	M.cache.sv.win = nil

	M.cache.pv.buf = nil
	M.cache.pv.win = nil
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

	M.buf_unlock(M.cache.sv.buf)
	api.nvim_buf_set_lines(M.cache.sv.buf, 0, -1, false, buf_lines)
	if buf_last_pos ~= nil then
		api.nvim_win_set_cursor(M.cache.sv.win, { buf_last_pos, 0 })
		buf_last_pos = nil
	end
	M.buf_lock(M.cache.sv.buf)

	local keymap_opt = { buffer = M.cache.sv.buf, silent = true }
	vim.keymap.set("n", "q", M.toggle_win, keymap_opt)
	vim.keymap.set("n", "<esc>", M.toggle_win, keymap_opt)
	vim.keymap.set("n", "<tab>", M.toggle_children, keymap_opt)
	vim.keymap.set("n", "<cr>", M.enter_action, keymap_opt)

	local augroup = api.nvim_create_augroup("CscopeMaps", {})
	api.nvim_create_autocmd({ "BufLeave" }, {
		group = augroup,
		buffer = M.cache.sv.buf,
		callback = M.toggle_win,
	})

	api.nvim_create_autocmd("CursorMoved", {
		group = augroup,
		buffer = M.cache.sv.buf,
		callback = function()
			hl.refresh(M.cache.sv.buf, root, #buf_lines)
			M.preview_update()
		end,
	})
end

--- Read data from given file
--- @param file string
--- @return table
M.read_lines_from_file = function(file)
	local lines = {}
	for line in io.lines(file) do
		lines[#lines + 1] = line
	end
	return lines
end

--- Update preview window to show location under cursor
M.preview_update = function()
	vim.schedule(function()
		local _, filename, lnum = M.line_to_data(fn.getline("."))
		if filename == "" then
			api.nvim_buf_set_lines(M.cache.pv.buf, 0, -1, false, {})
			return
		end
		local lines = M.read_lines_from_file(filename)
		api.nvim_buf_set_lines(M.cache.pv.buf, 0, -1, false, lines)
		api.nvim_win_set_cursor(M.cache.pv.win, { lnum, 0 })
	end)
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
	if vim.bo.filetype ~= M.ft then
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
	if vim.bo.filetype == M.ft then
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
	if vim.bo.filetype == M.ft then
		buf_last_pos = fn.line(".")
		M.buf_close()
		return
	end
	M.buf_update()
end

M.enter_action = function()
	if vim.bo.filetype ~= M.ft then
		return
	end

	if fn.line(".") == 1 then
		return
	end

	local _, pfilename, plnum = M.line_to_data(fn.getline("."))
	M.toggle_win()
	api.nvim_command("edit +" .. plnum .. " " .. pfilename)
end

-- :CsStackView toggle
-- :CsStackView open down|up symbol

M.run_cmd = function(args)
	local cmd = args[1]

	if vim.startswith(cmd, "o") then
		if #args ~= 3 then
			return
		end
		local stk_dir = args[2]
		local symbol = args[3]
		if vim.startswith(stk_dir, "d") then
			stk_dir = "down"
		elseif vim.startswith(stk_dir, "u") then
			stk_dir = "up"
		end
		M.open(stk_dir, symbol)
	elseif vim.startswith(cmd, "t") then
		M.toggle_win()
	end
end

M.set_user_cmd = function()
	-- Create the :CsStackView user command
	vim.api.nvim_create_user_command("CsStackView", function(opts)
		M.run_cmd(opts.fargs)
	end, {
		nargs = "*",
		complete = function(_, line)
			local cmds = { "open", "toggle" }
			local l = vim.split(line, "%s+")
			local n = #l - 2

			if n == 0 then
				return vim.tbl_filter(function(val)
					return vim.startswith(val, l[2])
				end, cmds)
			end

			if n == 1 and vim.startswith(l[2], "o") then
				return { "down", "up" }
			end
		end,
	})
end

M.setup = function()
	M.set_user_cmd()
end

return M
