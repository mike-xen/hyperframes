FROM node:22-bookworm-slim

# System dependencies + native ARM64 Chromium
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    ffmpeg \
    chromium \
    libgbm1 \
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libcups2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libxshmfence1 \
    libgtk-3-0 \
    fonts-liberation \
    fonts-noto-color-emoji \
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-noto-extra \
    fonts-noto-ui-core \
    fonts-freefont-ttf \
    fonts-dejavu-core \
    fontconfig \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && fc-cache -fv

# Use Debian's native ARM64 Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CONTAINER=true
ENV NODE_ENV=production

WORKDIR /app

# Bun
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL="/root/.bun" bash -s "bun-v1.3.13"
ENV PATH="/root/.bun/bin:$PATH"

# Workspace manifests
COPY package.json bun.lock ./

COPY packages/parsers/package.json packages/parsers/package.json
COPY packages/lint/package.json packages/lint/package.json
COPY packages/studio-server/package.json packages/studio-server/package.json
COPY packages/core/package.json packages/core/package.json
COPY packages/engine/package.json packages/engine/package.json
COPY packages/producer/package.json packages/producer/package.json
COPY packages/player/package.json packages/player/package.json
COPY packages/cli/package.json packages/cli/package.json
COPY packages/studio/package.json packages/studio/package.json
COPY packages/shader-transitions/package.json packages/shader-transitions/package.json
COPY packages/aws-lambda/package.json packages/aws-lambda/package.json
COPY packages/gcp-cloud-run/package.json packages/gcp-cloud-run/package.json
COPY packages/sdk/package.json packages/sdk/package.json
COPY packages/sdk-playground/package.json packages/sdk-playground/package.json

RUN bun install --frozen-lockfile

# Source
COPY packages/parsers/ packages/parsers/
COPY packages/lint/ packages/lint/
COPY packages/studio-server/ packages/studio-server/
COPY packages/core/ packages/core/
COPY packages/engine/ packages/engine/
COPY packages/producer/ packages/producer/

# Build dependencies
RUN bun run --filter '@hyperframes/{parsers,lint,studio-server}' build \
    && bun run --cwd packages/core build \
    && bun run --filter @hyperframes/core build:hyperframes-runtime:modular

# Generate embedded fonts
RUN cd packages/producer && bunx tsx scripts/generate-font-data.ts

WORKDIR /app/packages/producer

# Production server
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

CMD ["bun", "run", "src/server.ts"]
