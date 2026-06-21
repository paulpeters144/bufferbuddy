local logger = require("bufferbuddy.logger")

local M = {}

local function handle_response(url, response, callback)
  if not response or not response.status then
    local err = "HTTP request failed: no response from " .. url
    if callback then
      callback(nil, err)
    end
    return nil, err
  end

  if response.status >= 400 then
    local err_msg = "HTTP " .. response.status
    if response.body then
      local ok2, decoded = pcall(vim.json.decode, response.body)
      if ok2 and decoded.error then
        err_msg = err_msg .. ": " .. (decoded.error.message or decoded.error.status or response.body)
      else
        err_msg = err_msg .. ": " .. response.body
      end
    end
    logger.error("HTTP POST failed:", url, err_msg)
    if callback then
      callback(nil, err_msg)
    end
    return nil, err_msg
  end

  if not response.body or response.body == "" then
    local err = "Empty response from " .. url
    if callback then
      callback(nil, err)
    end
    return nil, err
  end

  local ok3, decoded = pcall(vim.json.decode, response.body)
  if not ok3 then
    logger.error("JSON decode failed:", response.body)
    local err = "Failed to parse response JSON"
    if callback then
      callback(nil, err)
    end
    return nil, err
  end

  if callback then
    callback(decoded, nil)
  end
  return decoded, nil
end

function M.post(url, body, opts)
  opts = opts or {}
  local headers = opts.headers or {}
  local callback = opts.callback
  if not headers["Content-Type"] then
    headers["Content-Type"] = "application/json"
  end

  local ok, curl = pcall(require, "plenary.curl")
  if not ok then
    local err = "plenary.nvim is required. Install it and restart Neovim."
    if callback then
      callback(nil, err)
      return
    end
    return nil, err
  end

  local curl_opts = {
    body = vim.json.encode(body),
    headers = headers,
    timeout = 60000,
  }

  if callback then
    curl.post(url, vim.tbl_extend("keep", curl_opts, { callback = function(response)
      handle_response(url, response, callback)
    end }))
  else
    local response = curl.post(url, curl_opts)
    return handle_response(url, response, nil)
  end
end

return M
