local health = vim.health or require("health")

local env_vars = {
  gemini = "GEMINI_API_KEY",
  claude = "ANTHROPIC_API_KEY",
}

local function check()
  health.start("bufferbuddy")

  local ok, llm = pcall(require, "bufferbuddy.access.llm")
  if not ok then
    health.error("Failed to load bufferbuddy.access.llm: " .. tostring(llm))
    return
  end

  local initialized = llm.initialized

  if not initialized then
    health.warn("bufferbuddy.setup() has not been called yet. "
      .. "Showing default configuration — results may not reflect your settings.")
  end

  local provider = llm.config and llm.config.provider or "gemini"
  local model = llm.config and llm.config.model
  local env_var = env_vars[provider]

  health.ok("Provider: " .. provider)

  if model and model ~= "" then
    local prefix = provider == "claude" and "gemini" or "claude"
    if model:find("^" .. prefix) then
      health.warn("Model '" .. model .. "' looks like a " .. prefix .. " model but provider is " .. provider)
    else
      health.ok("Model: " .. model)
    end
  else
    health.warn("Model is not set. Set `model` in bufferbuddy.setup().")
  end

  do
    local api_key = llm.config and llm.config.api_key
    if not api_key or api_key == "" then
      api_key = os.getenv(env_var)
    end
    if api_key and api_key ~= "" then
      local masked = api_key:sub(1, 8) .. string.rep("*", #api_key - 8)
      health.ok("API key found: " .. masked)
    else
      health.error("No API key found. "
        .. "Set `api_key` in bufferbuddy.setup() or the " .. env_var .. " environment variable.")
    end
  end

  do
    if vim.fn.executable("rg") == 1 then
      local version = vim.fn.system({ "rg", "--version" }):match("ripgrep ([%d.]+)")
      health.ok("ripgrep installed" .. (version and " (" .. version .. ")" or ""))
    else
      health.warn("ripgrep (rg) is not installed. The rg tool will not work.")
    end
  end

  do
    if vim.fn.executable("ast-grep") == 1 then
      local version = vim.fn.system({ "ast-grep", "--version" }):match("ast%-grep ([%d.]+)")
      health.ok("ast-grep installed" .. (version and " (" .. version .. ")" or ""))
    else
      health.warn("ast-grep (sg) is not installed. The ast-grep tool will not work.")
    end
  end
end

return vim.health and { check = check } or { check = check }
