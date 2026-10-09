.PHONY: test format lint

test:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/spec {minimal_init = 'tests/minimal_init.lua', sequential = true}"

format:
	stylua lua plugin tests

lint:
	stylua --check lua plugin tests
