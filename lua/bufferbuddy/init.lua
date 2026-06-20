local M = {}

function M.open_chat()
  local window_w = math.floor(vim.o.columns * 0.8)
  local width = math.min(100, window_w)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "markdown"

  local welcome = [[
# Buffer Buddy Chat
Type your message below. Press `<CR>` to send (placeholder for now).
Press `q` or `<Esc>` to close.

---
]]
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(welcome, "\n"))
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>q<CR>", { noremap = true, silent = true })
  vim.wo[win].winhl = "Normal:NormalFloat"
end

return M
