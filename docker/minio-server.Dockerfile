# MinIO Community build from the official, pinned upstream source.
# Upstream release is AGPLv3 and unmaintained; see docs/MIGRACAO_MINIO_EVIDENCIAS.md.
FROM golang:1.24.8-bookworm AS build

ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG MINIO_RELEASE=RELEASE.2025-10-15T17-29-55Z
ARG MINIO_COMMIT=9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init \
    && git remote add origin https://github.com/minio/minio.git \
    && git fetch --depth=1 origin "refs/tags/${MINIO_RELEASE}:refs/tags/${MINIO_RELEASE}" \
    && test "$(git rev-parse "refs/tags/${MINIO_RELEASE}^{commit}")" = "${MINIO_COMMIT}" \
    && git checkout --detach "${MINIO_COMMIT}"

RUN set -eu; \
    release_date="${MINIO_RELEASE#RELEASE.}"; \
    ldflags="$(MINIO_RELEASE=RELEASE go run buildscripts/gen-ldflags.go "${release_date}")"; \
    mkdir -p /out; \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      go build -tags kqueue -trimpath -ldflags "${ldflags}" -o /out/minio .

FROM debian:bookworm-slim AS runtime
ENV HOME=/tmp
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 minio \
    && useradd --system --uid 10001 --gid minio --home-dir /tmp --shell /usr/sbin/nologin minio \
    && install -d -o 10001 -g 10001 -m 0750 /data
COPY --from=build --chown=10001:10001 /out/minio /usr/local/bin/minio
USER 10001:10001
WORKDIR /data
EXPOSE 9000 9001
ENTRYPOINT ["/usr/local/bin/minio"]
