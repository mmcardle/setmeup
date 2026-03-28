# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y -qq sudo curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core && \
    /tmp/bats-core/install.sh /usr/local && \
    rm -rf /tmp/bats-core

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" && \
    curl -fsLS https://mise.run | sh
ENV PATH="/home/testuser/.local/bin:${PATH}"
ENV POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

RUN mkdir -p /home/testuser/.config/chezmoi /home/testuser/setmeup /home/testuser/tests
COPY --chown=testuser:testuser tests/chezmoi-test-config.toml /home/testuser/.config/chezmoi/chezmoi.toml
COPY --chown=testuser:testuser bootstrap.sh /home/testuser/setmeup/bootstrap.sh
COPY --chown=testuser:testuser update.sh /home/testuser/setmeup/update.sh
COPY --chown=testuser:testuser home/ /home/testuser/setmeup/home/
COPY --chown=testuser:testuser tests/setup_environment.sh /home/testuser/tests/setup_environment.sh
RUN chmod +x /home/testuser/tests/setup_environment.sh && \
    cd /home/testuser/setmeup && \
    git init -b main && \
    git config user.email "test@example.com" && \
    git config user.name "Test User" && \
    git add -A && \
    git commit --no-verify -m "initial"

FROM base AS prepared-setup

RUN --mount=type=secret,id=GITHUB_TOKEN,mode=0444 \
    if [ ! -s /run/secrets/GITHUB_TOKEN ]; then \
        echo "ERROR: GITHUB_TOKEN secret is required to avoid GitHub API rate limits" && exit 1; \
    fi && \
    export GITHUB_TOKEN="$(cat /run/secrets/GITHUB_TOKEN)" && \
    export MISE_GITHUB_TOKEN="$GITHUB_TOKEN" && \
    /home/testuser/tests/setup_environment.sh

FROM prepared-setup AS prepared

COPY --chown=testuser:testuser tests/test_helper.bash /home/testuser/tests/test_helper.bash
COPY --chown=testuser:testuser tests/backup.bats /home/testuser/tests/backup.bats
COPY --chown=testuser:testuser tests/claude_code.bats /home/testuser/tests/claude_code.bats
COPY --chown=testuser:testuser tests/dotfiles.bats /home/testuser/tests/dotfiles.bats
COPY --chown=testuser:testuser tests/update_script.bats /home/testuser/tests/update_script.bats

CMD ["/bin/bash", "-lc", "bats $HOME/tests/backup.bats $HOME/tests/claude_code.bats $HOME/tests/dotfiles.bats $HOME/tests/update_script.bats"]

FROM prepared-setup AS full

COPY --chown=testuser:testuser tests/ /home/testuser/tests/
RUN chmod +x /home/testuser/tests/setup_environment.sh

CMD ["/bin/bash", "-lc", "bats $HOME/tests/*.bats"]
