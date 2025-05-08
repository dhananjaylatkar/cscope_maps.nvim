local RC = require("cscope_maps.utils.ret_codes")
local log = require("cscope_maps.utils.log")
local helper = require("cscope_maps.utils.helper")
local utils = require("cscope_maps.utils")
local db = require("cscope.db")

local M = {}

---@class CsProjectRooterConfig
---@field enable? boolean
---@field change_cwd? boolean

---@class CsPicketOpts
---@field window_size? integer
---@field window_pos? string

---@class CsConfig
---@field db_file? string|[string]
---@field exec? string
---@field picker? string
---@field skip_picker_for_single_result? boolean
---@field db_build_cmd? table
---@field statusline_indicator? string|nil
---@field project_rooter? CsProjectRooterConfig
M.opts = {
	db_file = "./cscope.out",
	exec = "cscope",
	picker = "quickfix",
	picker_opts = {
		window_size = 5,
		window_pos = "bottom",
	},
	skip_picker_for_single_result = false,
	db_build_cmd = { script = "default", args = { "-bqkv" } },
	statusline_indicator = nil,
	project_rooter = {
		enable = false,
		change_cwd = false,
	},
}

M.user_opts = {}

-- operation symbol to number map
M.op_s_n = {
	s = "0",
	g = "1",
	d = "2",
	c = "3",
	t = "4",
	e = "6",
	f = "7",
	i = "8",
	a = "9",
}

-- operation number to symbol map
M.op_n_s = {}
for k, v in pairs(M.op_s_n) do
	M.op_n_s[v] = k
end

local cscope_picker = nil
local gtags_db = "GTAGS"

M.help = function()
	print([[
Cscope commands:
find : Query for a pattern            (Usage: find a|c|d|e|f|g|i|s|t name)
       a: Find assignments to this symbol
       c: Find functions calling this function
       d: Find functions called by this function
       e: Find this egrep pattern
       f: Find this file
       g: Find this definition
       i: Find files #including this file
       s: Find this C symbol
       t: Find this text string

db   : DB related queries             (Usage: db build|add <files>|rm <files>|show)
       build : Build cscope database
       add   : Add db file(s)
       rm    : Remove db file(s)
       show  : Show current db file(s)

reload: Reload plugin config
help : Show this message              (Usage: help)
]])
end

M.push_tagstack = function()
	local from = { vim.fn.bufnr("%"), vim.fn.line("."), vim.fn.col("."), 0 }
	local items = { { tagname = vim.fn.expand("<cword>"), from = from } }
	local ts = vim.fn.gettagstack()
	local ts_last_item = ts.items[ts.curidx - 1]

	if
		ts_last_item
		and ts_last_item.tagname == items[1].tagname
		and ts_last_item.from[1] == items[1].from[1]
		and ts_last_item.from[2] == items[1].from[2]
	then
		-- Don't push duplicates on tagstack
		return
	end

	vim.fn.settagstack(vim.fn.win_getid(), { items = items }, "t")
end

M.parse_line = function(line, db_pre_path)
	local t = {}

	-- Populate t with filename, context and linenumber
	local sp = vim.split(line, "%s+")

	t.filename = sp[1]
	-- prepend db_pre_path when both of following are true -
	-- 1. relative path is used for filename
	-- 2. db_pre_path is not present in filename
	if db_pre_path and not utils.is_path_abs(t.filename) and not vim.startswith(t.filename, db_pre_path) then
		t.filename = vim.fs.joinpath(db_pre_path, t.filename)
	end
	t.filename = utils.get_rel_path(vim.fn.getcwd(), t.filename)

	t.ctx = sp[2]
	t.lnum = sp[3]
	local sz = #sp[1] + #sp[2] + #sp[3] + 3

	-- Populate t["text"] with search result
	t.text = string.sub(line, sz, -1)

	-- Enclose context with << >>
	if string.sub(t.ctx, 1, 1) == "<" then
		t.ctx = "<" .. t.ctx .. ">"
	else
		t.ctx = "<<" .. t.ctx .. ">>"
	end

	-- Add context to text
	t.text = t.ctx .. t.text

	return t
end

M.parse_output = function(cs_out, db_pre_path)
	-- Parse cscope output to be populated in QuickFix List
	-- setqflist() takes list of dicts to be shown in QF List. See :h setqflist()

	local res = {}

	for line in string.gmatch(cs_out, "([^\n]+)") do
		local parsed_line = M.parse_line(line, db_pre_path)
		table.insert(res, parsed_line)
	end

	return res
end

M.open_picker = function(op_s, symbol, parsed_output)
	local title = "cscope find " .. op_s .. " " .. symbol

	-- Push current symbol on tagstack
	M.push_tagstack()

	-- update jumplist
	vim.cmd([[normal! m']])

	if M.opts.skip_picker_for_single_result and #parsed_output == 1 then
		utils.open_file(parsed_output[1]["filename"], tonumber(parsed_output[1]["lnum"], 10))
		return RC.SUCCESS
	end

	local picker_opts = {}
	picker_opts.cscope = {}
	picker_opts.cscope.parsed_output = parsed_output
	picker_opts.cscope.prompt_title = title
	picker_opts.cscope.picker_opts = M.opts.picker_opts
	-- backward compatibility for qf_window_pos and qf_window_size
	picker_opts.cscope.qf_window_size = M.opts.qf_window_size
	picker_opts.cscope.qf_window_pos = M.opts.qf_window_pos

	cscope_picker.run(picker_opts)
	return RC.SUCCESS
end

M.cmd_exec = function(cmd)
	local file = assert(io.popen(cmd, "r"))
	file:flush()
	local output = file:read("*all")
	file:close()
	return output
end

M.get_result = function(op_n, op_s, symbol, hide_log)
	-- Executes cscope search and return parsed output

	local db_conns = db.all_conns()
	local cmd = string.format("%s -dL -%s %s", M.opts.exec, op_n, symbol)
	local out = ""
	local res = {}

	local exec_and_update_res = function(_db_con, _cmd_args)
		if vim.loop.fs_stat(_db_con.file) == nil then
			return
		end

		local _cmd = string.format("%s -f %s -P %s %s", cmd, _db_con.file, _db_con.pre_path, _cmd_args)
		out = M.cmd_exec(_cmd)
		res = vim.list_extend(res, M.parse_output(out, _db_con.pre_path))
	end

	if M.opts.exec == "cscope" then
		for _, db_con in ipairs(db_conns) do
			exec_and_update_res(db_con, "")
		end
	elseif M.opts.exec == "gtags-cscope" then
		if op_s == "d" then
			log.warn("'d' operation is not available for " .. M.opts.exec, hide_log)
			return RC.INVALID_OP, nil
		end
		exec_and_update_res(db.primary_conn(), "-a")
	else
		log.warn("'" .. M.opts.exec .. "' executable is not supported", hide_log)
		return RC.INVALID_EXEC, nil
	end

	if vim.tbl_isempty(res) then
		log.warn("no results for 'cscope find " .. op_s .. " " .. symbol .. "'", hide_log)
		return RC.NO_RESULTS, nil
	end

	return RC.SUCCESS, res
end

M.find = function(op, symbol)
	if symbol == nil then
		return RC.INVALID_SYMBOL
	end

	local ok, res
	op = tostring(op)

	if #op ~= 1 then
		log.warn("operation '" .. op .. "' is invalid")
		return RC.INVALID_OP
	end

	if string.find("012346789", op) then
		ok, res = M.get_result(op, M.op_n_s[op], symbol)
	elseif string.find("sgdctefia", op) then
		ok, res = M.get_result(M.op_s_n[op], op, symbol)
	else
		log.warn("operation '" .. op .. "' is invalid")
		return RC.INVALID_OP
	end

	if ok == RC.SUCCESS then
		return M.open_picker(op, symbol, res)
	end

	return RC.NO_RESULTS
end

-- get lnum and text of tag
-- returns list of all occurrences of tag
M.tag_get_info = function(tag)
	local res = {}
	local bin = ""
	if vim.fn.executable("rg") then
		bin = "rg"
	elseif vim.fn.executable("grep") then
		bin = "grep"
	end

	if bin == "" then
		return {}
	end

	-- remove leading and trailing "/" because "cmd" is Ex cmd for vim
	local filter = string.gsub(tag.cmd, "^/", "")
	filter = string.gsub(filter, "/$", "")

	-- escape shell chars
	filter = filter:gsub("[\\~?*|{\\[()%-%.%+]", function(x)
		return "\\" .. x
	end)

	local proc = vim.system({ bin, "-n", filter, tag.filename }, { text = true }):wait()

	if proc.code ~= 0 then
		return {}
	end

	local lines = vim.split(proc.stdout, "\n")
	for _, line in ipairs(lines) do
		local sp = vim.split(line, ":")
		if #sp == 2 then
			table.insert(res, { lnum = sp[1], text = sp[2] })
		end
	end

	return res
end

-- parse taglist for give sym
-- returns same format as cscope parse_output
M.get_tags = function(sym)
	-- don't use custom picker for help tags
	if vim.bo.filetype == "help" then
		return {}
	end

	local tags = vim.fn.taglist(string.format("^%s$", sym))
	local res = {}

	for _, tag in ipairs(tags) do
		local info = M.tag_get_info(tag)
		for _, info_item in ipairs(info) do
			local item = {}
			item.filename = tag.filename
			item.ctx = string.format("<<%s>>", tag.name)
			item.lnum = info_item.lnum
			item.text = string.format("%s %s", item.ctx, info_item.text)
			table.insert(res, item)
		end
	end
	return res
end

M.cstag = function(symbol)
	local op = "g"
	-- if symbol is not provided use cword
	symbol = symbol or M.default_sym(op)

	local ok, res = M.get_result(M.op_s_n[op], op, symbol, true)
	if ok == RC.SUCCESS then
		return M.open_picker(op, symbol, res)
	end

	res = M.get_tags(symbol)
	if #res ~= 0 then
		return M.open_picker("tags", symbol, res)
	end

	if not pcall(vim.cmd.tjump, symbol) then
		log.warn("Vim(tag):E426: tag not found: " .. symbol)
		return RC.NO_RESULTS
	end
	return RC.NO_RESULTS
end

M.default_sym = function(op)
	local sym = ""
	if vim.fn.mode() == "v" then
		local saved_reg = vim.fn.getreg("v")
		vim.cmd([[noautocmd sil norm! "vy]])
		sym = vim.fn.getreg("v")
		vim.fn.setreg("v", saved_reg)
	else
		local arg = "<cword>"
		if vim.tbl_contains({ "f", "i", "7", "8" }, op) then
			arg = "<cfile>"
		end
		sym = vim.fn.expand(arg)
	end
	return sym
end

M.run = function(args)
	-- Parse top level input and call appropriate functions
	local args_num = #args
	if args_num < 1 then
		-- invalid command
		log.warn("invalid cmd. see :Cscope help")
		return
	end

	local cmd = args[1]

	if cmd:sub(1, 1) == "f" then
		local op = args[2]
		-- if symbol is not provided use cword or cfile
		local symbol = args[3] or M.default_sym(op)

		-- collect all args
		for i = 4, args_num do
			symbol = symbol .. " " .. args[i]
		end

		-- escape commonly used special chars
		symbol = symbol:gsub("([%s\"%'%(%)><])", {
			[" "] = "\\ ",
			['"'] = '\\"',
			["'"] = "\\'",
			["("] = "\\(",
			[")"] = "\\)",
			[">"] = "\\>",
			["<"] = "\\<",
		})

		M.find(op, symbol)
	elseif cmd:sub(1, 1) == "b" then
		log.warn("':Cs build' is deprecated. Use ':Cs db build'")
	elseif cmd:sub(1, 1) == "d" then
		if args_num < 2 then
			log.warn("db command expects atleast 2 arguments")
			return
		end

		local op = args[2]:sub(1, 1)
		if op == "b" then
			db.build(M.opts)
		elseif op == "a" or op == "r" then
			-- collect all args
			local files = {}
			for i = 3, args_num do
				table.insert(files, args[i])
			end

			db.update(op, files)
		elseif op == "s" then
			db.print_conns()
		else
			log.warn("invalid operation")
		end
	elseif cmd:sub(1, 1) == "h" then
		M.help()
	elseif cmd:sub(1, 1) == "r" then
		M.reload()
	else
		log.warn("command '" .. cmd .. "' is invalid")
	end
end

M.cmd_cmp = function(_, line)
	local cmds = { "find", "db", "reload", "help" }
	local l = vim.split(line, "%s+")
	local n = #l - 2

	if n == 0 then
		return vim.tbl_filter(function(val)
			return vim.startswith(val, l[2])
		end, cmds)
	end

	local short_cmd = l[2]:sub(1, 1)
	if n == 1 then
		if short_cmd == "f" then
			return vim.tbl_keys(M.op_s_n)
		end

		if short_cmd == "d" then
			cmds = { "build", "add", "rm", "show" }
			return vim.tbl_filter(function(val)
				return vim.startswith(val, l[3])
			end, cmds)
		end
	end

	local short_cmd2 = l[3]:sub(1, 1)
	local cur_arg = l[#l]

	if n == 2 and short_cmd == "f" then
		-- complete default_sym for "find" cmd
		local default_sym = M.default_sym(short_cmd2)
		if cur_arg == "" or vim.startswith(default_sym, cur_arg) then
			return { default_sym }
		end
	end

	if n >= 2 and short_cmd == "d" and short_cmd2 == "a" then
		local sp = vim.split(cur_arg, db.sep)
		local parent, fs_entries

		if sp[2] ~= nil then
			-- complete pre path.
			-- this will show "@" and dirs only
			parent = utils.get_path_parent(sp[2])
			fs_entries = utils.get_dirs_in_dir(parent)
			table.insert(fs_entries, 1, "@")

			fs_entries = vim.tbl_map(function(x)
				return sp[1] .. db.sep .. x
			end, fs_entries)
		else
			-- complete db path
			-- this will show all files
			parent = utils.get_path_parent(cur_arg)
			fs_entries = utils.get_files_in_dir(parent)
		end

		return vim.tbl_filter(function(val)
			return vim.startswith(val, cur_arg)
		end, fs_entries)
	end

	if n >= 2 and short_cmd == "d" and short_cmd2 == "r" then
		-- complete db_conns except primary_conn
		local db_conns = db.all_conns()
		local entries = {}
		if not db_conns then
			return entries
		end

		for i, conn in ipairs(db_conns) do
			if i > 1 then
				table.insert(entries, string.format("%s%s%s", conn.file, db.sep, conn.pre_path))
			end
		end

		return vim.tbl_filter(function(val)
			return vim.startswith(val, cur_arg)
		end, entries)
	end
end

M.user_command = function()
	-- Create the :Cscope user command
	vim.api.nvim_create_user_command("Cscope", function(opts)
		M.run(opts.fargs)
	end, {
		nargs = "*",
		complete = M.cmd_cmp,
	})

	-- Create the :Cs user command
	vim.api.nvim_create_user_command("Cs", function(opts)
		M.run(opts.fargs)
	end, {
		nargs = "*",
		complete = M.cmd_cmp,
	})

	-- Create the :Cstag user command
	vim.api.nvim_create_user_command("Cstag", function(opts)
		M.cstag(unpack(opts.fargs))
	end, {
		nargs = "*",
	})
end

M.reload = function()
	db.reset()
	M.setup(M.user_opts)
end

M.root = function(source, marker)
	if vim.fn.filereadable(vim.fs.joinpath(source, marker)) == 1 then
		return source
	end

	for dir in vim.fs.parents(source) do
		if vim.fn.filereadable(vim.fs.joinpath(dir, marker)) == 1 then
			return dir
		end
	end
	return nil
end

---Initialization api
---@param opts CsConfig
M.setup = function(opts)
	-- save original opts for reload operation
	M.user_opts = vim.deepcopy(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	-- This variable can be used by other plugins to change db_file
	-- e.g. vim-gutentags can use it for when
	--	vim.g.gutentags_cache_dir is enabled.
	vim.g.cscope_maps_db_file = nil
	vim.g.cscope_maps_statusline_indicator = nil

	if M.opts.exec == "gtags-cscope" then
		M.opts.db_file = gtags_db
	end

	if type(M.opts.db_file) == "string" then
		db.add(M.opts.db_file)
	else -- table
		for _, f in ipairs(M.opts.db_file) do
			db.add(f)
		end
	end

	if M.opts.db_build_cmd.script ~= "default" and vim.fn.executable(M.opts.db_build_cmd.script) ~= 1 then
		log.warn(string.format("db_build script(%s) not found. Using default", M.opts.db_build_cmd.script))
		M.opts.db_build_cmd = { script = "default", args = { "-bqkv" } }
	end

	if M.opts.db_build_cmd_args then
		M.opts.db_build_cmd.args = M.opts.db_build_cmd_args
		log.warn(
			string.format(
				[[db_build_cmd_args is deprecated. Use 'db_build_cmd = { args = %s }']],
				vim.inspect(M.opts.db_build_cmd_args)
			)
		)
	end

	-- if project rooter is enabled,
	-- 1. get root of project and update primary conn
	-- 2. if change_cwd is enabled, change into it (?)
	if M.opts.project_rooter.enable then
		local primary_conn = db.primary_conn()
		local root = M.root(vim.fn.getcwd(), primary_conn.file)
		if root then
			db.update_primary_conn(vim.fs.joinpath(root, primary_conn.file), root)

			if M.opts.project_rooter.change_cwd then
				vim.cmd("cd " .. root)
			end
		end
	end

	cscope_picker = require("cscope.pickers." .. M.opts.picker)
	M.user_command()
end

return M
