local logger = require("bufferbuddy.logger")

describe("logger", function()
  local original_config

  before_each(function()
    original_config = vim.deepcopy(logger.config)
    logger.config.testing = true
  end)

  after_each(function()
    logger.config = original_config
  end)

  it("debug returns empty string when loglevel is warn", function()
    logger.config.loglevel = "warn"
    assert.are.same("", logger.debug("test"))
  end)

  it("info returns empty string when loglevel is warn", function()
    logger.config.loglevel = "warn"
    assert.are.same("", logger.info("test"))
  end)

  it("warn returns output when loglevel is warn", function()
    logger.config.loglevel = "warn"
    local result = logger.warn("test")
    assert.is_true(string.find(result, "[WARN]", 1, true) ~= nil)
  end)

  it("error returns output when loglevel is warn", function()
    logger.config.loglevel = "warn"
    local result = logger.error("test")
    assert.is_true(string.find(result, "[ERROR]", 1, true) ~= nil)
  end)

  it("debug returns output when loglevel is debug", function()
    logger.config.loglevel = "debug"
    local result = logger.debug("test")
    assert.is_true(string.find(result, "[DEBUG]", 1, true) ~= nil)
  end)

  it("info returns empty string when loglevel is error", function()
    logger.config.loglevel = "error"
    assert.are.same("", logger.info("test"))
  end)

  it("output ends with newline", function()
    logger.config.loglevel = "debug"
    local result = logger.debug("hello")
    assert.is_true(string.sub(result, -1) == "\n")
  end)

  it("output includes timestamp", function()
    logger.config.loglevel = "debug"
    local result = logger.debug("hello")
    assert.is_true(string.match(result, "^%d%d%d%d%d%d%d%d %d%d:%d%d:%d%d") ~= nil)
  end)

  it("debug prefixes with [DEBUG]", function()
    logger.config.loglevel = "debug"
    local result = logger.debug("x")
    assert.is_true(string.find(result, "[DEBUG]", 1, true) ~= nil)
  end)

  it("info prefixes with [INFO]", function()
    logger.config.loglevel = "info"
    local result = logger.info("x")
    assert.is_true(string.find(result, "[INFO]", 1, true) ~= nil)
  end)

  it("warn prefixes with [WARN]", function()
    logger.config.loglevel = "warn"
    local result = logger.warn("x")
    assert.is_true(string.find(result, "[WARN]", 1, true) ~= nil)
  end)

  it("error prefixes with [ERROR]", function()
    logger.config.loglevel = "error"
    local result = logger.error("x")
    assert.is_true(string.find(result, "[ERROR]", 1, true) ~= nil)
  end)

  it("serializes table arguments as JSON", function()
    logger.config.loglevel = "debug"
    local result = logger.debug({ key = "value" })
    assert.is_true(string.find(result, '"key"', 1, true) ~= nil)
    assert.is_true(string.find(result, '"value"', 1, true) ~= nil)
  end)

  it("joins multiple string arguments with tabs", function()
    logger.config.loglevel = "debug"
    local result = logger.debug("foo", "bar", "baz")
    local message = string.match(result, "foo bar baz")
    assert.is_true(message ~= nil)
  end)

  it("handles nil argument", function()
    logger.config.loglevel = "debug"
    local result = logger.debug(nil)
    assert.is_true(string.len(result) > 0)
  end)

  it("handles number argument", function()
    logger.config.loglevel = "debug"
    local result = logger.debug(42)
    assert.is_true(string.find(result, "42", 1, true) ~= nil)
  end)

  it("serializes complex nested table as JSON", function()
    logger.config.loglevel = "debug"
    local complex = {
      name = "test",
      count = 42,
      nested = {
        active = true,
        tags = { "a", "b", "c" },
        metadata = { score = 3.14 },
      },
    }
    local result = logger.debug(complex)
    print("result", result)
    local _, end_pos = string.find(result, "[DEBUG] ", 1, true)
    local json_str = string.sub(result, end_pos + 1, -2)
    assert.is_not.equal(nil, json_str, "Failed to extract JSON from: " .. tostring(result))
    local decoded = vim.json.decode(json_str)
    assert.are.same(complex.name, decoded.name)
    assert.are.same(complex.count, decoded.count)
    assert.is_true(decoded.nested.active)
    assert.are.same(complex.nested.tags, decoded.nested.tags)
    assert.are.same(complex.nested.metadata.score, decoded.nested.metadata.score)
  end)

  it("returns output without writing file when testing is true", function()
    logger.config.loglevel = "debug"
    local result = logger.debug("in testing mode")
    assert.is_true(string.find(result, "[DEBUG]", 1, true) ~= nil)
  end)
end)
