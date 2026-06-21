local logger = require("bufferbuddy.logger")
logger.config.loglevel = "debug"
local registry = {}

function registry:register(name, definition, handler)
  self[name] = {
    definition = definition,
    handler = handler,
  }
  logger.debug("Tool registered:", name)
end

function registry:get_definitions()
  local defs = {}
  for _, tool in pairs(self) do
    if type(tool) == "table" and tool.definition then
      table.insert(defs, tool.definition)
    end
  end
  return defs
end

function registry:execute(name, args)
  local tool = self[name]
  if not tool then
    return "Error: Unknown tool '" .. tostring(name) .. "'"
  end
  logger.info("Executing tool:", name, args)
  local ok, result = pcall(tool.handler, args)
  if not ok then
    logger.error("Tool execution failed:", name, result)
    return "Error executing " .. name .. ": " .. tostring(result)
  end
  return result
end

return registry
