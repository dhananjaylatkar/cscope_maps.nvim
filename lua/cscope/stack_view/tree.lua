local RC = require("cscope_maps.utils.ret_codes")
local M = {}

--- node = {data: d, children: {n1, n2, n3, ...}}

M.create_node = function(symbol, filename, lnum)
	local node = {}

	node.children = nil
	node.depth = 0
	node.data = {}
	node.is_root = false
	node.id = 0

	node.data.symbol = symbol
	node.data.filename = filename
	node.data.lnum = tonumber(lnum, 10)

	return node
end

M.compare_node = function(node, id)
	return (node and node.id == id)
end

M.get_node = function(root, id)
	if M.compare_node(root, id) then
		return root
	end

	local children = root.children

	if not children then
		return nil
	end

	for _, c in ipairs(children) do
		local node = M.get_node(c, id)
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

M.update_children = function(root, parent_id, children)
	local node = M.get_node(root, parent_id)

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

M.update_node = function(root, parent_id, children)
	local ret = M.update_children(root, parent_id, children)

	if ret == RC.SUCCESS then
		return root
	end

	return nil
end

return M
