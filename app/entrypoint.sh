#!/usr/bin/env bash
#
# Perforce Helix Core (p4d) entrypoint -- Unreal Engine ready.
#
# The container starts as root only to align the 'perforce' user with the host
# (PUID/PGID) and to run the one-time bootstrap; the p4d server itself then runs
# as the unprivileged 'perforce' user, so the data volume stays owned by a user
# you control on the host.
#
#   * First run: bootstraps the server with the official configure-p4d.sh
#       - creates the super-user and sets its password
#       - enables Unicode mode, keeps case-sensitivity (the default)
#     then logs in, applies the Unreal typemap, raises the security level and
#     registers the server in the topology.
#   * Subsequent runs: just start p4d in the foreground (PID 1).
#
set -euo pipefail

# --- Config (overridable via environment) ------------------------------------
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${P4ROOT:=/p4/root}"
: "${P4PORT:=1666}"
: "${P4USER:=admin}"
: "${P4NAME:=perforce}"
: "${P4CHARSET:=utf8}"
: "${P4PASSWD:?ERROR: set the P4PASSWD environment variable (admin super-user password)}"

# Keep the password out of the environment; the p4 client authenticates via the
# ticket created by 'p4 login' instead.
ADMIN_PW="${P4PASSWD}"
unset P4PASSWD

P4="p4 -p localhost:${P4PORT} -u ${P4USER} -C ${P4CHARSET}"
log() { echo ">> [entrypoint] $*"; }

# --- Align the 'perforce' user/group with the host --------------------------
# The p4-server package creates 'perforce' with an internal UID/GID; remap it to
# PUID/PGID so the mounted data volume is owned by a user you control (and so
# 'perforce' inside the container == e.g. 'umedia' on the host).
log "Aligning the perforce user to ${PUID}:${PGID}..."
groupmod -o -g "${PGID}" perforce
usermod  -o -u "${PUID}" -g "${PGID}" perforce
chown -R perforce:perforce /opt/perforce /etc/perforce 2>/dev/null || true

mkdir -p "${P4ROOT}"
chown perforce:perforce /p4 "${P4ROOT}" 2>/dev/null || true

# --- First-run bootstrap (official installer) --------------------------------
if [ ! -f "${P4ROOT}/db.domain" ]; then
    log "First run -- bootstrapping with the official configure-p4d.sh..."
    # configure-p4d.sh treats -r as the BASE directory and creates the real
    # P4ROOT as <base>/root. Passing the PARENT of P4ROOT lands the db exactly
    # at ${P4ROOT} (matching the 'p4d' start below).
    /opt/perforce/sbin/configure-p4d.sh "${P4NAME}" -n \
        -p "${P4PORT}" \
        -r "$(dirname "${P4ROOT}")" \
        -u "${P4USER}" \
        -P "${ADMIN_PW}" \
        --unicode

    # configure-p4d.sh sets up (and starts) the service via p4dctl. Make sure it
    # is running, then finish the Unreal-specific configuration.
    p4dctl start "${P4NAME}" >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do
        ${P4} info >/dev/null 2>&1 && break
        sleep 1
    done

    log "Logging in as '${P4USER}'..."
    echo "${ADMIN_PW}" | ${P4} login

    # Unreal Engine typemap:
    #   binary+l => non-mergeable assets with an EXCLUSIVE lock (file locking)
    #   binary+w => regular binaries (always writable on the client)
    #   text     => source/config (mergeable as usual)
    log "Applying the Unreal Engine typemap (lock on binaries)..."
    ${P4} typemap -i <<'TYPEMAP'
TypeMap:
	binary+l //....uasset
	binary+l //....umap
	binary+l //....upk
	binary+l //....udk
	binary+w //....exe
	binary+w //....dll
	binary+w //....lib
	binary+w //....pdb
	binary+w //....so
	binary+w //....a
	binary+w //....dylib
	binary+w //....stub
	binary+w //....ipa
	binary+w //....bmp
	binary+w //....png
	binary+w //....jpg
	binary+w //....jpeg
	binary+w //....gif
	binary+w //....tga
	binary+w //....tif
	binary+w //....tiff
	binary+w //....dds
	binary+w //....psd
	binary+w //....xcf
	binary+w //....ico
	binary+w //....wav
	binary+w //....mp3
	binary+w //....ogg
	binary+w //....flac
	binary+w //....avi
	binary+w //....mov
	binary+w //....mp4
	binary+w //....mpg
	binary+w //....webm
	binary+w //....fbx
	binary+w //....obj
	binary+w //....3ds
	binary+w //....abc
	binary+w //....glb
	binary+w //....gltf
	binary+w //....ttf
	binary+w //....otf
	binary+w //....pfx
	binary+w //....zip
	binary+w //....rar
	binary+w //....7z
	binary+w //....gz
	text //....cpp
	text //....c
	text //....cc
	text //....h
	text //....hpp
	text //....inl
	text //....cs
	text //....ini
	text //....cfg
	text //....txt
	text //....md
	text //....xml
	text //....json
	text //....uproject
	text //....uplugin
TYPEMAP

    log "Hardening (security level 3)..."
    ${P4} configure set security=3
    ${P4} configure set run.users.authorize=1
    ${P4} configure set dm.user.noautocreate=2

    log "Registering the server spec in the topology..."
    ${P4} server -i <<SERVERSPEC
ServerID: ${P4NAME}
Type: server
Name: ${P4NAME}
Services: standard
Description:
	Standalone Helix Core server (Unreal Engine ready).
SERVERSPEC

    log "Stopping the bootstrap service..."
    p4dctl stop "${P4NAME}" >/dev/null 2>&1 || ${P4} admin stop >/dev/null 2>&1 || true
    sleep 2

    # Make sure everything the bootstrap created is owned by the host user.
    chown -R perforce:perforce "$(dirname "${P4ROOT}")"
else
    log "Server already initialized -- starting normally."
fi

# --- Start p4d as the unprivileged 'perforce' user (PID 1) -------------------
log "Starting p4d as perforce (${PUID}:${PGID}) on port ${P4PORT} (root=${P4ROOT})..."
exec setpriv --reuid="${PUID}" --regid="${PGID}" --clear-groups \
    p4d -r "${P4ROOT}" -p "${P4PORT}"
