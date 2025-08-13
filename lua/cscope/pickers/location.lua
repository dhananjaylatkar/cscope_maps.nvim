local M = {}

M.run = function(opts)
	local pos_cmd = ""

	vim.fn.setloclist(0, opts.cscope.parsed_output)
	vim.fn.setloclist(0, {}, "a", { title = opts.cscope.prompt_title })

	if opts.cscope.picker_opts.window_pos == "top" then
		pos_cmd = "aboveleft"
	elseif opts.cscope.picker_opts.window_pos == "bottom" then
		pos_cmd = "belowright"
	elseif opts.cscope.picker_opts.window_pos == "right" then
		pos_cmd = "belowright vertical"
	elseif opts.cscope.picker_opts.window_pos == "left" then
		pos_cmd = "aboveleft vertical"
	end

	vim.cmd(pos_cmd .. " lopen " .. opts.cscope.picker_opts.window_size)
end

return M
