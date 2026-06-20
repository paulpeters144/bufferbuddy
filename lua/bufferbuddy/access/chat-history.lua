---@class ChatHistory
---@field private _entries table[]
local ChatHistory = {}
ChatHistory.__index = ChatHistory

---@return ChatHistory
function ChatHistory:new()
  local instance = setmetatable({}, ChatHistory)
  instance._entries = {}
  return instance
end

---@param lines string[]
function ChatHistory:add_user_message(lines)
  table.insert(self._entries, { role = "user", lines = lines })
end

---@param lines string[]
function ChatHistory:add_assistant_message(lines)
  table.insert(self._entries, { role = "assistant", lines = lines })
end

---@return string
function ChatHistory:to_string()
  local parts = {}
  for _, entry in ipairs(self._entries) do
    local header = entry.role == "user" and "### User" or "### Assistant"
    table.insert(parts, header)
    for _, line in ipairs(entry.lines) do
      table.insert(parts, line)
    end
    table.insert(parts, "")
  end
  return table.concat(parts, "\n")
end

function ChatHistory:clear()
  self._entries = {}
end

return ChatHistory
