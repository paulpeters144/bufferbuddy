local AiChatWindow = require("bufferbuddy.ui.ai-chat-window")
local UserInputWindow = require("bufferbuddy.ui.user-input-window")
local Spinner = require("bufferbuddy.ui.spinner")
local LLM = require("bufferbuddy.access.llm")
local ChatHistory = require("bufferbuddy.access.chat-history")
local util = require("bufferbuddy.ui.util")

---@type NvimModel
local NvimModel = require("bufferbuddy.ui.nvim-model")

local Controller = {}
Controller.__index = Controller

---@param opts? {vim?: Vim}
function Controller:new(opts)
  opts = opts or {}
  local vim = opts.vim or NvimModel.create()

  local window_w = math.floor(vim.o.columns * 0.8)
  local width = math.min(100, window_w)
  local total_height = math.floor(vim.o.lines * 0.8)
  local input_height = 5
  local display_height = total_height - input_height - 2
  local total_row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local instance = setmetatable({}, Controller)
  instance.vim = vim
  instance.width = width
  instance.input_height = input_height
  instance.display_height = display_height
  instance.total_row = total_row
  instance.col = col
  instance.selected_lines = nil
  instance._chat_history = ChatHistory:new({ max_entries = LLM.config.max_history_entries })
  instance._spinner = Spinner:new()
  instance.ai_chat = AiChatWindow:new({
    width = instance.width,
    height = instance.display_height,
    row = instance.total_row,
    col = instance.col,
  })
  instance.user_input = UserInputWindow:new({
    width = instance.width,
    height = instance.input_height,
    row = instance.total_row + instance.display_height + 2,
    col = instance.col,
  })
  return instance
end

function Controller:open(selected_lines)
  self:_capture_context()
  self.ai_chat:open()
  self.user_input:open()
  self:_setup_keymaps()

  if selected_lines and #selected_lines > 0 then
    self.selected_lines = selected_lines
    local marker = "[Selected ~" .. #selected_lines .. " lines]"
    self.vim.api.nvim_buf_set_lines(self.user_input.buf, 0, -1, false, { marker, "" })
  end

  self.vim.schedule(function()
    pcall(function()
      self.vim.api.nvim_set_current_win(self.user_input.win)
    end)
    if self.selected_lines then
      self.vim.api.nvim_win_set_cursor(self.user_input.win, { 2, 0 })
    end
    self.vim.cmd("startinsert!")
  end)
end

function Controller:open_explain(lines)
  self:_capture_context()
  self.ai_chat:open()
  self.user_input:open()
  self:_setup_keymaps()

  if not lines or #lines == 0 then
    return
  end

  self.selected_lines = lines
  local marker = "[Selected ~" .. #lines .. " lines]"
  self.vim.api.nvim_buf_set_lines(self.user_input.buf, 0, -1, false, { marker, "Explain this code:" })

  self.vim.schedule(function()
    pcall(function()
      self.vim.api.nvim_set_current_win(self.user_input.win)
    end)
    self.vim.api.nvim_win_set_cursor(self.user_input.win, { 2, 0 })
    self.vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(self.user_input.buf) then
        self:_send_message()
      end
    end, 50)
  end)
end

function Controller:_capture_context()
  self._context = {}

  local filepath = vim.fn.expand("%:p")
  if filepath and filepath ~= "" then
    self._context.filepath = filepath
  end

  local win = vim.api.nvim_get_current_win()
  if win and vim.api.nvim_win_is_valid(win) then
    local wininfo = vim.fn.getwininfo(win)
    if wininfo and #wininfo > 0 then
      self._context.visible_lines = { top = wininfo[1].topline, bottom = wininfo[1].botline }
    end
  end
end

function Controller:_send_message()
  local lines = self.user_input:get_lines()
  if #lines <= 0 then
    return
  end

  local all_lines = {}
  if self.selected_lines and lines[1] and lines[1]:match("^%[Selected ~") then
    local user_lines = {}
    for i = 2, #lines do
      table.insert(user_lines, lines[i])
    end
    for _, line in ipairs(self.selected_lines) do
      table.insert(all_lines, line)
    end
    for _, line in ipairs(user_lines) do
      table.insert(all_lines, line)
    end
  else
    all_lines = lines
  end
  self.selected_lines = nil

  local formatted_lines = {}
  table.insert(formatted_lines, "### User")
  for _, line in ipairs(all_lines) do
    table.insert(formatted_lines, line)
  end
  table.insert(formatted_lines, "")

  local start_line = self.ai_chat:append_lines(formatted_lines)
  self.user_input:clear()

  local focused_line = { start_line + #formatted_lines, 0 }
  self.vim.api.nvim_win_set_cursor(self.ai_chat.win, focused_line)
  self.vim.api.nvim_set_current_win(self.ai_chat.win)

  util.force_mode(self.vim, "normal")

  self.ai_chat:append_lines({ "### Assistant" })
  self._spinner:start({
    buf = self.ai_chat.buf,
    text = "",
  })
  local tool_start_line = self._spinner.line

  LLM.chat_completion({
    user_message = table.concat(all_lines, "\n"),
    context = self._context,
    history = self._chat_history,
    callbacks = {
      on_tool_call = function(name, _args)
        if not vim.api.nvim_buf_is_valid(self.ai_chat.buf) then
          return
        end
        self._spinner:stop()
        local buflen = #vim.api.nvim_buf_get_lines(self.ai_chat.buf, 0, -1, false)
        vim.api.nvim_buf_set_lines(self.ai_chat.buf, tool_start_line, buflen, false, {
          "🔧 Running `" .. name .. "`...",
        })
        self._spinner:start({
          buf = self.ai_chat.buf,
          text = "",
        })
      end,
      on_result = function(text)
        self._spinner:stop()
        if not vim.api.nvim_buf_is_valid(self.ai_chat.buf) then
          return
        end

        local response_lines = {}
        for line in text:gmatch("[^\n]+") do
          table.insert(response_lines, line)
        end
        table.insert(response_lines, "")
        self._chat_history:add_user_message(all_lines)
        self._chat_history:add_assistant_message(response_lines)

        local buflen = #vim.api.nvim_buf_get_lines(self.ai_chat.buf, 0, -1, false)
        vim.api.nvim_buf_set_lines(self.ai_chat.buf, tool_start_line, buflen, false, response_lines)
        local cursor_line = { tool_start_line + #response_lines, 0 }
        self.vim.api.nvim_win_set_cursor(self.ai_chat.win, cursor_line)
      end,
      on_error = function(err)
        self._spinner:stop()
        if not vim.api.nvim_buf_is_valid(self.ai_chat.buf) then
          return
        end
        local buflen = #vim.api.nvim_buf_get_lines(self.ai_chat.buf, 0, -1, false)
        vim.api.nvim_buf_set_lines(self.ai_chat.buf, tool_start_line, buflen, false, { "Error: " .. err, "" })
      end,
    },
  })
end

function Controller:close()
  self._spinner:stop()
  self.ai_chat:close()
  self.user_input:close()
  util.force_mode(self.vim, "normal")
end

function Controller:_setup_keymaps()
  self.vim.api.nvim_buf_set_keymap(self.user_input.buf, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    nowait = true,
    callback = function()
      self:close()
    end,
  })

  self.vim.api.nvim_buf_set_keymap(self.user_input.buf, "i", "<Esc>", "", {
    noremap = true,
    silent = true,
    nowait = true,
    callback = function()
      util.force_mode(vim, "normal")
    end,
  })

  self.vim.api.nvim_buf_set_keymap(self.user_input.buf, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    callback = function()
      if self._spinner:is_spinning() then
        return
      end
      self:_send_message()
    end,
  })

  self.vim.api.nvim_buf_set_keymap(self.ai_chat.buf, "n", "i", "", {
    noremap = true,
    silent = true,
    callback = function()
      self.vim.api.nvim_set_current_win(self.user_input.win)
      self.vim.cmd("startinsert!")
    end,
  })

  self.vim.api.nvim_buf_set_keymap(self.ai_chat.buf, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    nowait = true,
    callback = function()
      self.vim.api.nvim_set_current_win(self.user_input.win)
      self.vim.cmd("startinsert!")
    end,
  })
end

return Controller
