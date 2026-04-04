FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    build-essential \
    jq \
    unzip \
    openssh-client \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash claude
USER claude

# Install Claude Code via native installer
ARG CLAUDE_VERSION=latest
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- ${CLAUDE_VERSION}
ENV PATH="/home/claude/.local/bin:${PATH}"

# Supply chain hardening — env vars take effect whenever runtimes are installed
ENV npm_config_ignore_scripts=true
ENV NODE_OPTIONS="--dns-result-order=ipv4first"

# Git defaults
RUN git config --global core.autocrlf input \
    && git config --global init.defaultBranch main

WORKDIR /project
ENTRYPOINT ["/home/claude/.local/bin/claude", "--dangerously-skip-permissions"]
