local M = {}

--- @param mode "normal" | "insert" | "visual"
--- @param vim Vim
function M.force_mode(vim, mode)
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
    local r = vim.api.nvim_replace_termcodes(keys, true, true, true)
    vim.api.nvim_feedkeys(r, "n", false)
  end
end
return M
