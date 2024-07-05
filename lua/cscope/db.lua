local utils = require("cscope_maps.utils")
local log = require("cscope_maps.utils.log")

local M = {}

--- conns = { {file = db_file, rel = db_rel}, ... }
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
---@param rel string
M.update_primary_conn = function(file, rel)
	M.conns[1].file = vim.fs.normalize(file)
	M.conns[1].rel = vim.fs.normalize(rel)
end

---Update global db connection
M.update_global_conn = function()
	if vim.g.cscope_maps_db_file then
		local file, rel = M.sp_file_rel(vim.g.cscope_maps_db_file)
		M.global_conn = { { file = file, rel = rel } }
	else
		M.global_conn = nil
	end
end

---Split input to ":Cs db add" into file and rel
---@param path string
---@return string
---@return string|nil
M.sp_file_rel = function(path)
	local sp = vim.split(path, ":")
	local file = vim.fs.normalize(sp[1])

	---@type string|nil
	local rel = sp[2]

	-- use parent as rel if its "@"
	if rel and rel == "@" then
		rel = utils.get_path_parent(file)
	end

	-- make it nil if its empty
	if rel and rel == "" then
		rel = nil
	end

	-- if rel exists, normalize it
	if rel then
		rel = vim.fs.normalize(rel)
	end

	return file, rel
end

---Find index of db in all connections
---@param file string
---@param rel string|nil
---@return integer
M.find = function(file, rel)
	for i, cons in ipairs(M.conns) do
		if cons.file == file and ((rel and cons.rel == rel) or cons.rel == nil) then
			return i
		end
	end

	return -1
end

---Add db in db connections
---@param path string
M.add = function(path)
	local file, rel = M.sp_file_rel(path)
	if M.find(file, rel) == -1 then
		table.insert(M.conns, { file = file, rel = rel })
	end
end

---Remove db from db connections
---Primary db connection will not be removed
---@param path string
M.remove = function(path)
	local file, rel = M.sp_file_rel(path)
	local loc = M.find(file, rel)
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
		log.warn(string.format("db=%s relpath=%s", conn.file, conn.rel))
	end
end

return M
