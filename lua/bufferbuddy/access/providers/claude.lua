local Provider = require("bufferbuddy.access.provider")
local prompts = require("bufferbuddy.prompt")
local project = require("bufferbuddy.project")

---@class Claude: Provider
---@field max_history_entries number|nil
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
  local root = project.summarize(instance.project_root) or ""
  instance.system_instruction = config.system_instruction
    or (prompts.load("system.txt"):gsub("{{PROJECT_ROOT}}", root):gsub("\n\n\n+", "\n\n"))
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
  local claude_messages = {}
  for _, msg in ipairs(state.messages) do
    if msg.role == "user" then
      table.insert(claude_messages, {
        role = "user",
        content = { { type = "text", text = msg.text } },
      })
    elseif msg.role == "assistant" then
      local content = {}
      if msg.text then
        table.insert(content, { type = "text", text = msg.text })
      end
      if msg.tool_calls then
        for _, tc in ipairs(msg.tool_calls) do
          table.insert(content, {
            type = "tool_use",
            id = tc.id,
            name = tc.name,
            input = tc.args,
          })
        end
      end
      table.insert(claude_messages, { role = "assistant", content = content })
    elseif msg.role == "tool" then
      local tool_content = {}
      for _, tr in ipairs(msg.tool_results) do
        table.insert(tool_content, {
          type = "tool_result",
          tool_use_id = tr.id,
          content = { { type = "text", text = tr.ok and tostring(tr.result) or "Error: " .. tostring(tr.result) } },
        })
      end
      table.insert(claude_messages, { role = "user", content = tool_content })
    end
  end

  local body = {
    model = self.model,
    max_tokens = state.max_tokens or self.max_tokens,
    system = state.system_instruction or self.system_instruction,
    messages = claude_messages,
  }

  if #state.tool_defs > 0 then
    body.tools = {}
    for _, def in ipairs(state.tool_defs) do
      table.insert(body.tools, {
        name = def.name,
        description = def.description,
        input_schema = def.parameters,
      })
    end
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

return Claude
