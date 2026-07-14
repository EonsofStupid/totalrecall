# Enable GPU support.
# This option can be set to `nvidia` or `amd` to enable GPU support.
# This option is defined here because it is used in `FROM` instructions.
ARG GPU

# Cross-compiling using Docker multi-platform builds/images and `xx`.
#
# https://docs.docker.com/build/building/multi-platform/
# https://github.com/tonistiigi/xx
FROM --platform=${BUILDPLATFORM:-linux/amd64} tonistiigi/xx AS xx

# Utilizing Docker layer caching with `cargo-chef`.
#
# https://www.lpalmieri.com/posts/fast-rust-docker-builds/

# Note: using bookworm base image to match GPU runtime image, otherwise we're
# seeing runtime errors due to libc version mismatch.
# Cross-compilation setup
FROM --platform=${BUILDPLATFORM:-linux/amd64} lukemathwalker/cargo-chef:latest-rust-1.96.0-bookworm  AS chef


FROM chef AS planner
WORKDIR /trecall
COPY . .
RUN cargo chef prepare --recipe-path recipe.json


FROM chef AS builder
WORKDIR /trecall

COPY --from=xx / /

# Relative order of `ARG` and `RUN` commands in the Dockerfile matters.
#
# If you pass a different `ARG` to `docker build`, it would invalidate Docker layer cache
# for the next steps. (E.g., the following steps may depend on a new `ARG` value, so Docker would
# have to re-execute them instead of using a cached layer from a previous run.)
#
# Steps in this stage are ordered in a way that should maximize Docker layer cache utilization,
# so, please, don't reorder them without prior consideration. 🥲

RUN apt-get update \
    && apt-get install -y clang lld cmake protobuf-compiler jq \
    && rustup component add rustfmt \
    && cargo install cargo-sbom

# `ARG`/`ENV` pair is a workaround for `docker build` backward-compatibility.
#
# https://github.com/docker/buildx/issues/510
ARG BUILDPLATFORM
ENV BUILDPLATFORM=${BUILDPLATFORM:-linux/amd64}

ARG MOLD_VERSION=2.41.0

RUN case "$BUILDPLATFORM" in \
        */amd64 ) PLATFORM=x86_64 ;; \
        */arm64 | */arm64/* ) PLATFORM=aarch64 ;; \
        * ) echo "Unexpected BUILDPLATFORM '$BUILDPLATFORM'" >&2; exit 1 ;; \
    esac; \
    \
    mkdir -p /opt/mold; \
    cd /opt/mold; \
    \
    TARBALL="mold-$MOLD_VERSION-$PLATFORM-linux.tar.gz"; \
    curl -sSLO "https://github.com/rui314/mold/releases/download/v$MOLD_VERSION/$TARBALL"; \
    tar -xf "$TARBALL" --strip-components 1; \
    rm "$TARBALL"

# `ARG`/`ENV` pair is a workaround for `docker build` backward-compatibility.
#
# https://github.com/docker/buildx/issues/510
ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN xx-apt-get install -y pkg-config gcc g++ libc6-dev libunwind-dev

# Select Cargo profile (e.g., `release`, `dev` or `ci`)
ARG PROFILE=release

# Enable crate features
ARG FEATURES

# Pass custom `RUSTFLAGS` (e.g., `--cfg tokio_unstable` to enable Tokio tracing/`tokio-console`)
ARG RUSTFLAGS

# Select linker (e.g., `mold`, `lld` or an empty string for the default linker)
ARG LINKER=mold

# Select target CPU; use `rustc --print target-cpus` to see available values
ARG TARGET_CPU

# Select jemalloc's allocator page size
#
# Specified as base 2 log, e.g.:
# 12 = 2^12 = 4k
# 14 = 2^14 = 16k
# 16 = 2^16 = 64k
#
# https://github.com/tikv/jemallocator/tree/main/jemalloc-sys#environment-variables
# https://github.com/jemalloc/jemalloc/blob/dev/INSTALL.md?plain=1#L225-L232
ARG JEMALLOC_SYS_WITH_LG_PAGE

# Enable GPU support
ARG GPU

COPY --from=planner /trecall/recipe.json recipe.json
# `PKG_CONFIG=...` is a workaround for `xx-cargo` bug for crates using `pkg-config`!
#
# https://github.com/tonistiigi/xx/issues/107
# https://github.com/tonistiigi/xx/pull/108
RUN PKG_CONFIG="/usr/bin/$(xx-info)-pkg-config" \
    PATH="$PATH:/opt/mold/bin" \
    RUSTFLAGS="${LINKER:+-C link-arg=-fuse-ld=}$LINKER ${TARGET_CPU:+-C target-cpu=}$TARGET_CPU $RUSTFLAGS" \
    ${JEMALLOC_SYS_WITH_LG_PAGE:+env JEMALLOC_SYS_WITH_LG_PAGE="${JEMALLOC_SYS_WITH_LG_PAGE}"} \
    xx-cargo chef cook --profile $PROFILE ${FEATURES:+--features} $FEATURES --features=stacktrace ${GPU:+--features=gpu} --recipe-path recipe.json

COPY . .
# Include git commit into TotalRecall binary during build
ARG GIT_COMMIT_ID
# `PKG_CONFIG=...` is a workaround for `xx-cargo` bug for crates using `pkg-config`!
#
# https://github.com/tonistiigi/xx/issues/107
# https://github.com/tonistiigi/xx/pull/108
RUN PKG_CONFIG="/usr/bin/$(xx-info)-pkg-config" \
    PATH="$PATH:/opt/mold/bin" \
    RUSTFLAGS="${LINKER:+-C link-arg=-fuse-ld=}$LINKER ${TARGET_CPU:+-C target-cpu=}$TARGET_CPU $RUSTFLAGS" \
    ${JEMALLOC_SYS_WITH_LG_PAGE:+env JEMALLOC_SYS_WITH_LG_PAGE="${JEMALLOC_SYS_WITH_LG_PAGE}"} \
    xx-cargo build --profile $PROFILE ${FEATURES:+--features} $FEATURES --features=stacktrace ${GPU:+--features=gpu} --bin trecall \
    && PROFILE_DIR=$(if [ "$PROFILE" = dev ]; then echo debug; else echo $PROFILE; fi) \
    && mv target/$(xx-cargo --print-target-triple)/$PROFILE_DIR/trecall /trecall/trecall

# Download and extract web UI
RUN mkdir /static && STATIC_DIR=/static ./tools/sync-web-ui.sh

# Generate SBOM
RUN cargo sbom > trecall.spdx.json


# Dockerfile does not support conditional `FROM` directly.
# To workaround this limitation, we use a multi-stage build with a different base images which have equal name to ARG value.

# Base image for TotalRecall.
FROM debian:13-slim AS trecall-cpu


# Base images for TotalRecall with nvidia GPU support.
FROM nvidia/opengl:1.2-glvnd-devel-ubuntu22.04 AS trecall-gpu-nvidia
# Set non-interactive mode for apt-get.
ENV DEBIAN_FRONTEND=noninteractive
# Set NVIDIA driver capabilities. By default, all capabilities are disabled.
ENV NVIDIA_DRIVER_CAPABILITIES compute,graphics,utility
# Copy Nvidia ICD loader file into the container.
COPY --from=builder /trecall/lib/gpu/nvidia_icd.json /etc/vulkan/icd.d/
# Override maintainer label. Nvidia base image have it's own maintainer label.
LABEL maintainer="EonsofStupid <https://github.com/EonsofStupid>"


# Base images for TotalRecall with amd GPU support.
FROM rocm/dev-ubuntu-22.04 AS trecall-gpu-amd
# Set non-interactive mode for apt-get.
ENV DEBIAN_FRONTEND=noninteractive
# Override maintainer label. AMD base image have it's own maintainer label.
LABEL maintainer="EonsofStupid <https://github.com/EonsofStupid>"


FROM trecall-${GPU:+gpu-}${GPU:-cpu} AS trecall

# Install GPU dependencies
ARG GPU

RUN if [ -n "$GPU" ]; then \
    apt-get update \
    && apt-get install -y \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools \
    ; fi

# Install additional packages into the container.
# E.g., the debugger of choice: gdb/gdbserver/lldb.
ARG PACKAGES

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata libunwind8 $PACKAGES \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/lib/dpkg/status-old

# Copy TotalRecall source files into the container. Useful for debugging.
#
# To enable, set `SOURCES` to *any* non-empty string. E.g., 1/true/enable/whatever.
# (Note, that *any* non-empty string would work, so 0/false/disable would enable the option as well.)
ARG SOURCES

# Dockerfile does not support conditional `COPY` instructions (e.g., it's impossible to do something
# like `if [ -n "$SOURCES" ]; then COPY ...; fi`), so we *hack* conditional `COPY` by abusing
# parameter expansion and `COPY` wildcards support. 😎

ENV DIR=${SOURCES:+/trecall/src}
COPY --from=builder ${DIR:-/null?} $DIR/

ENV DIR=${SOURCES:+/trecall/lib}
COPY --from=builder ${DIR:-/null?} $DIR/

ENV DIR=${SOURCES:+/usr/local/cargo/registry/src}
COPY --from=builder ${DIR:-/null?} $DIR/

ENV DIR=${SOURCES:+/usr/local/cargo/git/checkouts}
COPY --from=builder ${DIR:-/null?} $DIR/

ENV DIR=""

ARG APP=/trecall

ARG USER_ID=0

RUN if [ "$USER_ID" != 0 ]; then \
        groupadd --gid "$USER_ID" trecall; \
        useradd --uid "$USER_ID" --gid "$USER_ID" -m trecall; \
        mkdir -p "$APP"/storage "$APP"/snapshots; \
        chown -R "$USER_ID:$USER_ID" "$APP"; \
    fi

COPY --from=builder --chown=$USER_ID:$USER_ID /trecall/trecall "$APP"/trecall
COPY --from=builder --chown=$USER_ID:$USER_ID /trecall/trecall.spdx.json "$APP"/trecall.spdx.json
COPY --from=builder --chown=$USER_ID:$USER_ID /trecall/config "$APP"/config
COPY --from=builder --chown=$USER_ID:$USER_ID /trecall/tools/entrypoint.sh "$APP"/entrypoint.sh
COPY --from=builder --chown=$USER_ID:$USER_ID /static "$APP"/static

WORKDIR "$APP"

USER "$USER_ID:$USER_ID"

ENV TZ=Etc/UTC \
    RUN_MODE=production

EXPOSE 6333
EXPOSE 6334

LABEL org.opencontainers.image.title="TotalRecall"
LABEL org.opencontainers.image.description="TotalRecall Advanced RAG Engine"
LABEL org.opencontainers.image.url="https://github.com/EonsofStupid/totalrecall"
LABEL org.opencontainers.image.documentation="https://github.com/EonsofStupid/totalrecall/blob/main/docs/DEVELOPMENT.md"
LABEL org.opencontainers.image.source="https://github.com/EonsofStupid/totalrecall"
LABEL org.opencontainers.image.vendor="EonsofStupid"

CMD ["./entrypoint.sh"]
