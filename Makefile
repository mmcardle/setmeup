.PHONY: shell test test-file test-filter test-quick

IMAGE := setmeup-dev
TEST_IMAGE := setmeup-test

shell: GITHUB_TOKEN ?= $(shell gh auth token 2>/dev/null)
shell: ## Interactive shell in a fresh Ubuntu container with the repo mounted
	docker build -t $(TEST_IMAGE) -f tests/Dockerfile .
	docker run --rm -it \
		-v "$(PWD):/home/testuser/setmeup" \
		$(if $(GITHUB_TOKEN),-e GITHUB_TOKEN -e MISE_GITHUB_TOKEN=$(GITHUB_TOKEN)) \
		$(TEST_IMAGE) bash -c '\
			echo ""; \
			echo "  Setup is baked into the image."; \
			echo "  Run tests directly:"; \
			echo "    bats ~/tests/dotfiles.bats"; \
			echo "    bats --filter \"aliases\" ~/tests/*.bats"; \
			echo ""; \
			echo "  To re-run setup after source changes:"; \
			echo "    rm ~/.local/state/setmeup/test-setup-complete && ~/tests/setup_environment.sh"; \
			echo ""; \
			exec bash'

test: ## Run the full test suite in Docker
	./tests/run_tests.sh

test-file: ## Run a single test file (usage: make test-file FILE=dotfiles.bats)
	./tests/run_tests.sh '$$HOME/tests/$(FILE)'

test-filter: ## Run tests matching a pattern (usage: make test-filter FILTER="aliases")
	./tests/run_tests.sh --filter '$(FILTER)' '$$HOME/tests/*.bats'

test-quick: ## Run fast tests only (skip mise_tools and shell_clean)
	./tests/run_tests.sh '$$HOME/tests/backup.bats' '$$HOME/tests/dotfiles.bats' '$$HOME/tests/idempotency.bats' '$$HOME/tests/update_script.bats'
