# syntax=docker/dockerfile:1

# Helix Core Server (p4d) on Debian, installed the official way:
# the Perforce apt repository + the p4-server package, then bootstrapped with
# the official configure-p4d.sh (see app/entrypoint.sh).
#
# The Perforce apt repo targets Ubuntu; we use the 'noble' (24.04) codename on
# Debian -- the packages are plain ELF x86_64 and install on a recent Debian.
FROM debian:13-slim

LABEL Maintainer="Finallf <finallf2@gmail.com>"
LABEL Homepage="reloaded.com.br"
LABEL Description="Perforce Helix Core (p4d) server, Unreal Engine ready, on Debian."

ENV P4ROOT=/p4/root \
    P4PORT=1666 \
    P4USER=admin \
    P4NAME=perforce \
    P4CHARSET=utf8 \
    TZ=UTC \
    DEBIAN_FRONTEND=noninteractive

# Install the official Helix Core Server package (p4-server) from Perforce.
RUN set -eux \
&&  apt-get -qq update \
&&  apt-get -qq install --no-install-recommends \
    ca-certificates \
    gnupg \
    tzdata \
    wget \
&&  wget -qO - https://package.perforce.com/perforce.pubkey \
      | gpg --dearmor > /usr/share/keyrings/perforce.gpg \
&&  echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] https://package.perforce.com/apt/ubuntu noble release" \
      > /etc/apt/sources.list.d/perforce.list \
&&  apt-get -qq update \
&&  apt-get -qq install --no-install-recommends p4-server \
&&  apt-get -qq clean \
&&  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

COPY app/ /app/

RUN set -eux \
&&  mkdir -p /p4 \
&&  chmod +x /app/entrypoint.sh

WORKDIR /p4

# Healthcheck: the server answers 'p4 info' once it is up.
HEALTHCHECK --interval=1m --timeout=15s --start-period=45s --retries=3 \
    CMD p4 -p localhost:1666 info >/dev/null 2>&1 || exit 1

EXPOSE 1666
ENTRYPOINT ["/app/entrypoint.sh"]
