local M = {}

local non_empty = function(item)
	return item and item ~= "" and item ~= "."
end

--- Check is given path is absolute path
---@param path string
---@return boolean
M.is_path_abs = function(path)
	return vim.startswith(path, "/")
end

--- Get relative path
--- if "rel_to" or "path" are not absolute paths then return "path" as it is
--- else return relative path of "path" wrt to "rel_to"
---@param rel_to string
---@param path string
---@return string
M.get_rel_path = function(rel_to, path)
	if not M.is_path_abs(rel_to) or not M.is_path_abs(path) then
		return path
	end

	local rel_path = ""
	local sp_rel_to = vim.tbl_filter(non_empty, vim.split(rel_to, "/"))
	local sp_path = vim.tbl_filter(non_empty, vim.split(path, "/"))
	local len_rel_to = #sp_rel_to + 1
	local len_path = #sp_path + 1
	local i = 1

	-- skip till parents are same
	while i < len_rel_to and i < len_path do
		if sp_rel_to[i] == sp_path[i] then
			i = i + 1
		else
			break
		end
	end

	-- append "../" for remaining parents
	rel_path = rel_path .. string.rep("../", len_rel_to - i)

	-- append remaining path
	rel_path = rel_path .. table.concat(sp_path, "/", i)

	return rel_path
end

--- Convert given path to absolute path
---@param path string
---@return string
M.get_abs_path = function(path)
	if M.is_path_abs(path) then
		return path
	end

	local abs_path = "/"
	local cwd = vim.fn.getcwd()
	local sp_cwd = vim.tbl_filter(non_empty, vim.split(cwd, "/"))
	local sp_path = vim.tbl_filter(non_empty, vim.split(path, "/"))
	local len_cwd = #sp_cwd + 1
	local len_path = #sp_path + 1
	local i = 1

	-- get number of "../"
	while i < len_path do
		if sp_path[i] ~= ".." then
			break
		end
		i = i + 1
	end

	--- remove trailing parents from "cwd"
	abs_path = abs_path .. table.concat(sp_cwd, "/", 1, len_cwd - i)
	if abs_path == "/" then
		abs_path = ""
	end

	-- append remaining parents from "path"
	abs_path = abs_path .. "/" .. table.concat(sp_path, "/", i)
	return abs_path
end

--- Get parent of given path
---@param path string
---@return string
M.get_path_parent = function(path)
	local sp_path = vim.tbl_filter(non_empty, vim.split(path, "/"))
	local parent = ""

	if M.is_path_abs(path) then
		parent = "/"
	end

	parent = parent .. table.concat(sp_path, "/", 1, #sp_path - 1)
	print(parent)
	return parent
end

return M
