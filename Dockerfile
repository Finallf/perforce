# syntax=docker/dockerfile:1

# STAGE 1: The Builder (temporary environment)
# Downloads the official standalone Perforce binaries (p4d + p4).
# Perforce's apt repo only supports Ubuntu; the direct binaries run on any
# modern Linux, so we keep the Debian slim base (stack standard).
FROM debian:13-slim AS builder

# Helix Core version (2026.1). IMPORTANT: use a release that ships the standalone
# Linux binaries (p4d/p4) on the public FTP -- the majors (r26.1, r25.2) do, but
# some point releases are partial (r26.2 tools-only, r26.4 Mac/Win only).
# Check before bumping:
#   https://ftp.perforce.com/perforce/<release>/bin.linux26x86_64/
ARG P4_RELEASE=r26.1
ARG P4_ARCH=bin.linux26x86_64
ARG P4_BASEURL=https://ftp.perforce.com/perforce

RUN set -eux \
&&  apt-get -qq update \
&&  apt-get -qq install --no-install-recommends \
    ca-certificates \
    curl \
&&  mkdir -p /perforce \
&&  curl -sSfL "${P4_BASEURL}/${P4_RELEASE}/${P4_ARCH}/p4d" -o /perforce/p4d \
&&  curl -sSfL "${P4_BASEURL}/${P4_RELEASE}/${P4_ARCH}/p4"  -o /perforce/p4  \
&&  chmod +x /perforce/p4d /perforce/p4

# STAGE 2: Final image (Debian 13 Trixie Slim)
FROM debian:13-slim

LABEL Maintainer="Finallf <finallf2@gmail.com>"
LABEL Homepage="reloaded.com.br"
LABEL Description="Perforce Helix Core (p4d) server, Unreal Engine ready, on Debian slim."

# Environment settings:
ENV P4ROOT=/p4/root \
    P4PORT=1666 \
    P4USER=admin \
    P4CHARSET=utf8 \
    UID=1000 \
    GID=0 \
    TZ=UTC \
    DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies (p4d is largely self-contained; needs certs + tz):
RUN set -eux \
&&  apt-get -qq update \
&&  apt-get -qq install --no-install-recommends \
    ca-certificates \
    tzdata \
&&  apt-get -qq clean \
&&  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# Copy the Perforce binaries and the bootstrap entrypoint:
COPY --from=builder /perforce/p4d /usr/local/bin/p4d
COPY --from=builder /perforce/p4  /usr/local/bin/p4
COPY app/ /app/

# Prepare data dir + permissions (non-root user, group 0 writable):
RUN set -eux \
&&  mkdir -p /p4 \
&&  chmod +x /app/entrypoint.sh \
&&  chmod -R g+rwX /p4 /app

WORKDIR /p4
USER $UID:$GID

# Healthcheck: the server answers 'p4 info' once it is up.
HEALTHCHECK --interval=1m --timeout=15s --start-period=45s --retries=3 \
    CMD p4 -p localhost:1666 info >/dev/null 2>&1 || exit 1

EXPOSE 1666
ENTRYPOINT ["/app/entrypoint.sh"]
