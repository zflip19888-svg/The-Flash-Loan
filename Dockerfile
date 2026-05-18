# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Build
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install root deps (hardhat / test tooling — needed for artifacts)
COPY package*.json ./
RUN npm ci --ignore-scripts

# Install bot deps
COPY bot/package*.json ./bot/
RUN cd bot && npm ci --ignore-scripts

# Copy source and compile
COPY bot/ ./bot/
RUN cd bot && npx tsc

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

# Non-root user for security
RUN addgroup -S botuser && adduser -S botuser -G botuser

WORKDIR /app

# Copy compiled output and production deps only
COPY --from=builder /app/bot/dist       ./bot/dist
COPY --from=builder /app/bot/node_modules ./bot/node_modules
COPY bot/package.json                   ./bot/package.json

# Logs directory (writable by botuser)
RUN mkdir -p /app/logs && chown botuser:botuser /app/logs

USER botuser

# Health check — confirm node process is alive every 60s
HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
  CMD pgrep -x node > /dev/null || exit 1

WORKDIR /app/bot

CMD ["node", "dist/index.js"]
