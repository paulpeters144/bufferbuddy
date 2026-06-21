local Provider = require("bufferbuddy.access.provider")
local prompts = require("bufferbuddy.prompt")

local Gemini = setmetatable({}, Provider)
Gemini.__index = Gemini

function Gemini:new(config)
  config = config or {}
  local instance = setmetatable({}, Gemini)
  instance.api_key = config.api_key or os.getenv("GEMINI_API_KEY")
  instance.model = config.model or "gemini-3.1-flash-lite"
  instance.max_tool_rounds = config.max_tool_rounds or 5
  instance.project_root = config.project_root or vim.fn.getcwd()
  instance.system_instruction = config.system_instruction
    or (prompts.load("system.txt"):gsub("{{PROJECT_ROOT}}", instance.project_root))
  return instance
end

function Gemini:_name()
  return "Gemini"
end

function Gemini:_check_api_key(callbacks)
  if not self.api_key or self.api_key == "" then
    if callbacks.on_error then
      callbacks.on_error("GEMINI_API_KEY is not set. Set the environment variable or pass api_key in setup().")
    end
    return false
  end
  return true
end

function Gemini:_build_request(state)
  local gemini_contents = {}
  for _, msg in ipairs(state.messages) do
    if msg.role == "user" then
      table.insert(gemini_contents, {
        role = "user",
        parts = { { text = msg.text } },
      })
    elseif msg.role == "assistant" then
      local parts = {}
      if msg.text then
        table.insert(parts, { text = msg.text })
      end
      if msg.tool_calls then
        for _, tc in ipairs(msg.tool_calls) do
          table.insert(parts, {
            functionCall = { name = tc.name, args = tc.args },
          })
        end
      end
      table.insert(gemini_contents, { role = "model", parts = parts })
    elseif msg.role == "tool" then
      local parts = {}
      for _, tr in ipairs(msg.tool_results) do
        table.insert(parts, {
          functionResponse = {
            name = tr.name,
            response = tr.ok and { result = tr.result } or { error = tostring(tr.result) },
          },
        })
      end
      table.insert(gemini_contents, { role = "user", parts = parts })
    end
  end

  local body = {
    system_instruction = {
      parts = { { text = state.system_instruction or self.system_instruction } },
    },
    contents = gemini_contents,
  }

  if #state.tool_defs > 0 then
    body.tools = { {
      functionDeclarations = state.tool_defs,
    } }
  end

  return {
    url = string.format(
      "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
      self.model,
      self.api_key
    ),
    body = body,
  }
end

function Gemini:_parse_response(response)
  local candidate = response.candidates and response.candidates[1]
  if not candidate then
    local reason = "unknown"
    if response.promptFeedback then
      reason = response.promptFeedback.blockReason or "blocked"
    end
    return nil, "blocked: " .. reason
  end

  local content = candidate.content
  if not content or not content.parts or #content.parts == 0 then
    return nil, "empty response"
  end

  local text_parts = {}
  local tool_calls = {}

  for _, part in ipairs(content.parts) do
    if part.text then
      table.insert(text_parts, part.text)
    elseif part.functionCall then
      local fc = part.functionCall
      local tc = {
        name = fc.name,
        args = fc.args or {},
        id = fc.name,
      }
      local ts = fc.thoughtSignature or fc.thought_signature or part.thoughtSignature or part.thought_signature
      if ts then
        tc.thought_signature = ts
      end
      table.insert(tool_calls, tc)
    end
  end

  if #text_parts == 0 and #tool_calls == 0 then
    return nil, "empty response"
  end

  local text = #text_parts > 0 and table.concat(text_parts, "\n") or nil
  return { text = text, tool_calls = #tool_calls > 0 and tool_calls or nil }, nil
end

return Gemini
