local logger = require("bufferbuddy.logger")

if vim.g.loaded_bufferbuddy then
  logger.error("NOT LOADED")
  return
end
vim.g.loaded_bufferbuddy = true

vim.api.nvim_create_user_command("BufferBuddyChat", function()
  require("bufferbuddy").open_chat()
end, {})

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
