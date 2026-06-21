local util = {}

---@param str string
---@param max_lines number
---@param message string
---@return string
function util.truncate(str, max_lines, message)
  if max_lines < 1 then
    return ""
  end

  local lines = {}
  for line in str:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  if #lines <= max_lines then
    return str
  end

  local result = {}
  for i = 1, max_lines do
    table.insert(result, lines[i])
  end
  table.insert(result, message)
  return table.concat(result, "\n")
end

return util
