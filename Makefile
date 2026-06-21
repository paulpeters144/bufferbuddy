TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

.PHONY: test lint lint-lua format format-lua install-hooks

test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

test-filter:
	TEST_FILTER='$(name)' nvim --headless --noplugin -u ${TESTS_INIT} -c "luafile scripts/test-filter.lua"

test-coverage:
	@LUACOV=1 nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

coverage-report:
	@luacov

coverage-html:
	@luacov-html

coverage-clean:
	@rm -f luacov.stats.out luacov.report.out

coverage: test-coverage coverage-report

lint-lua:
	@stylua --check lua/ plugin/ tests/
	@luacheck lua/ plugin/ tests/

lint: lint-lua

format-lua:
	@stylua lua/ plugin/ tests/

format: format-lua
