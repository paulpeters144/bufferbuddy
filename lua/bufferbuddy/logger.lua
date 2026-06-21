local M = {
  config = {
    testing = false,
    loglevel = "warn", -- "debug", "info", "warn", "error"
  },
}

local log_dir = vim.fn.stdpath("data")
local log_path = log_dir .. "/bufferbuddy.log"
local dir_ready = false

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
  local date = os.date("%Y%m%d %H:%M:%S")
  return tostring(date)
end

--- @param ... any
--- @return string
local function to_json(...)
  local args = { ... }
  for i, v in ipairs(args) do
    if type(v) == "table" then
      args[i] = vim.json.encode(v, { indent = "  " })
    end
  end
  return table.concat(args, " ")
end

--- @param prefix string
--- @param data string
--- @return string
local function write_out(prefix, data)
  data = prefix .. data .. "\n"

  if not M.config.testing then
    if not dir_ready then
      pcall(vim.uv.fs_mkdir, log_dir, 493)
      dir_ready = true
    end
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
  local data = to_json(...)
  return write_out(prefix, data)
end

function M.info(...)
  if not allow_log_level("info") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [INFO] "
  local data = to_json(...)
  return write_out(prefix, data)
end

function M.warn(...)
  if not allow_log_level("warn") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [WARN] "
  local data = to_json(...)
  return write_out(prefix, data)
end

function M.error(...)
  if not allow_log_level("error") then
    return ""
  end
  local datetime = get_timestamp()
  local prefix = datetime .. " [ERROR] "
  local data = to_json(...)
  return write_out(prefix, data)
end

return M
