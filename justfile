# nvim-aibo development tasks

# List all available tasks
default:
	@just --list

# Run luacheck for linting
lint:
	@luacheck lua/ --globals vim

# Format code with stylua
fmt:
	@stylua lua/ tests/

# Run all tests
test:
	@echo "Running tests..."
	@nvim --headless -c "luafile tests/test_runner.lua" -c "qa!" 2>&1 | tee test-results.log

# Run a specific test file
test-file FILE:
	@echo "Running test: {{FILE}}"
	@nvim --headless -c "luafile tests/test_{{FILE}}.lua" -c "qa!"

# Run tests in watch mode (requires fswatch)
test-watch:
	@while true; do \
		clear; \
		date; \
		nvim --headless -c "luafile tests/test_runner.lua" -c "qa!"; \
		echo "Waiting for changes... Press Ctrl+C to exit"; \
		fswatch -1 lua/ tests/ plugin/ ftplugin/ 2>/dev/null || sleep 5; \
	done

# Run all checks (lint + format + test)
check: lint fmt test

# Clean test artifacts
clean:
	@rm -f test-results.log
	@rm -rf .test-cache
