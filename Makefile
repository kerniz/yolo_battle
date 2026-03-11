SHELL := /bin/sh

.PHONY: test lint

test:
	bats tests

lint:
	zsh -n yolo.zsh battle.zsh modes/*.zsh
	bash -n install.sh
