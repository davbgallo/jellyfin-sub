# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Clone Jellyfin source
RUN apt-get update && apt-get install -y git && \
    git clone https://github.com/cyberpoison/jellyfin-sub.git . && \
    git submodule update --init

# Restore and build
RUN dotnet restore Jellyfin.Server
RUN dotnet publish Jellyfin.Server -c Release -o /app/publish

# Clone and build Jellyfin web client
WORKDIR /web
RUN git clone https://github.com/jellyfin/jellyfin-web.git . --branch master --depth 1
RUN npm ci && npm run build:production

# ---- Runtime Stage ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}"
WORKDIR /app

# Install FFmpeg and dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libva2 libvdpau1 libdrm2 && \
    rm -rf /var/lib/apt/lists/*

# Copy Jellyfin server and web UI
COPY --from=build /app/publish .
COPY --from=build /web/dist /app/jellyfin-web

EXPOSE 8096
ENTRYPOINT ["dotnet", "jellyfin.dll"]

