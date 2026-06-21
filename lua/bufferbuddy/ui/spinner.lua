local Spinner = {}
Spinner.__index = Spinner

local default_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function Spinner:new()
  local instance = setmetatable({}, Spinner)
  instance.buf = nil
  instance.win = nil
  instance.text = ""
  instance.chars = default_chars
  instance.interval = 200
  instance.idx = 1
  instance.line = nil
  instance._stopped = true
  return instance
end

function Spinner:is_spinning()
  return not self._stopped
end

function Spinner:start(opts)
  self.text = opts.text or ""
  self.chars = opts.chars or default_chars
  self.interval = opts.interval or 200
  self.idx = 0
  self.line = opts.line
  self._stopped = false

  if opts.winbar then
    self:_tick_winbar()
  else
    self.buf = opts.buf
    self.line = self.line or #vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
    self:_tick_buf()
  end
end

function Spinner:_tick_buf()
  if self._stopped then
    return
  end
  if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    self:stop()
    return
  end
  self.idx = self.idx % #self.chars + 1
  pcall(vim.api.nvim_buf_set_lines, self.buf, self.line, self.line + 1, false,
    { self.text .. self.chars[self.idx] })
  vim.defer_fn(function()
    self:_tick_buf()
  end, self.interval)
end

function Spinner:_tick_winbar()
  if self._stopped then
    return
  end
  self.win = self.win or vim.api.nvim_get_current_win()
  if not self.win or not vim.api.nvim_win_is_valid(self.win) then
    self:stop()
    return
  end
  self.idx = self.idx % #self.chars + 1
  local text = "%=%#BufferBuddySpinner# " .. self.text .. " " .. self.chars[self.idx] .. " %*"
  pcall(function() vim.wo[self.win].winbar = text end)
  vim.defer_fn(function()
    self:_tick_winbar()
  end, self.interval)
end

function Spinner:stop()
  self._stopped = true
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    pcall(function() vim.wo[self.win].winbar = "" end)
    self.win = nil
  end
  self.buf = nil
end

return Spinner
