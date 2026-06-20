---@class UserInputWindow
local UserInputWindow = {}
UserInputWindow.__index = UserInputWindow

function UserInputWindow:new(opts)
  local instance = setmetatable({}, UserInputWindow)
  instance.opts = opts
  return instance
end

function UserInputWindow:open()
  local buf = vim.api.nvim_create_buf(false, true)
  local ok, result = pcall(vim.api.nvim_open_win, buf, false, {
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
  vim.wo[win].winhl = "Normal:NormalFloat"
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })

  self.buf = buf
  self.win = win
end

function UserInputWindow:get_lines()
  local lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

function UserInputWindow:clear()
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, { "" })
end

function UserInputWindow:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
end

return UserInputWindow
