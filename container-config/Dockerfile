FROM node:22-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    unzip \
    openssh-client \
    perl \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

RUN useradd -m -s /bin/bash claude
USER claude

RUN git config --global core.autocrlf input \
    && git config --global init.defaultBranch main \
    && npm config set ignore-scripts true

WORKDIR /project
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
