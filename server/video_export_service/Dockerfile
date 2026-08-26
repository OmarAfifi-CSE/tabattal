FROM node:18-bullseye-slim

# Install FFmpeg and required media libraries
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

# Cloud Run default port is 8080
ENV PORT=8080
EXPOSE 8080

CMD ["node", "index.js"]
