local filter = vim.env.TEST_FILTER

local busted = require("plenary.busted")
local orig_it = busted.it
local orig_describe = busted.describe

local describe_match = false

describe = function(desc, func)
  if not filter then
    orig_describe(desc, func)
    return
  end
  local parent_match = describe_match
  if desc:find(filter) then
    describe_match = true
  end
  orig_describe(desc, func)
  describe_match = parent_match
end

it = function(desc, test_func)
  if not filter then
    orig_it(desc, test_func)
    return
  end
  if describe_match or desc:find(filter) then
    orig_it(desc, test_func)
  end
end

local h = require("plenary.test_harness")

for _, file in ipairs(h._find_files_to_run("tests/")) do
  local fn = loadfile(file:absolute())
  if fn then
    pcall(fn)
  end
end

local results
for i = 1, 50 do
  local name, value = debug.getupvalue(orig_it, i)
  if name == "results" then
    results = value
    break
  end
end

if results then
  busted.format_results(results)
  if #results.fail > 0 or #results.errs > 0 then
    vim.cmd("1cq")
  else
    vim.cmd("0cq")
  end
else
  vim.cmd("0cq")
end
