local M = {}

--- node = {data: d, children: {n1, n2, n3, ...}}

M.create_node = function(symbol, filename, lnum)
	local node = {}

	node.children = nil
	node.data = {}
	node.data.symbol = symbol
	node.data.filename = filename
	node.data.lnum = tonumber(lnum, 10)

	return node
end

M.compare_node = function(node, symbol, filename, lnum)
	return (node.data.symbol == symbol
			and node.data.filename == filename
			and node.data.lnum == lnum)
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

M.update_children = function(root, symbol, filename, lnum, children)
	local node = M.get_node(root, symbol, filename, lnum)

	if not node then
		return
	end

	node.children = children
end

return M
