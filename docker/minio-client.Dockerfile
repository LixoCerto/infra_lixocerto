# MinIO Client build from the official, pinned source release.
# The upstream repository is archived/read-only and the client is AGPLv3.
FROM golang:1.24.8-bookworm AS build

ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG MC_RELEASE=RELEASE.2025-08-13T08-35-41Z
ARG MC_COMMIT=7394ce0dd2a80935aded936b09fa12cbb3cb8096

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init \
    && git remote add origin https://github.com/minio/mc.git \
    && git fetch --depth=1 origin "refs/tags/${MC_RELEASE}:refs/tags/${MC_RELEASE}" \
    && test "$(git rev-parse "refs/tags/${MC_RELEASE}^{commit}")" = "${MC_COMMIT}" \
    && git checkout --detach "${MC_COMMIT}"

RUN mkdir -p /out \
    && CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      go build -trimpath -o /out/mc .

FROM debian:bookworm-slim AS runtime
ENV HOME=/tmp
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates coreutils \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 mc \
    && useradd --system --uid 10001 --gid mc --home-dir /tmp --shell /usr/sbin/nologin mc
COPY --from=build --chown=10001:10001 /out/mc /usr/local/bin/mc
COPY --chown=10001:10001 minio-bootstrap.sh /usr/local/bin/minio-bootstrap.sh
# Windows Git checkouts can convert LF to CRLF. Normalize the script in-image
# before /bin/sh parses it so the container entrypoint is portable.
RUN tr -d '\r' < /usr/local/bin/minio-bootstrap.sh > /tmp/minio-bootstrap.sh \
    && install -o 10001 -g 10001 -m 0555 /tmp/minio-bootstrap.sh /usr/local/bin/minio-bootstrap.sh \
    && rm /tmp/minio-bootstrap.sh
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/mc"]
