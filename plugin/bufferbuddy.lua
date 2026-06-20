if vim.g.loaded_bufferbuddy then
  return
end
vim.g.loaded_bufferbuddy = true

vim.api.nvim_create_user_command("BufferBuddyChat", function()
  require("bufferbuddy").open_chat()
end, {})

vim.keymap.set("n", "<leader>bbq", function()
  require("bufferbuddy").open_chat()
end, { desc = "Open Buffer Buddy chat" })
