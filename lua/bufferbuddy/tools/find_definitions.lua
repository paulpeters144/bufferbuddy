local tools = require("bufferbuddy.tools")

local PATTERNS = {
  ["function"] = {
    lua = "function $NAME($$$)",
    python = "def $NAME($$$):",
    js = "function $NAME($$$) { $$$ }",
    ts = "function $NAME($$$) { $$$ }",
    tsx = "function $NAME($$$) { $$$ }",
    jsx = "function $NAME($$$) { $$$ }",
    go = "func $NAME($$$) { $$$ }",
    rust = "fn $NAME($$$)",
    java = "function $NAME($$$) { $$$ }",
    cpp = "function $NAME($$$) { $$$ }",
    c = "function $NAME($$$) { $$$ }",
  },
  ["class"] = {
    python = "class $NAME:",
    js = "class $NAME { $$$ }",
    ts = "class $NAME { $$$ }",
    tsx = "class $NAME { $$$ }",
    jsx = "class $NAME { $$$ }",
    go = "type $NAME struct { $$$ }",
    rust = "struct $NAME { $$$ }",
    java = "class $NAME { $$$ }",
    cpp = "class $NAME { $$$ }",
  },
}

local function detect_language_from_path(path)
  local ext = path:match("%.([^./]+)$")
  local ext_map = {
    lua = "lua",
    py = "python",
    js = "js",
    ts = "ts",
    tsx = "tsx",
    jsx = "jsx",
    go = "go",
    rs = "rust",
    java = "java",
    cpp = "cpp",
    c = "c",
    h = "c",
    hpp = "cpp",
  }
  return ext_map[ext]
end

local function build_astgrep_cmd(kind, language, path)
  local pattern = PATTERNS[kind][language]
  if not pattern then
    return nil, string.format("No pattern defined for kind '%s' with language '%s'", kind, language or "?")
  end

  local cmd = { "ast-grep", "--json" }
  if language then
    table.insert(cmd, "--lang")
    table.insert(cmd, language)
  end
  table.insert(cmd, "-p")
  table.insert(cmd, pattern)
  table.insert(cmd, path or ".")

  return cmd, nil
end

local function name_matches_filter(text, filter)
  if not filter or filter == "" then
    return true
  end
  if filter:sub(1, 1) == "*" and filter:sub(-1) == "*" then
    local substr = filter:sub(2, -2)
    return text:find(substr, 1, true) ~= nil
  elseif filter:sub(1, 1) == "*" then
    local suffix = filter:sub(2)
    return text:sub(-#suffix) == suffix
  elseif filter:sub(-1) == "*" then
    local prefix = filter:sub(1, -2)
    return text:sub(1, #prefix) == prefix
  else
    return text:find(filter, 1, true) ~= nil
  end
end

local function execute_astgrep(cmd)
  if vim.fn.executable("ast-grep") == 0 then
    return nil, "ast-grep (sg) is not installed."
  end

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    return nil, "ast-grep exited with code " .. exit_code .. ": " .. output
  end

  local ok, parsed = pcall(vim.json.decode, output)
  if not ok then
    return nil, nil
  end

  return parsed, nil
end

tools:register("find_definitions", {
  name = "find_definitions",
  description = "Find function/class/method definitions by syntactic structure "
    .. "using ast-grep. PREFER this over rg for definitions or declarations. "
    .. "Specify the kind and optional name filter.",
  parameters = {
    type = "object",
    properties = {
      kind = {
        type = "string",
        description = "Kind of definition: 'function' (function/method), 'class' (class/struct)",
        enum = { "function", "class" },
      },
      name = {
        type = "string",
        description = "Name pattern to filter by. Supports: 'foo*' (starts with), "
          .. "'*foo' (ends with), '*foo*' (contains), 'foo' (substring). "
          .. "Examples: 'get_*', '*Handler'.",
      },
      language = {
        type = "string",
        description = "Language ('lua', 'python', 'js', 'ts', 'go', 'rust'). "
          .. "Auto-detected from file extension if omitted.",
      },
      path = {
        type = "string",
        description = "Directory path to search in (default: project root)",
      },
    },
    required = { "kind" },
  },
}, function(args)
  local kind = args.kind
  local name_filter = args.name
  local path_arg = args.path or "."
  local language = args.language

  if not language then
    language = detect_language_from_path(path_arg)
  end
  language = language or "lua"

  local cmd, err = build_astgrep_cmd(kind, language, path_arg)
  if err then
    return err
  end

  local results; results, err = execute_astgrep(cmd)
  if err then
    return err
  end
  if not results then
    return "No results or failed to parse output"
  end

  local lines = {}
  local count = 0
  for _, item in ipairs(results) do
    local fpath = item.path or "?"
    local line = item.line or 0
    local col = item.column or 0
    local text_val = item.text or ""

    if name_filter then
      if not name_matches_filter(text_val, name_filter) then
        goto continue
      end
    end

    count = count + 1
    table.insert(lines, string.format("%s:%d:%d: %s", fpath, line, col, text_val))
    ::continue::
  end

  if count == 0 then
    return string.format("No %s definitions found matching the criteria", kind)
  end

  local max_results = 50
  local truncated = #lines > max_results
  if truncated then
    for i = max_results + 1, #lines do
      lines[i] = nil
    end
  end

  table.insert(lines, 1, string.format("Found %d %s definition(s):", count, kind))
  if truncated then
    table.insert(lines, string.format("(showing first %d of %d matches, truncated)", max_results, count))
  end
  return table.concat(lines, "\n")
end)
