.PHONY: shell test test-full test-file test-filter test-rebuild test-clean test-clean-all

shell: GITHUB_TOKEN ?= $(shell gh auth token 2>/dev/null)
shell: ## Interactive shell in the prepared fast test container
	GITHUB_TOKEN="$(GITHUB_TOKEN)" ./tests/run_tests.sh shell

test: ## Run the fast local smoke suite in Docker
	./tests/run_tests.sh fast

test-full: ## Run the clean full integration suite in Docker
	./tests/run_tests.sh full

test-file: ## Run a single test file (usage: make test-file FILE=dotfiles.bats)
	./tests/run_tests.sh fast '$$HOME/tests/$(FILE)'

test-filter: ## Run tests matching a pattern (usage: make test-filter FILTER="aliases")
	./tests/run_tests.sh fast --filter '$(FILTER)' '$$HOME/tests/*.bats'

test-rebuild: ## Rebuild the prepared fast test image
	./tests/run_tests.sh rebuild

test-clean: ## Remove the current worktree's scoped test images and cache
	./tests/run_tests.sh clean

test-clean-all: ## Remove all scoped setmeup test images on this host
	./tests/run_tests.sh clean-all
