local M = {}

M.run = function(opts)
	local pos

	vim.fn.setloclist(0, opts.cscope.parsed_output, "r")
	vim.fn.setloclist(0, {}, "a", { title = opts.cscope.prompt_title })

	if opts.cscope.qf_window_pos == "top" then
		pos = "topleft"
	elseif opts.cscope.qf_window_pos == "bottom" then
		pos = "botright"
	elseif opts.cscope.qf_window_pos == "right" then
		pos = "botright vertical"
	elseif opts.cscope.qf_window_pos == "left" then
		pos = "topleft vertical"
	end

	vim.cmd(pos .. " lopen " .. opts.cscope.qf_window_size)
end

return M

