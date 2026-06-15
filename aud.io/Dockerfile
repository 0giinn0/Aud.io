FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore --upgrade yt-dlp

WORKDIR /app

# Copy server package files from server/ subdirectory
COPY server/package.json server/package-lock.json ./
RUN npm ci

# Copy server source files
COPY server/ .

ENV NODE_ENV=production
ENV PORT=10000

EXPOSE 10000
CMD ["node", "src/index.js"]