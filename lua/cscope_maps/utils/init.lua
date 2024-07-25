local M = {}

--- Check if given path is absolute path
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
	local sp_rel_to = vim.split(vim.fs.normalize(rel_to), "/")
	local sp_path = vim.split(vim.fs.normalize(path), "/")
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

	local abs_path = vim.fs.joinpath(vim.fn.getcwd(), path)

	return vim.fs.normalize(abs_path)
end

--- Get parent of given path
---@param path string
---@return string
M.get_path_parent = function(path)
	for parent in vim.fs.parents(path) do
		return parent
	end
	return ""
end

---Get all dirs and files in given path
---@param dir string
---@return table
M.get_files_in_dir = function(dir)
	local fs_entries = vim.fn.readdir(dir)

	-- add "/" suffix for dirs and return
	return vim.tbl_map(function(x)
		local entry = x
		if dir ~= "." then
			entry = vim.fs.joinpath(dir, x)
		end
		if vim.fn.isdirectory(x) == 1 then
			entry = entry .. "/"
		end
		return entry
	end, fs_entries)
end

---Get all dirs in given path
---@param dir string
---@return table
M.get_dirs_in_dir = function(dir)
	local fs_entries = vim.fn.readdir(dir)

	-- add "/" suffix for dirs
	fs_entries = vim.tbl_map(function(x)
		local entry = x
		if dir ~= "." then
			entry = vim.fs.joinpath(dir, x)
		end
		return entry .. "/"
	end, fs_entries)

	-- return only dirs
	return vim.tbl_filter(function(x)
		return vim.fn.isdirectory(x) == 1
	end, fs_entries)
end

return M
