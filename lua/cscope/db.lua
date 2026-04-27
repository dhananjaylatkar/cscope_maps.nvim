local utils = require("cscope_maps.utils")
local log = require("cscope_maps.utils.log")

local M = {}

--- conns = { {file = db_file, pre_path = db_pre_path}, ... }
M.conns = {}
M.gtags_conns = {}
M.global_conn = nil

M.sep = "::"

M.reset = function()
	M.conns = {}
	M.gtags_conns = {}
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

---Add gtags db connection
---@param path string
M.add_gtags = function(path)
	local file, pre_path = M.sp_file_pre_path(path)
	for _, conn in ipairs(M.gtags_conns) do
		if
			utils.is_path_same(conn.file, file)
			and (utils.is_path_same(conn.pre_path, pre_path) or conn.pre_path == nil)
		then
			return
		end
	end
	table.insert(M.gtags_conns, { file = file, pre_path = pre_path })
end

---Get primary gtags db connection
---@return table|nil
M.primary_gtags_conn = function()
	if #M.gtags_conns == 0 then
		return nil
	end
	return M.gtags_conns[1]
end

---Update primary gtags db connection
---@param file string
---@param pre_path string
M.update_primary_gtags_conn = function(file, pre_path)
	M.gtags_conns[1].file = vim.fs.normalize(file)
	M.gtags_conns[1].pre_path = vim.fs.normalize(pre_path)
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
	if #M.conns == 0 and #M.gtags_conns == 0 then
		log.warn("No connections")
		return
	end

	for i, conn in ipairs(M.conns) do
		local file = utils.get_rel_path(vim.fn.getcwd(), conn.file)
		local pre_path = utils.get_rel_path(vim.fn.getcwd(), conn.pre_path)
		if not pre_path or pre_path == "" then
			log.warn(string.format("%d) [cscope] db=%s", i, file))
		else
			log.warn(string.format("%d) [cscope] db=%s pre_path=%s", i, file, pre_path))
		end
	end

	for i, conn in ipairs(M.gtags_conns) do
		local file = utils.get_rel_path(vim.fn.getcwd(), conn.file)
		local pre_path = utils.get_rel_path(vim.fn.getcwd(), conn.pre_path)
		if not pre_path or pre_path == "" then
			log.warn(string.format("%d) [gtags] db=%s", i, file))
		else
			log.warn(string.format("%d) [gtags] db=%s pre_path=%s", i, file, pre_path))
		end
	end
end

---Create commands to build DB for all exec types
---1. If script is default then build for each exec type
---2. If custom script is provided then use that with "-d <db>::<pre_path>" args
---@param opts table
---@param exec_list string[]
---@return table[]
M.get_build_cmds = function(opts, exec_list)
	local cmds = {}

	if opts.db_build_cmd.script == "default" then
		for _, exec in ipairs(exec_list) do
			local cmd = {}
			if exec == "cscope" then
				local pc = M.primary_conn()
				if pc then
					cmd = { "cscope", "-f", pc.file }
					vim.list_extend(cmd, opts.db_build_cmd.args)
					table.insert(cmds, cmd)
				end
			elseif exec == "gtags-cscope" then
				cmd = { "gtags-cscope" }
				vim.list_extend(cmd, opts.db_build_cmd.args)
				table.insert(cmds, cmd)
			end
		end
		return cmds
	end

	-- custom script
	local cmd = { opts.db_build_cmd.script }
	vim.list_extend(cmd, opts.db_build_cmd.args)

	for _, conn in ipairs(M.conns) do
		vim.list_extend(cmd, { "-d", string.format("%s::%s", conn.file, conn.pre_path) })
	end

	table.insert(cmds, cmd)
	return cmds
end

M.build = function(opts, exec_list)
	if vim.g.cscope_maps_statusline_indicator then
		log.warn("db build is already in progress")
		return
	end

	local cmds = M.get_build_cmds(opts, exec_list)
	if #cmds == 0 then
		log.warn("no build commands to run")
		return
	end

	local total = #cmds
	local completed = 0
	local failed = false

	vim.g.cscope_maps_statusline_indicator = opts.statusline_indicator or table.concat(exec_list, "+")

	for _, cmd in ipairs(cmds) do
		vim.system(cmd, { text = true }, function(obj)
			completed = completed + 1
			if obj.code ~= 0 then
				failed = true
			end
			if completed == total then
				vim.g.cscope_maps_statusline_indicator = nil
				if failed then
					print("cscope: database build failed")
				else
					print("cscope: database built successfully")
				end
			end
		end)
	end
end

return M
