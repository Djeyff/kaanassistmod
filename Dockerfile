# ============================================================================
# OpenClaw KaanAssist Mod v1 — Full toolkit + OpenViking memory + Chromium
# CRITICAL: Config staged in /opt/openclaw-seed, copied to volume at boot
# ============================================================================
FROM node:24-bookworm AS base

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    # ── Core ──
    procps hostname curl git lsof openssl jq wget unzip zip \
    build-essential python3 python3-pip python3-venv ca-certificates \
    postgresql-client \
    # ── OpenViking build deps ──
    cmake g++ \
    # ── Network debugging ──
    netcat-openbsd dnsutils net-tools iputils-ping iproute2 \
    # ── Process / system debugging ──
    htop strace nano less file tree \
    # ── Media processing ──
    ffmpeg imagemagick poppler-utils \
    # ── Code search ──
    ripgrep \
    # ── Database ──
    sqlite3 \
    # ── Chromium + browser tooling deps ──
    chromium \
    fonts-liberation fonts-noto-color-emoji fonts-noto-cjk \
    libatk-bridge2.0-0 libatk1.0-0 libcups2 libdrm2 libgbm1 \
    libnss3 libxcomposite1 libxdamage1 libxrandr2 libxshmfence1 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Chromium env
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium
ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_DOWNLOAD=true

# Go toolchain
ARG GO_VERSION=1.23.4
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
    | tar -C /usr/local -xzf - \
    && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
ENV GOPATH=/root/go
ENV PATH="${GOPATH}/bin:/usr/local/go/bin:${PATH}"

# Install OpenClaw + Codex + OpenClaude
RUN npm install -g openclaw@latest
RUN npm install -g @openai/codex@latest
RUN npm install -g @gitlawb/openclaude@latest 2>/dev/null || true

# Install Puppeteer (browser automation)
RUN npm install -g puppeteer-core@latest

# Install uv (fast Python package manager)
RUN pip3 install --break-system-packages uv 2>/dev/null || true

# Install OpenViking memory system (uses FREE Gemini embeddings + Groq VLM)
RUN pip3 install --break-system-packages openviking --upgrade 2>/dev/null || true
RUN npm install -g openclaw-openviking-setup-helper 2>/dev/null || true
RUN mkdir -p /root/.openviking/data

# Stage config + workspace in /opt (NOT in /root/.openclaw — volume hides it)
COPY openclaw.json /opt/openclaw-seed/openclaw.json
COPY workspace/ /opt/openclaw-seed/workspace/
COPY scripts/ /opt/openclaw-seed/scripts/
COPY openviking/ /opt/openclaw-seed/openviking/

# Startup script lives OUTSIDE the volume mount
COPY scripts/startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# Git identity
RUN git config --global user.name "Djeyff" \
    && git config --global user.email "djeyff006@gmail.com"

HEALTHCHECK --interval=3m --timeout=10s --start-period=30s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:18789/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

EXPOSE 18789
CMD ["/usr/local/bin/startup.sh"]
