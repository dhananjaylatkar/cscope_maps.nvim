local utils = require("cscope_maps.utils")

local M = {}

M.conns = {}
M.global_conn = nil

M.all_conns = function()
	M.update_global_conn()
	return M.global_conn or M.conns
end

M.primary_conn = function()
	M.update_global_conn()
	if M.global_conn then
		return M.global_conn[1]
	end
	return M.conns[1]
end

M.update_primary_conn = function(file, rel)
	M.conns[1].file = vim.fs.normalize(file)

	M.conns[1].rel = vim.fs.normalize(rel)
end

M.update_global_conn = function()
	if vim.g.cscope_maps_db_file then
		local file, rel = M.sp_file_rel(vim.g.cscope_maps_db_file)
		M.global_conn = { { file = file, rel = rel } }
	else
		M.global_conn = nil
	end
end

M.sp_file_rel = function(path)
	local sp = vim.split(path, ":")
	local file = vim.fs.normalize(sp[1])
	local rel = sp[2]

	-- use parent as rel if its "@"
	if rel and rel == "@" then
		rel = utils.get_path_parent(file)
	end

	-- if rel exists, normalize it
	if rel then
		rel = vim.fs.normalize(rel)
	end

	return file, rel
end

M.find = function(file, rel)
	for i, cons in ipairs(M.conns) do
		if cons.file == file and cons.rel == rel then
			return i
		end
	end

	return -1
end

M.add = function(path)
	local file, rel = M.sp_file_rel(path)
	if M.find(file, rel) == -1 then
		table.insert(M.conns, { file = file, rel = rel })
	end
end

M.remove = function(path)
	local file, rel = M.sp_file_rel(path)
	local loc = M.find(file, rel)
	-- do not remove first entry
	if loc > 1 then
		table.remove(M.conns, loc)
	end
end

return M
