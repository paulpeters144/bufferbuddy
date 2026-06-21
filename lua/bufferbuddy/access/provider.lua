local http = require("bufferbuddy.access.http")
local logger = require("bufferbuddy.logger")

---@class Provider
---@field config table
---@field api_key string|nil
---@field model string
---@field max_tool_rounds number
---@field max_tokens number|nil
---@field project_root string
---@field system_instruction string|nil
local Provider = {}
Provider.__index = Provider

function Provider:new(config)
  local instance = setmetatable({}, Provider)
  instance.config = config or {}
  return instance
end

function Provider:_name()
  return "Provider"
end

---@param state table
function Provider:_error(state, msg)
  if state.callbacks and state.callbacks.on_error then
    state.callbacks.on_error(msg)
  end
end

---@param params {
---  user_message: string,
---  history?: table,
---  callbacks?: table,
---  tools?: table,
---  system_instruction?: string,
---  max_tokens?: number }
function Provider:chat_completion(params)
  local user_message = params.user_message
  local history = params.history
  local callbacks = params.callbacks or {}
  local tools = params.tools
  local system_instruction = params.system_instruction
  local max_tokens = params.max_tokens

  if not self:_check_api_key(callbacks) then
    return
  end

  local messages = self:_build_history(history)
  table.insert(messages, self:_build_user_message(user_message))
  local tool_defs = tools and self:_convert_tools(tools:get_definitions()) or {}

  vim.schedule(function()
    self:_tool_loop({
      messages = messages,
      tool_defs = tool_defs,
      tools = tools,
      callbacks = callbacks,
      round = 0,
      system_instruction = system_instruction,
      max_tokens = max_tokens,
    })
  end)
end

---@param state { round: number, messages: table[], tool_defs: table[], callbacks: table, tools: table|nil }
function Provider:_tool_loop(state)
  state.round = state.round + 1

  if state.round > self.max_tool_rounds then
    self:_error(state, "Max tool call rounds reached (" .. self.max_tool_rounds .. ")")
    return
  end

  local req = self:_build_request(state)

  logger.debug(self:_name() .. " request body:", vim.inspect(req.body))

  http.post(req.url, req.body, {
    headers = req.headers,
    callback = function(response, err)
      vim.schedule(function()
        if not response then
          self:_error(state, self:_name() .. " API error: " .. (err or "unknown error"))
          return
        end

        local result, parse_err = self:_parse_response(response)
        if not result then
          self:_error(state, self:_name() .. " error: " .. parse_err)
          return
        end

        if result.tool_calls and #result.tool_calls > 0 then
          table.insert(state.messages, self:_build_assistant_message(response))

          local results = {}
          for _, tc in ipairs(result.tool_calls) do
            logger.info(self:_name() .. " tool called:", tc.name, tc.args)

            if state.callbacks.on_tool_call then
              state.callbacks.on_tool_call(tc.name, tc.args or {})
            end

            local ok, res
            if state.tools then
              ok, res = pcall(state.tools.execute, state.tools, tc.name, tc.args or {})
            else
              ok, res = false, "No tools available"
            end

            local MAX_TOOL_OUTPUT = 3000
            if ok and type(res) == "string" and #res > MAX_TOOL_OUTPUT then
              res = res:sub(1, MAX_TOOL_OUTPUT) .. "\n... (output truncated to " .. MAX_TOOL_OUTPUT .. " chars)"
            end

            table.insert(results, self:_build_tool_result(tc, ok, res))
          end

          table.insert(state.messages, self:_build_tool_results_message(results))

          local MAX_TOOL_PAIRS = 4
          local max_messages = 1 + (MAX_TOOL_PAIRS * 2)
          if #state.messages > max_messages then
            local pairs_to_remove = (#state.messages - max_messages) / 2
            for _ = 1, pairs_to_remove do
              table.remove(state.messages, 2)
              table.remove(state.messages, 2)
            end
          end

          self:_tool_loop(state)
        elseif result.text and state.callbacks.on_result then
          state.callbacks.on_result(result.text)
        end
      end)
    end,
  })
end

function Provider:_check_api_key(_callbacks)
  return true
end

function Provider:_build_request(_state)
  error("Subclasses must implement _build_request")
end

function Provider:_parse_response(_response)
  error("Subclasses must implement _parse_response")
end

function Provider:_build_assistant_message(_response)
  error("Subclasses must implement _build_assistant_message")
end

function Provider:_build_user_message(_text)
  error("Subclasses must implement _build_user_message")
end

function Provider:_build_history(_history)
  error("Subclasses must implement _build_history")
end

function Provider:_build_tool_result(_tc, _ok, _result)
  error("Subclasses must implement _build_tool_result")
end

function Provider:_build_tool_results_message(_results)
  error("Subclasses must implement _build_tool_results_message")
end

function Provider:_convert_tools(_definitions)
  error("Subclasses must implement _convert_tools")
end

return Provider
