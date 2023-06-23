local M = {}

M.lvl = vim.log.levels
-- DEBUG
-- ERROR
-- INFO
-- TRACE
-- WARN
-- OFF

M.debug = function(msg, hide)
	if hide then
		return
	end
	vim.notify("cscope: " .. msg, M.lvl.DEBUG)
end

M.error = function(msg, hide)
	if hide then
		return
	end
	vim.notify("cscope: " .. msg, M.lvl.ERROR)
end

M.info = function(msg, hide)
	if hide then
		return
	end
	vim.notify("cscope: " .. msg, M.lvl.INFO)
end

M.trace = function(msg, hide)
	if hide then
		return
	end
	vim.notify("cscope: " .. msg, M.lvl.trace)
end

M.warn = function(msg, hide)
	if hide then
		return
	end
	vim.notify("cscope: " .. msg, M.lvl.WARN)
end

return M
