.PHONY: shell test

IMAGE := setmeup-dev

shell: GITHUB_TOKEN ?= $(shell gh auth token 2>/dev/null)
shell: ## Interactive shell in a fresh Ubuntu container with the repo mounted
	docker build -t $(IMAGE) -f Dockerfile .
	docker run --rm -it \
		-v "$(PWD):/home/testuser/setmeup" \
		$(if $(GITHUB_TOKEN),-e GITHUB_TOKEN -e MISE_GITHUB_TOKEN=$(GITHUB_TOKEN)) \
		$(IMAGE) bash -c '\
			echo ""; \
			echo "  Run bootstrap with local source:"; \
			echo "    ~/setmeup/bootstrap.sh --local"; \
			echo ""; \
			echo "  Or from GitHub (uses committed code only):"; \
			echo "    curl -fsLS https://raw.githubusercontent.com/mmcardle/setmeup/main/bootstrap.sh | sh"; \
			echo ""; \
			exec bash'

test: ## Run the test suite in Docker
	./tests/run_tests.sh
