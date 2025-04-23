local M = {}

M.run = function(opts)
	local pos_cmd = ""
	local window_size = opts.cscope.qf_window_size or opts.cscope.picker_opts.window_size
	local window_pos = opts.cscope.qf_window_pos or opts.cscope.picker_opts.window_pos

	vim.fn.setqflist(opts.cscope.parsed_output, "r")
	vim.fn.setqflist({}, "a", { title = opts.cscope.prompt_title })

	if window_pos == "top" then
		pos_cmd = "topleft"
	elseif window_pos == "bottom" then
		pos_cmd = "botright"
	elseif window_pos == "right" then
		pos_cmd = "botright vertical"
	elseif window_pos == "left" then
		pos_cmd = "topleft vertical"
	end

	vim.cmd(pos_cmd .. " copen " .. window_size)
end

return M
