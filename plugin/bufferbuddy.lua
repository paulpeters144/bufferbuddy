local logger = require("bufferbuddy.logger")

if vim.g.loaded_bufferbuddy then
  logger.error("NOT LOADED")
  return
end
vim.g.loaded_bufferbuddy = true

vim.api.nvim_create_user_command("BufferBuddyChat", function()
  require("bufferbuddy").open_chat()
end, {})

vim.keymap.set("n", "<leader>bb", "<Nop>", { desc = "Buffer Buddy" })

vim.keymap.set("n", "<leader>bbq", function()
  require("bufferbuddy").open_chat()
end, { desc = "Open Buffer Buddy chat" })

vim.keymap.set("v", "<leader>bbq", function()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos
  end
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  if #lines > 0 then
    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
    else
      lines[1] = string.sub(lines[1], start_pos[3])
      lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
    end
  end
  require("bufferbuddy").open_chat(lines)
end, { desc = "Open Buffer Buddy chat with selection" })

vim.keymap.set("n", "<leader>bbx", function()
  local line_num = vim.fn.line(".")
  local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)
  require("bufferbuddy").explain(line)
end, { desc = "Explain current line" })

vim.keymap.set("v", "<leader>bbx", function()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos
  end
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  if #lines > 0 then
    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
    else
      lines[1] = string.sub(lines[1], start_pos[3])
      lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
    end
  end
  require("bufferbuddy").explain(lines)
end, { desc = "Explain selection" })

vim.keymap.set("n", "<leader>bbe", function()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable then
    return
  end
  local line_num = vim.fn.line(".")
  require("bufferbuddy").edit({ buf = buf, start_line = line_num, end_line = line_num })
end, { desc = "Edit code via LLM" })

vim.keymap.set("v", "<leader>bbe", function()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable then
    return
  end
  local s = vim.fn.line("v")
  local e = vim.fn.line(".")
  if s > e then
    s, e = e, s
  end
  require("bufferbuddy").edit({ buf = buf, start_line = s, end_line = e })
end, { desc = "Edit selection via LLM" })
