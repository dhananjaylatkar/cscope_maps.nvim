local cs = require("cscope")
local tree = require("cscope.stack_view.tree")
local hl = require("cscope.stack_view.hl")
local utils = require("cscope_maps.utils")
local M = {}

local def_width_scale = 0.85 -- width scale of stack view window (take 85% of the total height)
local def_height_scale = 0.8 -- height scale of stack view window (take 80% of the total height)

M.opts = {
	tree_hl = true, -- toggle tree highlighting
	width_scale = def_width_scale,
	height_scale = def_height_scale,
}

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

M.cache = { sv = { buf = nil, win = nil }, pv = { buf = nil, win = nil, files = {}, last_file = "" } }
M.dir_map = {
	down = {
		indicator = "<- ",
		cs_func = function(symbol)
			local _, res = cs.get_result(cs.op_s_n.c, "c", symbol)
			return res
		end,
	},
	up = {
		indicator = "-> ",
		cs_func = function(symbol)
			local _, res = cs.get_result(cs.op_s_n.d, "d", symbol)
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

M.pv_scroll = function(dir)
	local input = dir > 0 and [[]] or [[]]

	return function()
		vim.api.nvim_win_call(M.cache.pv.win, function()
			vim.cmd([[normal! ]] .. input)
		end)
	end
end

M.set_keymaps = function()
	local opts = { buffer = M.cache.sv.buf, silent = true }

	-- close window
	vim.keymap.set("n", "q", M.toggle_win, opts)
	vim.keymap.set("n", "<esc>", M.toggle_win, opts)

	-- toggle children
	vim.keymap.set("n", "<tab>", M.toggle_children, opts)

	-- open location under cursor
	vim.keymap.set("n", "<cr>", M.enter_action, opts)

	-- scroll up
	vim.keymap.set("n", "<C-u>", M.pv_scroll(-1), opts)
	vim.keymap.set("n", "<C-y>", M.pv_scroll(-1), opts)

	-- scroll down
	vim.keymap.set("n", "<C-d>", M.pv_scroll(1), opts)
	vim.keymap.set("n", "<C-e>", M.pv_scroll(1), opts)
end

M.buf_open = function(width_scale, height_scale)
	local vim_height = vim.o.lines
	local vim_width = vim.o.columns

	local w_scale = width_scale
	local h_scale = height_scale
	local width = math.floor(vim_width * w_scale * 0.5)
	local height = math.floor(vim_height * h_scale)
	local col = vim_width * (1 - w_scale) * 0.5
	local row = vim_height * (1 - h_scale) * 0.5

	M.cache.pv.buf = M.cache.pv.buf or api.nvim_create_buf(false, true)
	M.cache.pv.win = M.cache.pv.win
		or api.nvim_open_win(M.cache.pv.buf, true, {
			relative = "editor",
			title = "preview",
			title_pos = "center",
			width = width,
			height = height,
			col = col + width + 1,
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
			col = col,
			row = row,
			style = "minimal",
			focusable = false,
			border = "single",
		})
	api.nvim_set_option_value("filetype", M.ft, { buf = M.cache.sv.buf })
	api.nvim_set_option_value("cursorline", true, { win = M.cache.sv.win })

	M.set_keymaps()
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

	M.cache.pv.last_file = ""
end

M.buf_update = function()
	if root == nil then
		return
	end

	-- print(vim.inspect(root))
	buf_lines = {}
	M.buf_create_lines(root)
	-- print(vim.inspect(buf_lines))
	M.buf_open(M.opts.width_scale, M.opts.height_scale)

	M.buf_unlock(M.cache.sv.buf)
	api.nvim_buf_set_lines(M.cache.sv.buf, 0, -1, false, buf_lines)
	if buf_last_pos ~= nil then
		api.nvim_win_set_cursor(M.cache.sv.win, { buf_last_pos, 0 })
		buf_last_pos = nil
	end
	M.buf_lock(M.cache.sv.buf)

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
			if M.opts.tree_hl then
				hl.refresh(M.cache.sv.buf, root)
			end
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
			M.cache.pv.last_file = ""
			api.nvim_buf_set_lines(M.cache.pv.buf, 0, -1, false, {})
			return
		end
		if filename ~= M.cache.pv.last_file then
			local lines = M.cache.pv.files[filename] or M.read_lines_from_file(filename)
			-- cache files for reuse
			M.cache.pv.files[filename] = lines
			M.cache.pv.last_file = filename

			api.nvim_buf_set_lines(M.cache.pv.buf, 0, -1, false, lines)
		end
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
		local file_loc = vim.split(line_split[3], "::")
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
			"%s%s%s [%s::%s]",
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
	utils.open_file(pfilename, plnum)
end

-- :CsStackView toggle
-- :CsStackView open down|up symbol

M.run_cmd = function(args)
	local cmd = args[1]

	if vim.startswith(cmd, "o") then
		local stk_dir = args[2]
		local symbol = args[3] or cs.default_sym("s")
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

M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	-- Some sanity checks (make sure scales are between 0 to 1)
	if M.opts.width_scale <= 0 or M.opts.width_scale > 1 then
		M.opts.width_scale = def_width_scale
	end
	if M.opts.height_scale <= 0 or M.opts.height_scale > 1 then
		M.opts.height_scale = def_height_scale
	end
	M.set_user_cmd()
end

return M
