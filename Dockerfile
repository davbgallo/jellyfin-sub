# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Clone Jellyfin source
RUN apt-get update && apt-get install -y git && \
    git clone https://ithub.com:CyberPoison/jellyfin-sub.git . && \
    git submodule update --init

# Restore and build
RUN dotnet restore Jellyfin.Server
RUN dotnet publish Jellyfin.Server -c Release -o /app/publish

# FFmpeg (using Jellyfin’s recommended static build)
FROM ubuntu:24.04 AS ffmpeg
WORKDIR /ffmpeg
RUN apt-get update && apt-get install -y wget tar && \
    wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz && \
    tar -xf ffmpeg-release-amd64-static.tar.xz --strip-components=1 && \
    chmod +x ffmpeg ffprobe

# Final runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}"
WORKDIR /app

# Install dependencies (for FFmpeg runtime)
RUN apt-get update && apt-get install -y \
    libva2 libvdpau1 libdrm2 && \
    rm -rf /var/lib/apt/lists/*

# Copy app and ffmpeg binaries
COPY --from=build /app/publish .
COPY --from=ffmpeg /ffmpeg/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg /ffmpeg/ffprobe /usr/local/bin/ffprobe

EXPOSE 8096
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
