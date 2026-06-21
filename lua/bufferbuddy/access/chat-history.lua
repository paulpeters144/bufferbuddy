---@class ChatHistory
---@field private _entries table[]
---@field private _max_entries number|nil
local ChatHistory = {}
ChatHistory.__index = ChatHistory

---@param opts? { max_entries?: number }
---@return ChatHistory
function ChatHistory:new(opts)
  opts = opts or {}
  local instance = setmetatable({}, ChatHistory)
  instance._entries = {}
  instance._max_entries = opts.max_entries
  return instance
end

function ChatHistory:_trim()
  if not self._max_entries then
    return
  end
  while #self._entries > self._max_entries do
    table.remove(self._entries, 1)
  end
end

---@param lines string[]
function ChatHistory:add_user_message(lines)
  table.insert(self._entries, { role = "user", lines = lines })
  self:_trim()
end

---@param lines string[]
function ChatHistory:add_assistant_message(lines)
  table.insert(self._entries, { role = "assistant", lines = lines })
  self:_trim()
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
