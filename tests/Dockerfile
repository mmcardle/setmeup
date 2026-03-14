FROM ubuntu:24.04

# Avoid interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Minimal base — simulate a fresh machine (only add sudo + a test user)
RUN apt-get update -qq && \
    apt-get install -y -qq sudo curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user (bootstrap should not require root for everything)
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

# Pre-seed chezmoi config to avoid interactive prompts
RUN mkdir -p /home/testuser/.config/chezmoi
COPY --chown=testuser:testuser tests/chezmoi-test-config.toml /home/testuser/.config/chezmoi/chezmoi.toml

# Copy the repo source (used as chezmoi source directory)
COPY --chown=testuser:testuser . /home/testuser/setmeup

# Copy and set up test script
COPY --chown=testuser:testuser tests/test_bootstrap.sh /home/testuser/test_bootstrap.sh
RUN chmod +x /home/testuser/test_bootstrap.sh

CMD ["/home/testuser/test_bootstrap.sh"]
