FROM ubuntu:24.04

# Avoid interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Minimal base — simulate a fresh machine (only add sudo + a test user)
RUN apt-get update -qq && \
    apt-get install -y -qq sudo curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install BATS
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core && \
    /tmp/bats-core/install.sh /usr/local && \
    rm -rf /tmp/bats-core

# Create a non-root user (bootstrap should not require root for everything)
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

# Pre-install chezmoi and mise (cached Docker layer — avoids re-downloading on dotfile changes)
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" && \
    curl -fsLS https://mise.run | sh
ENV PATH="/home/testuser/.local/bin:${PATH}"

# Skip Powerlevel10k configuration wizard in test/debug shells
ENV POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

# Pre-seed chezmoi config to avoid interactive prompts
RUN mkdir -p /home/testuser/.config/chezmoi
COPY --chown=testuser:testuser tests/chezmoi-test-config.toml /home/testuser/.config/chezmoi/chezmoi.toml

# Copy the repo source (used as chezmoi source directory)
COPY --chown=testuser:testuser . /home/testuser/setmeup

# Copy tests
COPY --chown=testuser:testuser tests/ /home/testuser/tests/
RUN chmod +x /home/testuser/tests/setup_environment.sh

# Bake test setup into the image so repeated test runs are fast
RUN /home/testuser/tests/setup_environment.sh

# Pre-install mise tools so they're available in interactive shells
# GITHUB_TOKEN avoids GitHub API rate limits for aqua-based tool downloads
ARG GITHUB_TOKEN
RUN GITHUB_TOKEN="${GITHUB_TOKEN}" MISE_GITHUB_TOKEN="${GITHUB_TOKEN}" mise install --yes

CMD ["/bin/bash", "-c", "bats $HOME/tests/*.bats"]
