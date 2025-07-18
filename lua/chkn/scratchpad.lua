local M = {}

M._config = {
	width = 80,
	height = 20,
	border = "rounded",
	persistent = true,
	path = vim.fn.stdpath("data") .. "/chkn_scratchpad.txt",
}

M._state = {
	buf = nil,
	win = nil,
}

function M._reset_state()
	M._state.win = nil
	M._state.buf = nil
end

function M.get_state()
	return M._state
end

function M.get_config()
	return M._config
end

function M.setup(user_config)
	M._config = vim.tbl_deep_extend("force", M._config, user_config or {})
  -- to avoid breaking changes, trim the .txt from old configs
  M._config.path = M._config.path:gsub("%.[%a%d]+$", ".")
end

function M.open(file_ending)
  if file_ending == "" or not file_ending then
    file_ending = "txt"
  end
	if M._state.win and vim.api.nvim_win_is_valid(M._state.win) then
		-- If the window exists, close it
		vim.api.nvim_win_close(M._state.win, true)
		M._reset_state()
		return
	end

	-- Create the buffer if it doesn't exist or was wiped
	if not M._state.buf or not vim.api.nvim_buf_is_valid(M._state.buf) then
		M._state.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(M._state.buf, "bufhidden", "wipe")
    ft = vim.filetype.match({ filename = "." .. file_ending })
    if not ft then
      ft = "text"
    end

		-- Load persistent content if enabled
		if M._config.persistent and vim.fn.filereadable(M._config.path .. file_ending) == 1 then
			vim.api.nvim_buf_set_lines(M._state.buf, 0, -1, false, vim.fn.readfile(M._config.path .. file_ending))
		end

    vim.defer_fn(function()
      vim.cmd("do BufNewFile")
      vim.api.nvim_buf_set_option(M._state.buf, "ft", ft)
    end, 10)

		-- Set autocommands for persistence
		if M._config.persistent then
			vim.api.nvim_create_autocmd("BufWriteCmd", {
				buffer = M._state.buf,
				callback = function()
					M.save(M._state.buf, file_ending)
				end,
			})

			vim.api.nvim_create_autocmd("BufWipeout", {
				buffer = M._state.buf,
				callback = function()
					M.save(M._state.buf, file_ending)
				end,
			})
		end
	end

	-- Center the scratchpad
	local width = M._config.width
	local height = M._config.height
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	-- Create a floating window
	M._state.win = vim.api.nvim_open_win(M._state.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		border = M._config.border,
	})

	-- Set window options
	vim.api.nvim_win_set_option(M._state.win, "wrap", false)

	-- Map 'q' to close the scratchpad
	vim.api.nvim_buf_set_keymap(
		M._state.buf,
		"n",
		"q",
		":lua require('chkn.scratchpad').close()<CR>",
		{ noremap = true, silent = true, nowait = true }
	)
end

function M.close()
	if M._state.win and vim.api.nvim_win_is_valid(M._state.win) then
		vim.api.nvim_win_close(M._state.win, true)
		M._reset_state()
	end
end

function M.save(buf, file_ending)
	if M._config.persistent then
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 1 and lines[1] == "" then
      os.remove(M._config.path .. file_ending)
    else
      vim.fn.writefile(lines, M._config.path .. file_ending)
    end
	end
end

return M
