FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y -qq sudo curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser
ENV PATH="/home/testuser/.local/bin:${PATH}"

# Pre-seed chezmoi config to avoid interactive prompts
RUN mkdir -p /home/testuser/.config/chezmoi
COPY --chown=testuser:testuser tests/chezmoi-test-config.toml /home/testuser/.config/chezmoi/chezmoi.toml
