local LLM = require("bufferbuddy.access.llm")
local M = {}

function M.setup(config)
  LLM.setup(config)
end

function M.edit(opts)
  local InlineEdit = require("bufferbuddy.ui.inline-edit-ctrl")
  local ctrl = InlineEdit:new(opts)
  ctrl:open()
end

function M.open_chat(pasted_lines)
  local Controller = require("bufferbuddy.ui.input-chat-ctrl")
  local ctrl = Controller:new()
  ctrl:open(pasted_lines)
end

function M.explain(lines)
  if not lines or #lines == 0 then
    return
  end
  local Controller = require("bufferbuddy.ui.input-chat-ctrl")
  local ctrl = Controller:new()
  ctrl:open_explain(lines)
end

return M
