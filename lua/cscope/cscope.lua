local M = {}

M.opts = { db_file = "./cscope.out" }

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
help : Show this message              (Usage: help)
]])
end

local cscope_parse_line = function(line)
	local t = {}

	-- Populate t with filename, context and linenumber
	local sp = vim.split(line, "%s+")
	t["filename"] = sp[1]
	t["ctx"] = sp[2]
	t["lnum"] = sp[3]
	local sz = #sp[1] + #sp[2] + #sp[3] + 3

	-- Populate t["text"] with search result
	t["text"] = string.sub(line, sz, -1)

	-- Enclose context with << >>
	if string.sub(t["ctx"], 1, 1) == "<" then
		t["ctx"] = "<" .. t["ctx"] .. ">"
	else
		t["ctx"] = "<<" .. t["ctx"] .. ">>"
	end

	-- Add context to text
	t["text"] = t["ctx"] .. t["text"]

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

local cscope_find_helper = function(op_n, op_s, symbol)
	-- Executes cscope command and shows result in QuickFix List

	local db_file = vim.g.cscope_maps_db_file or M.opts.db_file

	if io.open(db_file, "r") == nil then
		print("cscope: database file not found. [" .. db_file .. "]")
		return
	end
	local cmd = "cscope -dL -f " .. db_file .. " -" .. op_n .. " " .. symbol

	local file = assert(io.popen(cmd, "r"))
	file:flush()
	local output = file:read("*all")
	file:close()

	if output == "" then
		print("cscope: no results for 'cscope find " .. op_s .. " " .. symbol .. "'")
		return
	end

	local parsed_output = cscope_parse_output(output)

	vim.fn.setqflist(parsed_output, "r")
	vim.fn.setqflist({}, "a", { title = "cscope find " .. op_s .. " " .. symbol })
	vim.api.nvim_command("botright copen")
end

local cscope_find = function(op, symbol)
	op = tostring(op)
	if #op ~= 1 then
		print("cscope: operation '" .. op .. "' is invalid")
		return
	end
	if string.find("012346789", op) then
		cscope_find_helper(op, M.op_n_s[op], symbol)
	elseif string.find("sgdctefia", op) then
		cscope_find_helper(M.op_s_n[op], op, symbol)
	else
		print("cscope: operation '" .. op .. "' is invalid")
	end
end

M.cscope = function(cmd, op, symbol)
	-- Parse top level output and call appropriate functions
	if cmd == "find" then
		cscope_find(op, symbol)
	elseif cmd == "help" then
		cscope_help()
	else
		print("cscope: command '" .. cmd .. "' is invalid")
	end
end

local cscope_user_command = function()
	-- Create the user command
	vim.api.nvim_create_user_command("Cscope", function(opts)
		M.cscope(unpack(opts.fargs))
	end, {
		nargs = "*",
		complete = function(_, line)
			local cmds = { "find", "help" }
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
		end,
	})
end

M.setup = function(opts)
	M.opts = vim.tbl_extend("force", M.opts, opts)
	-- This variable can be used by other plugins to change db_file
	-- e.g. vim-gutentags can use it for when
	--	vim.g.gutentags_cache_dir is enabled.
	vim.g.cscope_maps_db_file = "./cscope.out"
	cscope_user_command()
end

return M
