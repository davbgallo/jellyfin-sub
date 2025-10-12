# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS server-build
WORKDIR /src

# Clone Jellyfin source
RUN apt-get update && apt-get install -y git && \
    git clone https://github.com/cyberpoison/jellyfin-sub.git . && \
    git submodule update --init

# Restore and build
RUN dotnet restore Jellyfin.Server
RUN dotnet publish Jellyfin.Server -c Release -o /app/publish

# ---- Build Jellyfin Web ----
FROM node:20-bullseye AS web-build
WORKDIR /web

RUN git clone https://github.com/jellyfin/jellyfin-web.git . --branch master --depth 1

# Install deps and build production bundle
RUN npm ci
RUN npm run build:production


# ---- Runtime Image ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}"

WORKDIR /app

# Install FFmpeg and dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libva2 libvdpau1 libdrm2 && \
    rm -rf /var/lib/apt/lists/*

# Copy server & web client from build stages
COPY --from=server-build /app/publish .
COPY --from=web-build /web/dist /app/jellyfin-web

ENV JELLYFIN_CONFIG_DIR=/config
ENV JELLYFIN_CACHE_DIR=/cache
ENV JELLYFIN_DATA_DIR=/config/data
ENV JELLYFIN_LOG_DIR=/config/log
RUN mkdir -p /config /cache
VOLUME ["/config", "/cache"]
EXPOSE 8096
ENTRYPOINT ["dotnet", "jellyfin.dll"]
