---@alias prompt_name "system.txt"|"inline-edit.txt"|"inline-edit-system.txt"

local M = {}

local prompt_dir = (function()
  local script = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(script, ":h")
end)()

---@param name prompt_name
function M.load(name)
  local path = prompt_dir .. "/" .. name
  local f = io.open(path, "r")
  if not f then
    error("Could not open prompt file: " .. path)
  end
  local content = f:read("*a")
  f:close()
  return content
end

return M
