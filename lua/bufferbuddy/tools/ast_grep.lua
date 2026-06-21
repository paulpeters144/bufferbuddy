local tools = require("bufferbuddy.tools")
local util = require("bufferbuddy.tools.util")

tools:register("ast-grep", {
  name = "ast-grep",
  description = "Search code by syntactic structure using AST patterns. "
    .. "Use this for finding definitions (function, class, method) "
    .. "and structural patterns — things regex can't reliably match. "
    .. "Supports `$` variables. "
    .. "Examples: 'function $NAME($PARAMS)' finds function definitions; "
    .. "'class $NAME { $BODY }' finds class definitions.",
  parameters = {
    type = "object",
    properties = {
      pattern = {
        type = "string",
        description = "The AST pattern (e.g. 'console.log($ARG)' or 'function $NAME($PARAMS) { $BODY }')",
      },
      language = {
        type = "string",
        description = "Language filter (e.g. 'lua', 'python', 'js'). Detects from extension if omitted.",
      },
      path = {
        type = "string",
        description = "Directory path to search in (default: current working directory)",
      },
    },
    required = { "pattern" },
  },
}, function(args)
  if vim.fn.executable("ast-grep") == 0 then
    return "Error: ast-grep (sg) is not installed. Install it first."
  end

  local cmd = { "ast-grep", "--json" }

  if args.language then
    table.insert(cmd, "--lang")
    table.insert(cmd, args.language)
  end

  table.insert(cmd, "-p")
  table.insert(cmd, args.pattern)
  table.insert(cmd, args.path or ".")

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    return "Error: ast-grep exited with code " .. exit_code .. ": " .. output
  end

  local ok, parsed = pcall(vim.json.decode, output)
  if not ok then
    return "No results or failed to parse output"
  end

  local lines = {}
  local count = 0
  for _, item in ipairs(parsed) do
    count = count + 1
    local fpath = item.path or "?"
    local line = item.line or 0
    local col = item.column or 0
    local text = item.text or ""
    table.insert(lines, string.format("%s:%d:%d: %s", fpath, line, col, text))
  end

  if count == 0 then
    return "No matches found for pattern: " .. args.pattern
  end

  table.insert(lines, 1, string.format("Found %d match(s):", count))
  local result = table.concat(lines, "\n")
  local tail_msg = "(Results truncated. Consider using a more specific path or pattern.)"
  return util.truncate(result, 50, tail_msg)
end)
