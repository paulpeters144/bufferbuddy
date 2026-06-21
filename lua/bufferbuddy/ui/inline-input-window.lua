local InlineInputWindow = {}
InlineInputWindow.__index = InlineInputWindow

function InlineInputWindow:new(opts)
  local instance = setmetatable({}, InlineInputWindow)
  instance.title = opts.title or " Edit instruction "
  instance.prompt = opts.prompt
  instance.width = opts.width or 55
  instance.on_submit = opts.on_submit
  instance.on_cancel = opts.on_cancel
  instance.buf = nil
  instance.win = nil
  return instance
end

local function wrap_text(text, max_width)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    while #line > max_width do
      local sub = line:sub(1, max_width + 1)
      local space_pos = sub:match("^.*()%s")
      if space_pos then
        lines[#lines + 1] = sub:sub(1, space_pos - 1)
        line = line:sub(space_pos + 1):match("^%s*(.*)$")
      else
        lines[#lines + 1] = line:sub(1, max_width)
        line = line:sub(max_width + 1)
      end
    end
    if #line > 0 then
      lines[#lines + 1] = line
    end
  end
  return lines
end

function InlineInputWindow:open()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    return
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].bufhidden = "wipe"
  vim.bo[self.buf].textwidth = 0
  vim.bo[self.buf].wrapmargin = 0

  local inner_width = self.width - 4

  local prompt_lines = {}
  if self.prompt then
    prompt_lines = wrap_text(self.prompt, inner_width)
  end

  local wrapped = {}
  for _, pl in ipairs(prompt_lines) do
    wrapped[#wrapped + 1] = "  " .. pl
  end

  local lines = { "", table.unpack(wrapped), "", "> ", "" }
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)

  local prompt_count = #prompt_lines
  local input_row = prompt_count + 3
  local height = prompt_count + 4
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - self.width) / 2)

  local title = " " .. self.title .. " "

  local ok, result = pcall(vim.api.nvim_open_win, self.buf, true, {
    relative = "editor",
    width = self.width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "left",
  })
  if not ok then
    vim.api.nvim_buf_delete(self.buf, { force = true })
    self.buf = nil
    return
  end
  self.win = result

  vim.wo[self.win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
  vim.wo[self.win].wrap = true
  vim.wo[self.win].linebreak = true

  vim.api.nvim_win_set_cursor(self.win, { input_row, 3 })
  vim.cmd("startinsert!")

  local function submit()
    local text = self:get_text()
    local cb = self.on_submit
    local cc = self.on_cancel
    self:close()
    if text and text ~= "" then
      if cb then cb(text) end
    else
      if cc then cc() end
    end
  end

  local function cancel()
    local cc = self.on_cancel
    self:close()
    if cc then cc() end
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = self.buf, nowait = true })
  vim.keymap.set("i", "<C-c>", cancel, { buffer = self.buf, nowait = true })
  vim.keymap.set("n", "q", cancel, { buffer = self.buf, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = self.buf, nowait = true })
  vim.keymap.set("n", "<CR>", submit, { buffer = self.buf, nowait = true })
  vim.keymap.set("n", "<C-c>", cancel, { buffer = self.buf, nowait = true })
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
  end, { buffer = self.buf, nowait = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = self.buf,
    once = true,
    callback = function()
      pcall(function() vim.cmd("stopinsert") end)
    end,
  })
end

function InlineInputWindow:get_text()
  if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then
    return nil
  end
  local content = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
  for _, line in ipairs(content) do
    local text = line:match("^>%s?(.*)$")
    if text then
      return text
    end
  end
  return nil
end

function InlineInputWindow:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  self.win = nil
  self.buf = nil
  pcall(function() vim.cmd("stopinsert") end)
end

return InlineInputWindow
