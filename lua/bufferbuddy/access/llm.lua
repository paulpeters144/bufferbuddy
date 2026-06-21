local logger = require("bufferbuddy.logger")
local Tools = require("bufferbuddy.tools")

require("bufferbuddy.tools.rg")
require("bufferbuddy.tools.ast_grep")
require("bufferbuddy.tools.find_definitions")

local M = {
  config = {
    provider = "gemini",
    model = nil,
    max_tool_rounds = 15,
    max_tokens = nil,
    max_history_entries = 20,
    api_key = nil,
  },
  initialized = false,
}

local provider = nil

local default_models = {
  gemini = "gemini-3.1-flash-lite",
  claude = "claude-3-5-haiku-20241022",
}

function M.setup(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
  M.initialized = true
  if not M.config.model then
    M.config.model = default_models[M.config.provider]
  end
  logger.info("LLM configured with provider:", M.config.provider)
end

local function augment_with_context(message, context)
  local ctx_parts = {}

  context = context or {}

  if context.filepath then
    table.insert(ctx_parts, "[File: " .. context.filepath .. "]")
  end

  if context.visible_lines then
    table.insert(
      ctx_parts,
      "[Visible lines: " .. context.visible_lines.top .. "-" .. context.visible_lines.bottom .. "]"
    )
  end

  if #ctx_parts > 0 then
    return table.concat(ctx_parts, "\n") .. "\n\n" .. message
  end
  return message
end

function M.chat_completion(params)
  if not provider then
    local Provider = require("bufferbuddy.access.providers." .. M.config.provider)
    provider = Provider:new({
      api_key = M.config.api_key,
      model = M.config.model,
      max_tool_rounds = M.config.max_tool_rounds,
      max_tokens = M.config.max_tokens,
      max_history_entries = M.config.max_history_entries,
      project_root = vim.fn.getcwd(),
    })
  end

  local user_message = augment_with_context(params.user_message, params.context)

  provider:chat_completion({
    user_message = user_message,
    history = params.history,
    callbacks = params.callbacks,
    tools = params.no_tools and nil or Tools,
    system_instruction = params.system_instruction,
    max_tokens = params.max_tokens,
  })
end

return M
