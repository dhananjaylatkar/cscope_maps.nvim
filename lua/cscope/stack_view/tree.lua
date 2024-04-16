local RC = require("utils.ret_codes")
local M = {}

--- node = {data: d, children: {n1, n2, n3, ...}}

M.create_node = function(symbol, filename, lnum)
	local node = {}

	node.children = nil
	node.depth = 0
	node.data = {}
	node.is_root = false

	node.data.symbol = symbol
	node.data.filename = filename
	node.data.lnum = tonumber(lnum, 10)

	return node
end

M.compare_node = function(node, symbol, filename, lnum)
	return (
		node
		and node.data
		and node.data.symbol == symbol
		and node.data.filename == filename
		and node.data.lnum == lnum
	)
end

M.get_node = function(root, symbol, filename, lnum)
	if M.compare_node(root, symbol, filename, lnum) then
		return root
	end

	local children = root.children

	if not children then
		return nil
	end

	for _, c in ipairs(children) do
		local node = M.get_node(c, symbol, filename, lnum)
		if node ~= nil then
			return node
		end
	end
end

M.update_children_depth = function(children, depth)
	for _, c in ipairs(children) do
		c.depth = depth
	end
end

M.update_children = function(root, symbol, filename, lnum, children)
	local node = M.get_node(root, symbol, filename, lnum)

	if not node then
		return RC.NODE_NOT_FOUND
	end

	if node.children == nil then
		node.children = children
		M.update_children_depth(node.children, node.depth + 1)
	else
		node.children = nil
	end

	return RC.SUCCESS
end

M.update_node = function(root, psymbol, pfilename, plnum, children) -- "p" is for parent
	local ret = M.update_children(root, psymbol, pfilename, plnum, children)

	if ret == RC.SUCCESS then
		return root
	end

	return nil
end

return M
