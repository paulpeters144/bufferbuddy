local LLM = require("bufferbuddy.access.llm")
local logger = require("bufferbuddy.logger")
local prompts = require("bufferbuddy.prompt")
local Spinner = require("bufferbuddy.ui.spinner")
local InlineInputWindow = require("bufferbuddy.ui.inline-input-window")
local util = require("bufferbuddy.ui.util")

vim.api.nvim_set_hl(0, "BufferBuddySpinner", { fg = "#89b4fa", bg = "#313244", bold = true })

local editing_guard = false

local PATTERNS = {
  function_def = {
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
  class_def = {
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

local EXT_TO_LANG = {
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

local InlineEdit = {}
InlineEdit.__index = InlineEdit

function InlineEdit:new(opts)
  local instance = setmetatable({}, InlineEdit)
  instance.source_buf = opts.buf
  instance.source_path = vim.api.nvim_buf_get_name(opts.buf)
  instance.start_line = opts.start_line
  instance.end_line = opts.end_line
  instance.lines = nil
  instance.input_window = nil
  instance.spinner = Spinner:new()
  return instance
end

function InlineEdit:open()
  if editing_guard then
    vim.notify("Edit already in progress", vim.log.levels.WARN)
    return
  end
  editing_guard = true

  self:_expand_selection()

  self.lines = vim.api.nvim_buf_get_lines(self.source_buf, self.start_line - 1, self.end_line, false)
  if not self.lines or #self.lines == 0 then
    editing_guard = false
    return
  end

  self.input_window = InlineInputWindow:new({
    title = " Edit instruction ",
    prompt = "Describe the edit you want to make:",
    width = math.min(80, vim.o.columns - 4),
    on_submit = function(text)
      self:_submit(text)
    end,
    on_cancel = function()
      self:_cancel()
    end,
  })
  self.input_window:open()
end

function InlineEdit:_submit(instruction)
  self.input_window:close()
  util.force_mode(vim, "normal")
  self.input_window = nil

  -- Defer spinner creation so the input window is fully closed and cursor is settled
  vim.schedule(function()
    self:_show_spinner()
  end)

  local code_text = table.concat(self.lines, "\n")

  local template = prompts.load("inline-edit.txt")
  if self.source_path and self.source_path ~= "" then
    template = template:gsub("{{FILEPATH}}", self.source_path)
  else
    template = template:gsub("File: {{FILEPATH}}\n\n", "")
  end
  template = template:gsub("{{CODE}}", code_text)
  template = template:gsub("{{INSTRUCTION}}", instruction)

  LLM.chat_completion({
    user_message = template,
    system_instruction = prompts.load("inline-edit-system.txt"),
    max_tokens = 1024,
    callbacks = {
      on_result = function(text)
        self:_handle_result(text)
      end,
      on_error = function(err)
        self:_handle_error(err)
      end,
    },
  })
end

function InlineEdit:_strip_prose(code)
  local code_keywords = {
    "local", "function", "if", "for", "while", "return", "end", "do",
    "repeat", "until", "class", "def", "import", "export", "const", "let",
    "var", "type", "struct", "pub", "fn", "use", "mod", "package",
    "try", "catch", "except",
  }

  local function is_code(line)
    local s = line:match("^%s*(.-)%s*$")
    if s == "" then return false end
    for _, kw in ipairs(code_keywords) do
      if s == kw or s:find("^" .. kw .. "[%s%(]") then
        return true
      end
    end
    if s:match("^[%w_$@.]+%s*[=%(]") then return true end
    if s:match("^[%w_$@.]+:[%w_]+%(?") then return true end
    if s:match("^%-%-") then return true end
    if s:match("^#") then return true end
    if s:match("^//") then return true end
    return false
  end

  local lines = {}
  for line in code:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  local head = 1
  while head <= #lines and not is_code(lines[head]) do
    head = head + 1
  end

  if head > #lines then
    return code
  end

  code = table.concat(lines, "\n", head, #lines)
  code = code:gsub("^\n+", ""):gsub("\n+$", "")
  return code
end

function InlineEdit:_handle_result(text)
  self:_stop_spinner()
  editing_guard = false

  if not vim.api.nvim_buf_is_valid(self.source_buf) then
    vim.notify("Edit failed: buffer no longer exists", vim.log.levels.ERROR)
    return
  end

  local code = text

  local fenced = code:match("```[%w]*\n(.-)\n```")
  if fenced and fenced ~= "" then
    code = fenced
  else
    code = code:gsub("^```[a-zA-Z]*\n", "")
    code = code:gsub("\n```$", "")
    code = code:gsub("^```\n", "")
    code = code:gsub("\n```$", "")
  end

  logger.info("LLM raw response text:", "\n" .. code)
  local stripped = self:_strip_prose(code)
  if stripped ~= code then
    logger.info("Stripped non-code preamble. Before:", #code, "bytes, after:", #stripped, "bytes")
    vim.notify("Warning: stripped non-code text from LLM response", vim.log.levels.WARN)
  end
  code = stripped

  if code == "" then
    vim.notify("Edit failed: LLM returned empty response after stripping non-code text", vim.log.levels.ERROR)
    return
  end

  local line_count = vim.api.nvim_buf_line_count(self.source_buf)
  local safe_start = math.max(0, self.start_line - 1)
  local safe_end = math.min(self.end_line, line_count)

  local new_lines = vim.split(code, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(self.source_buf, safe_start, safe_end, false, new_lines)
  vim.cmd("write")
end

function InlineEdit:_handle_error(err)
  self:_stop_spinner()
  editing_guard = false
  vim.notify("Edit failed: " .. tostring(err), vim.log.levels.ERROR)
end

function InlineEdit:_cancel()
  editing_guard = false
  if self.input_window then
    self.input_window:close()
    self.input_window = nil
  end
end

function InlineEdit:_expand_selection()
  if vim.fn.executable("ast-grep") == 0 then
    return
  end

  if not self.source_path or self.source_path == "" then
    return
  end

  local language = self:_detect_language(self.source_path)
  if not language then
    return
  end

  local sel_start = self.start_line
  local sel_end = self.end_line
  local candidates = {}

  for _, kind in ipairs({ "function_def", "class_def" }) do
    local pattern = PATTERNS[kind][language]
    if pattern then
      local results = self:_run_astgrep(pattern, self.source_path, language)
      if results then
        for _, item in ipairs(results) do
          local match_start = item.range.start.line + 1
          local match_end = item.range["end"].line + 1
          if match_start <= sel_start and match_end >= sel_end then
            table.insert(candidates, {
              start = match_start,
              end_line = match_end,
              size = match_end - match_start,
            })
          end
        end
      end
    end
  end

  if #candidates > 0 then
    table.sort(candidates, function(a, b)
      return a.size < b.size
    end)
    self.start_line = candidates[1].start
    self.end_line = candidates[1].end_line
  end
end

function InlineEdit:_detect_language(filepath)
  local ext = filepath:match("%.([^./]+)$")
  if not ext then
    return nil
  end
  return EXT_TO_LANG[ext]
end

function InlineEdit:_run_astgrep(pattern, filepath, language)
  local cmd = { "ast-grep", "--json" }
  if language then
    table.insert(cmd, "--lang")
    table.insert(cmd, language)
  end
  table.insert(cmd, "-p")
  table.insert(cmd, pattern)
  table.insert(cmd, filepath)

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code > 1 then
    return nil
  end

  if exit_code == 1 or output == "" then
    return {}
  end

  local ok, parsed = pcall(vim.json.decode, output)
  if not ok then
    return nil
  end

  return parsed
end

function InlineEdit:_show_spinner()
  self._saved_winbar = vim.wo.winbar
  self._spinner_win = vim.api.nvim_get_current_win()
  self.spinner:start({ winbar = true, text = "Editing..." })
end

function InlineEdit:_stop_spinner()
  if self.spinner then
    self.spinner:stop()
    if self._spinner_win and vim.api.nvim_win_is_valid(self._spinner_win) then
      pcall(function() vim.wo[self._spinner_win].winbar = self._saved_winbar or "" end)
    end
  end
end

return InlineEdit
