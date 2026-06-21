local Provider = require("bufferbuddy.access.provider")
local prompts = require("bufferbuddy.prompt")

local Claude = setmetatable({}, Provider)
Claude.__index = Claude

function Claude:new(config)
  config = config or {}
  local instance = setmetatable({}, Claude)
  instance.api_key = config.api_key or os.getenv("ANTHROPIC_API_KEY")
  instance.model = config.model or "claude-3-5-haiku-20241022"
  instance.max_tool_rounds = config.max_tool_rounds or 5
  instance.max_tokens = config.max_tokens or 8192
  instance.max_history_entries = config.max_history_entries
  instance.project_root = config.project_root or vim.fn.getcwd()
  instance.system_instruction = config.system_instruction
    or (prompts.load("system.txt"):gsub("{{PROJECT_ROOT}}", instance.project_root))
  return instance
end

function Claude:_name()
  return "Claude"
end

function Claude:_check_api_key(callbacks)
  if not self.api_key or self.api_key == "" then
    if callbacks.on_error then
      callbacks.on_error("ANTHROPIC_API_KEY is not set. Set the environment variable or pass api_key in setup().")
    end
    return false
  end
  return true
end

function Claude:_build_request(state)
  local body = {
    model = self.model,
    max_tokens = state.max_tokens or self.max_tokens,
    system = state.system_instruction or self.system_instruction,
    messages = state.messages,
  }
  if #state.tool_defs > 0 then
    body.tools = state.tool_defs
  end
  return {
    url = "https://api.anthropic.com/v1/messages",
    body = body,
    headers = {
      ["x-api-key"] = self.api_key,
      ["anthropic-version"] = "2023-06-01",
    },
  }
end

function Claude:_parse_response(response)
  if response.type == "error" then
    return nil, (response.error and response.error.message or "unknown")
  end

  local content = response.content
  if not content or #content == 0 then
    return nil, "empty response"
  end

  local text_parts = {}
  local tool_calls = {}

  for _, block in ipairs(content) do
    if block.type == "text" then
      table.insert(text_parts, block.text)
    elseif block.type == "tool_use" then
      table.insert(tool_calls, {
        name = block.name,
        args = block.input or {},
        id = block.id,
      })
    end
  end

  if #text_parts == 0 and #tool_calls == 0 then
    return nil, "empty response"
  end

  local text = #text_parts > 0 and table.concat(text_parts, "\n") or nil
  return { text = text, tool_calls = #tool_calls > 0 and tool_calls or nil }, nil
end

function Claude:_build_assistant_message(response)
  return {
    role = "assistant",
    content = response.content,
  }
end

function Claude:_build_user_message(text)
  return {
    role = "user",
    content = { { type = "text", text = text } },
  }
end

function Claude:_build_history(history)
  local messages = {}
  if history and history._entries then
    local entries = history._entries
    if self.max_history_entries and #entries > self.max_history_entries then
      local start = #entries - self.max_history_entries + 1
      entries = {}
      for i = start, #history._entries do
        table.insert(entries, history._entries[i])
      end
    end
    for _, entry in ipairs(entries) do
      local text = table.concat(entry.lines, "\n")
      table.insert(messages, {
        role = entry.role,
        content = { { type = "text", text = text } },
      })
    end
  end
  return messages
end

function Claude:_build_tool_result(tc, ok, result)
  return {
    type = "tool_result",
    tool_use_id = tc.id,
    content = { { type = "text", text = ok and tostring(result) or "Error: " .. tostring(result) } },
  }
end

function Claude:_build_tool_results_message(results)
  return {
    role = "user",
    content = results,
  }
end

function Claude:_convert_tools(tool_defs)
  local converted = {}
  for _, def in ipairs(tool_defs) do
    table.insert(converted, {
      name = def.name,
      description = def.description,
      input_schema = def.parameters,
    })
  end
  return converted
end

return Claude
