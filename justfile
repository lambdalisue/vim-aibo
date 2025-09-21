# nvim-aibo development tasks

# List all available tasks
default:
	@just --list

# Run luacheck for linting
lint:
	@luacheck lua/ --globals vim

# Format code with stylua
fmt:
	@stylua lua/
