# ---- Build Stage ----
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Install prerequisites
RUN apt-get update && apt-get install -y git

# Clone Jellyfin source
RUN git clone https://github.com:cyberpoison/jellyfin-sub.git . --branch master --depth 1
RUN git submodule update --init --recursive

# Build using Jellyfin’s official script
RUN ./build --configuration Release --platform AnyCPU --arch x64 --disable-ffmpeg

# ---- Runtime Stage ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
ARG GITHUB_REPOSITORY
LABEL org.opencontainers.image.source="https://github.com/${GITHUB_REPOSITORY}"

WORKDIR /app

# Install FFmpeg + deps
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libva2 libvdpau1 libdrm2 && \
    rm -rf /var/lib/apt/lists/*

# Copy built server from the build stage
COPY --from=build /src/deployment/bin/net9.0/Release/publish .

EXPOSE 8096
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
