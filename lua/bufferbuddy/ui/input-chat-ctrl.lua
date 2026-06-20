local AiChatWindow = require("bufferbuddy.ui.ai-chat-window")
local UserInputWindow = require("bufferbuddy.ui.user-input-window")
local Spinner = require("bufferbuddy.ui.spinner")
local LLM = require("bufferbuddy.access.llm")
local ChatHistory = require("bufferbuddy.access.chat-history")

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
  instance._chat_history = ChatHistory:new()
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

--- Reads content from the input window, formats it, and triggers the chat submission.
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
    -- TODO: detect code and add the ```code thing
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

  self._chat_history:add_user_message(all_lines)

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

  self:_force_mode("normal")

  local messages_str = self._chat_history:to_string()

  self._spinner:start({
    buf = self.ai_chat.buf,
    text = "### Assistant  ",
  })
  local thinking_start = self._spinner.line

  LLM.chat_completion(messages_str, function(response)
    self._spinner:stop()

    if not vim.api.nvim_buf_is_valid(self.ai_chat.buf) then
      return
    end

    local response_lines = {}
    for line in response:gmatch("[^\n]+") do
      table.insert(response_lines, line)
    end
    self._chat_history:add_assistant_message(response_lines)

    local assistant_lines = {}
    table.insert(assistant_lines, "### Assistant")
    for _, line in ipairs(response_lines) do
      table.insert(assistant_lines, line)
    end
    table.insert(assistant_lines, "")

    vim.api.nvim_buf_set_lines(self.ai_chat.buf, thinking_start, thinking_start + 1, false, assistant_lines)
    local cursor_line = { thinking_start + #assistant_lines, 0 }
    self.vim.api.nvim_win_set_cursor(self.ai_chat.win, cursor_line)
  end)
end

function Controller:close()
  self._spinner:stop()
  self.ai_chat:close()
  self.user_input:close()
  self:_force_mode("normal")
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
      self:_force_mode("normal")
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

--- @param mode "normal" | "insert" | "visual"
function Controller:_force_mode(mode)
  local modes = {
    normal = "<Esc>",
    insert = "<Esc>i",
    visual = "<Esc>v",
    visual_line = "<Esc>V",
    visual_block = "<Esc><C-v>",
    replace = "<Esc>R",
  }

  if modes[mode] then
    local keys = modes[mode]
    local r = self.vim.api.nvim_replace_termcodes(keys, true, true, true)
    self.vim.api.nvim_feedkeys(r, "n", false)
  end
end

return Controller
