local tools = require("bufferbuddy.tools")

tools:register("rg", {
  name = "rg",
  description = "Search file contents by text or regex pattern using ripgrep. "
    .. "Good for finding usages, function calls, imports, and any text string. "
    .. "For definitions/declarations by syntactic structure, use ast-grep instead.",
  parameters = {
    type = "object",
    properties = {
      pattern = {
        type = "string",
        description = "The regex search pattern",
      },
      path = {
        type = "string",
        description = "Directory path to search in (default: current working directory)",
      },
      glob = {
        type = "string",
        description = "File glob to filter (e.g. '*.lua', '*.{ts,js}')",
      },
    },
    required = { "pattern" },
  },
}, function(args)
  if vim.fn.executable("rg") == 0 then
    return "Error: ripgrep (rg) is not installed. Install it first."
  end

  local cmd = { "rg", "--json", "-n", "--color", "never" }

  if args.glob then
    table.insert(cmd, "--glob")
    table.insert(cmd, args.glob)
  end

  table.insert(cmd, args.pattern)
  table.insert(cmd, args.path or ".")

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code > 1 then
    return "Error: rg exited with code " .. exit_code .. ": " .. output
  end

  local results = {}
  local count = 0
  for line in output:gmatch("[^\n]+") do
    local ok, parsed = pcall(vim.json.decode, line)
    if ok and parsed.type == "match" then
      count = count + 1
      local data = parsed.data
      local fpath = data.path and data.path.text or "?"
      local line_num = data.line_number or 0
      local text = data.lines and data.lines.text or ""
      table.insert(results, string.format("%s:%d: %s", fpath, line_num, text:gsub("^%s+", "")))
    end
  end

  local max_results = 50
  local truncated = #results > max_results
  if truncated then
    for i = max_results + 1, #results do
      results[i] = nil
    end
  end

  if count == 0 then
    if exit_code == 1 then
      return "No matches found for pattern: " .. args.pattern
    end
    return "No results"
  end

  table.insert(results, 1, string.format("Found %d match(s):", count))
  if truncated then
    table.insert(results, string.format("(showing first %d of %d matches, truncated)", max_results, count))
  end
  return table.concat(results, "\n")
end)
