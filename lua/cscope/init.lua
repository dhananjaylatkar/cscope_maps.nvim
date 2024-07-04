local RC = require("cscope_maps.utils.ret_codes")
local log = require("cscope_maps.utils.log")
local helper = require("cscope_maps.utils.helper")
local utils = require("cscope_maps.utils")
local db = require("cscope.db")

local M = {}

---@class CsProjectRooterConfig
---@field enable? boolean
---@field change_cwd? boolean

---@class CsConfig
---@field db_file? string|[string]
---@field exec? string
---@field picker? string
---@field qf_window_size? integer
---@field qf_window_pos? string
---@field skip_picker_for_single_result? boolean
---@field db_build_cmd_args? table
---@field statusline_indicator? string|nil
---@field project_rooter? CsProjectRooterConfig
M.opts = {
	db_file = "./cscope.out",
	exec = "cscope",
	picker = "quickfix",
	qf_window_size = 5,
	qf_window_pos = "bottom",
	skip_picker_for_single_result = false,
	db_build_cmd_args = { "-bqkv" },
	statusline_indicator = nil,
	project_rooter = {
		enable = false,
		change_cwd = false,
	},
}

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

M.parse_line = function(line, db_rel)
	local t = {}

	-- Populate t with filename, context and linenumber
	local sp = vim.split(line, "%s+")

	t.filename = sp[1]
	if db_rel then
		t.filename = vim.fs.joinpath(db_rel, t.filename)
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

M.parse_output = function(cs_out, db_rel)
	-- Parse cscope output to be populated in QuickFix List
	-- setqflist() takes list of dicts to be shown in QF List. See :h setqflist()

	local res = {}

	for line in string.gmatch(cs_out, "([^\n]+)") do
		local parsed_line = M.parse_line(line, db_rel)
		table.insert(res, parsed_line)
	end

	return res
end

M.open_picker = function(op_s, symbol, parsed_output)
	local title = "cscope find " .. op_s .. " " .. symbol

	-- Push current symbol on tagstack
	M.push_tagstack()

	if M.opts.skip_picker_for_single_result and #parsed_output == 1 then
		vim.api.nvim_command("edit +" .. parsed_output[1]["lnum"] .. " " .. parsed_output[1]["filename"])
		return RC.SUCCESS
	end

	local picker_opts = {}
	picker_opts.cscope = {}
	picker_opts.cscope.parsed_output = parsed_output
	picker_opts.cscope.prompt_title = title
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
	local any_res = false
	local res = {}

	if M.opts.exec == "cscope" then
		for _, db_con in ipairs(db_conns) do
			local db_file, db_rel = db_con.file, db_con.rel
			if vim.loop.fs_stat(db_file) ~= nil then
				local _cmd = string.format("%s -f %s", cmd, db_file)
				print(_cmd)
				out = M.cmd_exec(_cmd)
				if out ~= "" then
					any_res = true
					res = vim.tbl_deep_extend("keep", res, M.parse_output(out, db_rel))
				end
			end
		end
	elseif M.opts.exec == "gtags-cscope" then
		if vim.loop.fs_stat("GTAGS") == nil then
			log.warn("GTAGS file not found", hide_log)
			return RC.DB_NOT_FOUND, nil
		end
		if op_s == "d" then
			log.warn("'d' operation is not available for " .. M.opts.exec, hide_log)
			return RC.INVALID_OP, nil
		end

		out = M.cmd_exec(cmd)
	else
		log.warn("'" .. M.opts.exec .. "' executable is not supported", hide_log)
		return RC.INVALID_EXEC, nil
	end

	if any_res == false then
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

M.cstag = function(symbol)
	if symbol == nil then
		return RC.INVALID_SYMBOL
	end

	local op = "g"
	local ok, res = M.get_result(M.op_s_n[op], op, symbol, true)
	if ok == RC.SUCCESS then
		return M.open_picker(op, symbol, res)
	end
	-- log.info("trying tags...")
	if not pcall(vim.cmd.tjump, symbol) then
		log.warn("Vim(tag):E426: tag not found: " .. symbol)
		return RC.NO_RESULTS
	end
	return RC.NO_RESULTS
end

M.db_build_output = function(err, data)
	if err then
		print("cscope: [build] err: " .. err)
	end
	if data then
		print("cscope: [build] out: " .. data)
	end
end

M.db_build = function()
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)
	local db_build_cmd_args = vim.tbl_deep_extend("force", M.opts.db_build_cmd_args, {})
	local cur_path = vim.fn.getcwd()
	local db_conn = db.primary_conn() -- TODO: extend support to all db conns
	local db_file = db_conn.file
	local db_root = utils.get_path_parent(db_file)

	if vim.g.cscope_maps_statusline_indicator then
		log.warn("db build is already in progress")
		return
	end

	if M.opts.exec == "cscope" then
		table.insert(db_build_cmd_args, "-f")
		table.insert(db_build_cmd_args, db_file)
	end

	vim.cmd("cd " .. db_root)

	local handle = nil
	vim.g.cscope_maps_statusline_indicator = M.opts.statusline_indicator or M.opts.exec
	handle = vim.loop.spawn(
		M.opts.exec,
		{
			args = db_build_cmd_args,
			stdio = { nil, stdout, stderr },
		},
		vim.schedule_wrap(function(code, _) -- on exit
			stdout:read_stop()
			stderr:read_stop()
			stdout:close()
			stderr:close()
			handle:close()
			if code == 0 then
				log.info("database built successfully")
			else
				log.warn("database build failed")
			end
			vim.g.cscope_maps_statusline_indicator = nil
			vim.cmd("cd " .. cur_path)
		end)
	)
	vim.loop.read_start(stdout, M.db_build_output)
	vim.loop.read_start(stderr, M.db_build_output)
end

M.db_update = function(op, files)
	if op == "a" then
		for _, f in ipairs(files) do
			db.add(f)
		end
	elseif op == "r" then
		for _, f in ipairs(files) do
			db.remove(f)
		end
	end
	-- TODO: add proper print
	log.warn("updateed DB list: " .. vim.inspect(db.all_conns()))
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
		if args_num < 3 then
			log.warn("find command expects atleast 3 arguments")
			return
		end

		local op = args[2]
		local symbol = args[3]

		-- collect all args
		for i = 4, args_num do
			symbol = symbol .. " " .. args[i]
		end

		-- add escape chars for " ", '"' and "'"
		symbol = symbol:gsub(" ", "\\ "):gsub('"', '\\"'):gsub("'", "\\'")

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
			M.db_build()
		elseif op == "a" or op == "r" then
			-- collect all args
			local files = {}
			for i = 3, args_num do
				table.insert(files, args[i])
			end

			M.db_update(op, files)
		elseif op == "s" then
			-- TODO: use proper print
			log.warn("current DB list: " .. vim.inspect(db.all_conns()))
		else
			log.warn("invalid operation")
		end
	elseif cmd:sub(1, 1) == "h" then
		M.help()
	else
		log.warn("command '" .. cmd .. "' is invalid")
	end
end

M.cmd_cmp = function(_, line)
	local cmds = { "find", "db", "help" }
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
			return { "build", "add", "rm", "show" }
		end
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

---Initialization API for inbuilt cscope
---Used for neovim < 0.9
M.legacy_setup = function()
	-- use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
	vim.opt.cscopetag = true
	-- check cscope for definition of a symbol before checking ctags: set to 1
	-- if you want the reverse search order.
	vim.opt.csto = 0
	-- show msg when cscope db added
	vim.opt.cscopeverbose = true
	-- results in quickfix window
	vim.opt.cscopequickfix = "s-,g-,c-,t-,e-,f-,i-,d-,a-"

	if type(M.opts.db_file) == "table" then
		for _, db in ipairs(M.opts.db_file) do
			if vim.loop.fs_stat(db) ~= nil then
				vim.api.nvim_command("cs add " .. db)
			end
		end
	else -- string
		if vim.loop.fs_stat(M.opts.db_file) ~= nil then
			vim.api.nvim_command("cs add " .. M.opts.db_file)
		end
	end
end

---Initialization api
---@param opts CsConfig
M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	-- This variable can be used by other plugins to change db_file
	-- e.g. vim-gutentags can use it for when
	--	vim.g.gutentags_cache_dir is enabled.
	vim.g.cscope_maps_db_file = nil
	vim.g.cscope_maps_statusline_indicator = nil

	if type(M.opts.db_file) == "string" then
		db.add(M.opts.db_file)
	else -- table
		for _, f in ipairs(M.opts.db_file) do
			db.add(f)
		end
	end

	-- if project rooter is enabled,
	-- 1. get root of project and update primary conn
	-- 2. if change_cwd is enabled, change into it (?)
	if M.opts.project_rooter.enable then
		local primary_conn = db.primary_conn()
		local root = vim.fs.root(0, primary_conn.file)
		print("root" .. root)
		if root then
			db.update_primary_conn(vim.fs.joinpath(root, primary_conn.file), root)

			if M.opts.project_rooter.change_cwd then
				vim.cmd("cd " .. root)
			end
		end
	end

	if helper.legacy_cscope() then
		M.legacy_setup()
	else
		cscope_picker = require("cscope.pickers." .. M.opts.picker)
		M.user_command()
	end
end

return M
