local M = {}

local function find_git_root(start)
  local path = vim.fn.resolve(start)
  while true do
    if vim.fn.isdirectory(path .. "/.git") == 1 then
      return path
    end
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent == path then
      return nil
    end
    path = parent
  end
end

function M.summarize(project_root)
  project_root = project_root or vim.fn.getcwd()
  local git_root = find_git_root(project_root)
  if not git_root then
    return nil
  end
  return "Project root: " .. git_root
end

return M
