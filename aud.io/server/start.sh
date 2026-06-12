#!/bin/sh
# Launch the bgutil PO token provider (if baked into the image) before the
# API server; yt-dlp's bgutil plugin finds it on http://127.0.0.1:4416.
if [ -f /opt/bgutil/server/build/main.js ]; then
  node /opt/bgutil/server/build/main.js &
fi
exec node src/index.js
