local M = {
  config = {
    testing = false,
    loglevel = "warn",
  },
}

local log_path = vim.fn.stdpath("data") .. "/bufferbuddy.log"

--- @param level string
--- @return boolean
local function allow_log_level(level)
  local levels = { debug = 1, info = 2, warn = 3, error = 4 }
  assert(levels[level], "Invalid log level: " .. tostring(level))

  local current = levels[M.config.loglevel]
  if current == nil then
    return false
  end

  return levels[level] >= current
end

--- @return string
local function get_timestamp()
  local date = os.date("%Y-%m-%d %H:%M:%S")
  return tostring(date)
end

--- @param ... any
--- @return ...any
local function to_json(...)
  local args = { ... }
  for i, v in ipairs(args) do
    if type(v) == "table" then
      args[i] = vim.json.encode(v)
    end
  end
  return unpack(args)
end

--- @param prefix string
--- @param ... any
--- @return string
local function write_out(prefix, ...)
  local data = prefix .. table.concat({ ... }, "\t") .. "\n"

  if not M.config.testing then
    vim.fn.mkdir(vim.fn.stdpath("data"), "p")
    local file = io.open(log_path, "a")
    if file then
      file:write(data)
      file:close()
    end
  end

  return data
end

function M.debug(...)
  if not allow_log_level("debug") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [DEBUG] "
  return write_out(prefix, to_json(...))
end

function M.info(...)
  if not allow_log_level("info") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [INFO] "
  return write_out(prefix, to_json(...))
end

function M.warn(...)
  if not allow_log_level("warn") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [WARN] "
  return write_out(prefix, to_json(...))
end

function M.error(...)
  if not allow_log_level("error") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [ERROR] "
  return write_out(prefix, to_json(...))
end

return M
