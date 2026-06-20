vim.cmd("set rtp+=.")
vim.cmd("set rtp+=~/.local/share/nvim/lazy/plenary.nvim")
vim.cmd("source ~/.local/share/nvim/lazy/plenary.nvim/plugin/plenary.vim")
require("plenary.busted")
