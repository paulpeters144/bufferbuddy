local Spinner = {}
Spinner.__index = Spinner

local default_chars = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

function Spinner:new()
  local instance = setmetatable({}, Spinner)
  instance.buf = nil
  instance.text = ""
  instance.chars = default_chars
  instance.interval = 200
  instance.idx = 1
  instance.line = nil
  instance.timer = nil
  return instance
end

function Spinner:is_spinning()
  return self.timer ~= nil
end

function Spinner:start(opts)
  assert(not self:is_spinning(), "Spinner is already spinning")
  self.buf = opts.buf
  self.text = opts.text or ""
  self.chars = opts.chars or default_chars
  self.interval = opts.interval or 200
  self.idx = 1
  self.line = #vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
  vim.api.nvim_buf_set_lines(self.buf, self.line, self.line, false, { self.text .. self.chars[self.idx] })

  self.timer = vim.uv.new_timer()
  self.timer:start(self.interval, self.interval, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(self.buf) then
      self:stop()
      return
    end
    self.idx = self.idx % #self.chars + 1
    pcall(vim.api.nvim_buf_set_lines, self.buf, self.line, self.line + 1, false, { self.text .. self.chars[self.idx] })
  end))
end

function Spinner:stop()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
end

return Spinner
