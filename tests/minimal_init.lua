if os.getenv("LUACOV") then
  require("luacov.runner").init()
  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      require("luacov.runner").shutdown()
    end,
  })
end

vim.cmd("set rtp+=.")
vim.cmd("set rtp+=~/.local/share/nvim/lazy/plenary.nvim")
vim.cmd("source ~/.local/share/nvim/lazy/plenary.nvim/plugin/plenary.vim")
require("plenary.busted")
