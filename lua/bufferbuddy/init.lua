local Controller = require("bufferbuddy.ui.input-chat-ctrl")
local M = {}

function M.open_chat(pasted_lines)
  local ctrl = Controller:new()
  ctrl:open(pasted_lines)
end

return M
