local RC = require("utils.ret_codes")
local log = require("utils.log")

local M = {}

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
local project_root = nil

local cscope_help = function()
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
build: Build cscope database          (Usage: build)
help : Show this message              (Usage: help)
]])
end

local cscope_push_tagstack = function()
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

local cscope_parse_line = function(line)
	local t = {}

	-- Populate t with filename, context and linenumber
	local sp = vim.split(line, "%s+")

	t.filename = sp[1]
	-- update path if project_rooter is enabled
	if M.opts.project_rooter.enable and not M.opts.project_rooter.change_cwd and project_root ~= nil then
		t.filename = project_root .. "/" .. t.filename
	end

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

local cscope_parse_output = function(cs_out)
	-- Parse cscope output to be populated in QuickFix List
	-- setqflist() takes list of dicts to be shown in QF List. See :h setqflist()

	local res = {}

	for line in string.gmatch(cs_out, "([^\n]+)") do
		local parsed_line = cscope_parse_line(line)
		table.insert(res, parsed_line)
	end

	return res
end

local cscope_find_helper = function(op_n, op_s, symbol, hide_log)
	-- Executes cscope search and shows result in QuickFix List or Telescope

	local db_file = vim.g.cscope_maps_db_file or M.opts.db_file
	local cmd = M.opts.exec

	if cmd == "cscope" then
		cmd = cmd .. " " .. "-f " .. db_file
	elseif cmd == "gtags-cscope" then
		if op_s == "d" then
			log.warn("'d' operation is not available for " .. M.opts.exec, hide_log)
			return RC.INVALID_OP
		end
		db_file = "GTAGS" -- This is only used to verify whether db is created or not.
	else
		log.warn("'" .. cmd .. "' executable is not supported", hide_log)
		return RC.INVALID_EXEC
	end

	if vim.loop.fs_stat(db_file) == nil then
		log.warn("db file not found [" .. db_file .. "]. Create using :Cs build", hide_log)
		return RC.DB_NOT_FOUND
	end

	cmd = cmd .. " -dL" .. " -" .. op_n .. " " .. symbol

	local file = assert(io.popen(cmd, "r"))
	file:flush()
	local output = file:read("*all")
	file:close()

	if output == "" then
		log.warn("no results for 'cscope find " .. op_s .. " " .. symbol .. "'", hide_log)
		return RC.NO_RESULTS
	end

	local parsed_output = cscope_parse_output(output)
	local title = "cscope find " .. op_s .. " " .. symbol

	-- Push current symbol on tagstack
	cscope_push_tagstack()

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

local cscope_find = function(op, symbol)
	if symbol == nil then
		return RC.INVALID_SYMBOL
	end

	op = tostring(op)
	if #op ~= 1 then
		log.warn("operation '" .. op .. "' is invalid")
		return RC.INVALID_OP
	end

	if string.find("012346789", op) then
		return cscope_find_helper(op, M.op_n_s[op], symbol)
	elseif string.find("sgdctefia", op) then
		return cscope_find_helper(M.op_s_n[op], op, symbol)
	else
		log.warn("operation '" .. op .. "' is invalid")
		return RC.INVALID_OP
	end
end

local cscope_cstag = function(symbol)
	if symbol == nil then
		return RC.INVALID_SYMBOL
	end

	local op = "g"
	if cscope_find_helper(M.op_s_n[op], op, symbol, true) ~= RC.SUCCESS then
		-- log.info("trying tags...")
		if not pcall(vim.cmd.tag, symbol) then
			log.warn("Vim(tag):E426: tag not found: " .. symbol)
			return RC.NO_RESULTS
		end
	end
	return RC.SUCCESS
end

local function cscope_build_output(err, data)
	if err then
		print("cscope: [build] err: " .. err)
	end
	if data then
		print("cscope: [build] out: " .. data)
	end
end

local cscope_build = function()
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)
	local db_build_cmd_args = vim.tbl_deep_extend("force", M.opts.db_build_cmd_args, {})
	local cur_path = vim.fn.expand("%:p:h", true)

	if vim.g.cscope_maps_statusline_indicator then
		log.warn("db build is already in progress")
		return
	end

	if M.opts.exec == "cscope" then
		table.insert(db_build_cmd_args, "-f")
		table.insert(db_build_cmd_args, M.opts.db_file)
	end

	if M.opts.project_rooter.enable and not M.opts.project_rooter.change_cwd and project_root ~= nil then
		vim.cmd("cd " .. project_root)
	end

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
			if M.opts.project_rooter.enable and not M.opts.project_rooter.change_cwd and project_root ~= nil then
				vim.cmd("cd " .. cur_path)
			end
		end)
	)
	vim.loop.read_start(stdout, cscope_build_output)
	vim.loop.read_start(stderr, cscope_build_output)
end

local cscope = function(args)
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

		cscope_find(op, symbol)
	elseif cmd:sub(1, 1) == "b" then
		cscope_build()
	elseif cmd:sub(1, 1) == "h" then
		cscope_help()
	else
		log.warn("command '" .. cmd .. "' is invalid")
	end
end

local cscope_cmd_comp = function(_, line)
	local cmds = { "find", "build", "help" }
	local l = vim.split(line, "%s+")
	local n = #l - 2

	if n == 0 then
		return vim.tbl_filter(function(val)
			return vim.startswith(val, l[2])
		end, cmds)
	end

	if n == 1 and l[2] == "find" then
		return vim.tbl_keys(M.op_s_n)
	end
end

local cscope_user_command = function()
	-- Create the :Cscope user command
	vim.api.nvim_create_user_command("Cscope", function(opts)
		cscope(opts.fargs)
	end, {
		nargs = "*",
		complete = cscope_cmd_comp,
	})

	-- Create the :Cs user command
	vim.api.nvim_create_user_command("Cs", function(opts)
		cscope(opts.fargs)
	end, {
		nargs = "*",
		complete = cscope_cmd_comp,
	})

	-- Create the :Cstag user command
	vim.api.nvim_create_user_command("Cstag", function(opts)
		cscope_cstag(unpack(opts.fargs))
	end, {
		nargs = "*",
	})
end

local cscope_project_root = function()
	local path = vim.fn.expand("%:p:h", true)
	while true do
		if path == "" then
			path = "/"
		end
		if vim.loop.fs_stat(path .. "/" .. M.opts.db_file) ~= nil then
			return path
		end
		if path == "/" then
			return nil
		end
		if vim.fn.has("win32") and path:len() <= 2 then
			return nil
		end
		path = path:match("^(.*)[/\\]")
	end
end

M.init_inbuilt_cscope = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)

	-- use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
	vim.opt.cscopetag = true
	-- check cscope for definition of a symbol before checking ctags: set to 1
	-- if you want the reverse search order.
	vim.opt.csto = 0
	-- show msg when cscope db added
	vim.opt.cscopeverbose = true
	-- results in quickfix window
	vim.opt.cscopequickfix = "s-,g-,c-,t-,e-,f-,i-,d-,a-"
	-- add cscope database in current directory
	vim.api.nvim_command("cs add " .. M.opts.db_file)
end

M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	-- This variable can be used by other plugins to change db_file
	-- e.g. vim-gutentags can use it for when
	--	vim.g.gutentags_cache_dir is enabled.
	vim.g.cscope_maps_db_file = nil
	vim.g.cscope_maps_statusline_indicator = nil

	if M.opts.project_rooter.enable then
		project_root = cscope_project_root()
		if project_root ~= nil then
			M.opts.db_file = project_root .. "/" .. M.opts.db_file
			if M.opts.project_rooter.change_cwd then
				vim.cmd("cd " .. project_root)
			end
		end
	end

	cscope_picker = require("cscope.pickers." .. M.opts.picker)

	cscope_user_command()
end

return M
