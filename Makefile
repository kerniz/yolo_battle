SHELL := /bin/sh

.PHONY: test lint

test:
	bats tests

lint:
	zsh -n yolo.zsh battle.zsh lib/*.zsh modes/*.zsh
	bash -n install.sh yolo.sh
