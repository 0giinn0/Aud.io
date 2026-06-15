FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    python3 \
    python3-pip \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Debian bookworm marks the system Python env as externally managed (PEP 668);
# --break-system-packages is required for a system-wide yt-dlp in a container.
RUN pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore yt-dlp

# PO token provider: YouTube refuses datacenter IPs without a proof-of-origin
# token. The bgutil sidecar generates them; the pip plugin makes yt-dlp use it.
RUN git clone --depth 1 https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git /opt/bgutil \
    && cd /opt/bgutil/server \
    && npm install \
    && npx tsc
RUN pip3 install --no-cache-dir --break-system-packages bgutil-ytdlp-pot-provider

WORKDIR /app

# Use the pip-installed yt-dlp (kept fresh at every build) instead of the
# copy youtube-dl-exec would download from GitHub during npm install.
ENV YOUTUBE_DL_SKIP_DOWNLOAD=true
ENV YOUTUBE_DL_DIR=/usr/local/bin

COPY aud.io/server/package.json aud.io/server/package-lock.json ./
RUN npm install --omit=dev

COPY aud.io/server/ ./

ENV NODE_ENV=production
ENV PORT=10000

EXPOSE 10000

CMD ["node", "src/index.js"]
