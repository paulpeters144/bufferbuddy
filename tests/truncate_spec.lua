---@diagnostic disable: undefined-field, undefined-global
local util = require("bufferbuddy.tools.util")

describe("util.truncate", function()
  it("returns string unchanged when under max_lines", function()
    local result = util.truncate("line1\nline2", 5, "TRUNCATED")
    assert.are.same("line1\nline2", result)
  end)

  it("returns string unchanged when exactly at max_lines", function()
    local result = util.truncate("line1\nline2\nline3", 3, "TRUNCATED")
    assert.are.same("line1\nline2\nline3", result)
  end)

  it("truncates and appends message when over max_lines", function()
    local result = util.truncate("line1\nline2\nline3\nline4\nline5", 3, "TRUNCATED")
    assert.are.same("line1\nline2\nline3\nTRUNCATED", result)
  end)

  it("handles empty string", function()
    local result = util.truncate("", 5, "TRUNCATED")
    assert.are.same("", result)
  end)

  it("handles single line with max_lines = 1", function()
    local result = util.truncate("only line", 1, "TRUNCATED")
    assert.are.same("only line", result)
  end)

  it("returns empty string when max_lines < 1", function()
    local result = util.truncate("line1\nline2", 0, "TRUNCATED")
    assert.are.same("", result)
  end)

  it("uses custom message in truncated output", function()
    local result = util.truncate("a\nb\nc\nd\ne", 2, "(custom message)")
    assert.are.same("a\nb\n(custom message)", result)
  end)

end)
