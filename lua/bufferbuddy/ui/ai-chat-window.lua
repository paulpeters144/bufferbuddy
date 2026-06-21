---@class AiChatWindow
---@field opts table
local AiChatWindow = {}
AiChatWindow.__index = AiChatWindow

function AiChatWindow:new(opts)
  local instance = setmetatable({}, AiChatWindow)
  instance.opts = opts
  return instance
end

function AiChatWindow:open()
  local buf = vim.api.nvim_create_buf(false, true)
  local ok, result = pcall(vim.api.nvim_open_win, buf, true, {
    relative = "editor",
    width = self.opts.width,
    height = self.opts.height,
    row = self.opts.row,
    col = self.opts.col,
    style = "minimal",
    border = "rounded",
  })
  if not ok then
    return
  end
  local win = result

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "markdown"
  vim.wo[win].winhl = "Normal:NormalFloat"

  local welcome = [[
# Buffer Buddy Chat

Type your message in the input window below.
Press `<Esc>` then `<CR>` to send.
Press `<Esc>` twice to close.

From this window, press `i` or `<Esc>` to return to the input window.

---
]]
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(welcome, "\n"))

  self.buf = buf
  self.win = win
end

function AiChatWindow:append_lines(lines)
  local display_lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
  vim.api.nvim_buf_set_lines(self.buf, #display_lines, #display_lines, false, lines)
  return #display_lines
end

function AiChatWindow:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
end

return AiChatWindow
