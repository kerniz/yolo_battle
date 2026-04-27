SHELL := /bin/sh

.PHONY: test lint

test:
	@if command -v bats >/dev/null 2>&1; then \
		bats tests; \
	else \
		echo "Error: bats (Bash Automated Testing System) is not installed."; \
		echo "Install it with:"; \
		echo "  brew install bats-core  # macOS"; \
		echo "  sudo apt install bats   # Ubuntu/Debian"; \
		exit 1; \
	fi

lint:
	zsh -n yolo.zsh battle.zsh lib/*.zsh modes/*.zsh
	bash -n install.sh
