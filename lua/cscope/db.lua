local utils = require("cscope_maps.utils")
local log = require("cscope_maps.utils.log")

local M = {}

--- conns = { {file = db_file, pre_path = db_pre_path}, ... }
M.conns = {}
M.global_conn = nil

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

---Split input to ":Cs db add" into file and pre_path
---@param path string
---@return string
---@return string|nil
M.sp_file_pre_path = function(path)
	local sp = vim.split(path, ":")
	local file = vim.fs.normalize(sp[1])

	---@type string|nil
	local pre_path = sp[2]

	-- use parent as pre_path if its "@"
	if pre_path and pre_path == "@" then
		pre_path = utils.get_path_parent(file)
	end

	-- make it nil if its empty
	if pre_path and pre_path == "" then
		pre_path = nil
	end

	-- if pre_path exists, normalize it
	if pre_path then
		pre_path = vim.fs.normalize(pre_path)
	end

	return file, pre_path
end

---Find index of db in all connections
---@param file string
---@param pre_path string|nil
---@return integer
M.find = function(file, pre_path)
	for i, cons in ipairs(M.conns) do
		if utils.is_path_same(cons.file, file) and
			(utils.is_path_same(cons.pre_path, pre_path) or cons.pre_path == nil) then
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

M.print_conns = function()
	if not M.conns then
		log.warn("No connections")
	end

	for _, conn in ipairs(M.conns) do
		log.warn(string.format("db=%s pre_path=%s", conn.file, conn.pre_path))
	end
end

return M
