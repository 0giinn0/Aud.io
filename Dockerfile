FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Debian bookworm marks the system Python env as externally managed (PEP 668);
# --break-system-packages is required for a system-wide yt-dlp in a container.
RUN pip3 install --no-cache-dir --break-system-packages yt-dlp

WORKDIR /app

COPY aud.io/server/package.json aud.io/server/package-lock.json ./
RUN npm install --omit=dev

COPY aud.io/server/ ./

ENV NODE_ENV=production
ENV PORT=10000

EXPOSE 10000

CMD ["node", "src/index.js"]
