local M = {}

local non_empty = function(item)
	return item and item ~= ""
end

--- Get relative path
--- if "rel_to" or "path" are not absolute paths then return "path" as it is
--- else return relative path of "path" wrt to "rel_to"
---@param rel_to string
---@param path string
---@return string
M.get_rel_path = function(rel_to, path)
	if not vim.startswith(rel_to, "/") or not vim.startswith(path, "/") then
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

return M
