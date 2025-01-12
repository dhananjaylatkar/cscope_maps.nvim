local utils = require("cscope_maps.utils")
local log = require("cscope_maps.utils.log")

local M = {}

--- conns = { {file = db_file, pre_path = db_pre_path}, ... }
M.conns = {}
M.global_conn = nil

M.sep = "::"

M.reset = function()
	M.conns = {}
	M.global_conn = nil
end

---Get all db connections
---If global connection is declared then use that
---@return table
M.all_conns = function()
	M.update_global_conn()
	return M.global_conn or M.conns
end

---Get primary db connection
---If global connection is declared then use that
---@return table
M.primary_conn = function()
	M.update_global_conn()
	if M.global_conn then
		return M.global_conn[1]
	end
	return M.conns[1]
end

---Update primary db connection
---@param file string
---@param pre_path string
M.update_primary_conn = function(file, pre_path)
	M.conns[1].file = vim.fs.normalize(file)
	M.conns[1].pre_path = vim.fs.normalize(pre_path)
end

---Update global db connection
M.update_global_conn = function()
	if vim.g.cscope_maps_db_file then
		local file, pre_path = M.sp_file_pre_path(vim.g.cscope_maps_db_file)
		M.global_conn = { { file = file, pre_path = pre_path } }
	else
		M.global_conn = nil
	end
end

---Split input of ":Cs db add" into file and pre_path and normalize them
---@param path string
---@return string
---@return string|nil
M.sp_file_pre_path = function(path)
	local sp = vim.split(path, M.sep)
	local file = sp[1]
	local pre_path = sp[2]

	file = vim.fs.normalize(file)

	-- use cwd if pre_path is not provided
	if pre_path == nil or pre_path == "" then
		pre_path = vim.fn.getcwd()
	end

	-- use parent as pre_path if its "@"
	if pre_path == "@" then
		pre_path = utils.get_path_parent(file)
	end

	-- normalize it
	pre_path = vim.fs.normalize(pre_path)

	return file, pre_path
end

---Find index of db in all connections
---@param file string
---@param pre_path string|nil
---@return integer
M.find = function(file, pre_path)
	for i, cons in ipairs(M.conns) do
		if
			utils.is_path_same(cons.file, file)
			and (utils.is_path_same(cons.pre_path, pre_path) or cons.pre_path == nil)
		then
			return i
		end
	end

	return -1
end

---Add db in db connections
---@param path string
M.add = function(path)
	local file, pre_path = M.sp_file_pre_path(path)
	if M.find(file, pre_path) == -1 then
		table.insert(M.conns, { file = file, pre_path = pre_path })
	end
end

---Remove db from db connections
---Primary db connection will not be removed
---@param path string
M.remove = function(path)
	local file, pre_path = M.sp_file_pre_path(path)
	local loc = M.find(file, pre_path)
	-- do not remove first entry
	if loc > 1 then
		table.remove(M.conns, loc)
	end
end

---Update DB connections
---@param op string Operation (add/remove)
---@param files table list of files
M.update = function(op, files)
	if op == "a" then
		for _, f in ipairs(files) do
			M.add(f)
		end
	elseif op == "r" then
		for _, f in ipairs(files) do
			M.remove(f)
		end
	end
end

M.print_conns = function()
	if not M.conns then
		log.warn("No connections")
	end

	for i, conn in ipairs(M.conns) do
		local file = utils.get_rel_path(vim.fn.getcwd(), conn.file)
		local pre_path = utils.get_rel_path(vim.fn.getcwd(), conn.pre_path)
		if not pre_path or pre_path == "" then
			log.warn(string.format("%d) db=%s", i, file))
		else
			log.warn(string.format("%d) db=%s pre_path=%s", i, file, pre_path))
		end
	end
end

---Create command to build DB
---1. If script is default then use opt.exec
---2. If custom script is provided then use that with "-d <db>::<pre_path>" args
M.get_build_cmd = function(opts)
	local cmd = {}

	if opts.db_build_cmd.script == "default" then
		if opts.exec == "cscope" then
			cmd = { "cscope", "-f", M.primary_conn().file }
		else -- "gtags-cscope"
			cmd = { "gtags-cscope" }
		end

		vim.list_extend(cmd, opts.db_build_cmd.args)
		return cmd
	end

	-- custom script
	cmd = { opts.db_build_cmd.script }
	vim.list_extend(cmd, opts.db_build_cmd.args)

	for _, conn in ipairs(M.conns) do
		vim.list_extend(cmd, { "-d", string.format("%s::%s", conn.file, conn.pre_path) })
	end

	return cmd
end

local on_exit = function(obj)
	vim.g.cscope_maps_statusline_indicator = nil
	if obj.code == 0 then
		-- print("cscope: [build] out: " .. obj.stdout)
		print("cscope: database built successfully")
	else
		-- print("cscope: [build] out: " .. obj.stderr)
		print("cscope: database build failed")
	end
end

M.build = function(opts)
	if vim.g.cscope_maps_statusline_indicator then
		log.warn("db build is already in progress")
		return
	end

	local cmd = M.get_build_cmd(opts)

	vim.g.cscope_maps_statusline_indicator = opts.statusline_indicator or opts.exec
	vim.system(cmd, { text = true }, on_exit)
end

return M
