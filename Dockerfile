FROM node:24-slim AS base

# ── System deps ────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git wget unzip jq bash coreutils \
    python3 python3-pip \
    build-essential \
    postgresql-client \
    imagemagick poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# ── Install Go (for OpenClaw) ─────────────────────────────────
ENV GO_VERSION=1.23.4
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -xz -C /usr/local \
    && ln -s /usr/local/go/bin/go /usr/local/bin/go \
    && ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

ENV GOPATH=/root/go
ENV PATH=$PATH:/root/go/bin:/usr/local/go/bin

# ── Install OpenClaw CLI ──────────────────────────────────────
RUN npm install -g openclaw@latest

# ── Install Codex CLI ─────────────────────────────────────────
RUN npm install -g @openai/codex@latest

# ── Install OpenClaude ────────────────────────────────────────
RUN npm install -g openclaude@latest 2>/dev/null || echo "openclaude optional — skipping"

# ── Stage seed directory (NEVER copy directly into /root/.openclaw) ──
# Volume mount at /root/.openclaw wipes COPY'd files at boot.
# Solution: stage in /opt/openclaw-seed, copy at startup.
WORKDIR /opt/openclaw-seed

COPY openclaw.json ./openclaw.json
COPY workspace/ ./workspace/
COPY scripts/ ./scripts/
RUN chmod +x ./scripts/*.sh ./scripts/*.js 2>/dev/null || true

# ── Expose OpenClaw gateway port ──────────────────────────────
EXPOSE 18789

# ── Health check ──────────────────────────────────────────────
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -fsS http://127.0.0.1:18789/health || exit 1

# ── Entrypoint ────────────────────────────────────────────────
ENTRYPOINT ["/opt/openclaw-seed/scripts/startup.sh"]
