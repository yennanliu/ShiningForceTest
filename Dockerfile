# Headless Godot environment for tests and builds.
#   tools/docker.sh test      run the test suite
#   tools/docker.sh export    build the Linux app into build/
# Playing and editing still use the native Godot app (needs a GPU and a window).

FROM ubuntu:24.04 AS base
ARG GODOT_VERSION=4.7.2-stable
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    case "$TARGETARCH" in arm64) A=arm64 ;; *) A=x86_64 ;; esac; \
    curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.${A}.zip"; \
    unzip -q /tmp/godot.zip -d /tmp/godot; \
    mv /tmp/godot/Godot_v${GODOT_VERSION}_linux.${A} /usr/local/bin/godot; \
    rm -rf /tmp/godot /tmp/godot.zip; \
    godot --version
WORKDIR /project

# Adds export templates (~1 GB) on top of base, only needed for building the app.
FROM base AS export
ARG GODOT_VERSION=4.7.2-stable
RUN set -eux; \
    curl -fsSL -o /tmp/t.tpz "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"; \
    unzip -q /tmp/t.tpz -d /tmp/t; \
    DEST="/root/.local/share/godot/export_templates/$(echo ${GODOT_VERSION} | tr - .)"; \
    mkdir -p "$DEST"; mv /tmp/t/templates/* "$DEST/"; rm -rf /tmp/t /tmp/t.tpz
