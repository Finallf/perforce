#!/usr/bin/env bash
#
# Perforce Helix Core (p4d) entrypoint -- Unreal Engine ready.
#
#   * First run: initializes the server
#       - Unicode mode
#       - case-SENSITIVE handling (p4d default on Linux -- matches the game's
#         Linux dedicated server and catches case bugs early)
#       - super-user 'admin' with the password from P4PASSWD
#       - security level 3 (high) + hardening
#       - Unreal typemap (binary assets = binary+l => exclusive lock)
#   * Subsequent runs: just start p4d in the foreground (PID 1)
#
set -euo pipefail

# --- Config (overridable via environment) ------------------------------------
: "${P4ROOT:=/p4/root}"
: "${P4PORT:=1666}"
: "${P4USER:=admin}"
: "${P4CHARSET:=utf8}"
: "${P4SERVERID:=perforce}"
: "${P4PASSWD:?ERROR: set the P4PASSWD environment variable (admin super-user password)}"

# Keep the password in a local variable and remove it from the environment.
# Otherwise the p4 CLIENT tries to authenticate with P4PASSWD on every command,
# which fails during bootstrap (before the user/password exist) with
# "Perforce password (P4PASSWD) invalid or unset". A ticket from 'p4 login'
# authenticates the remaining steps instead.
ADMIN_PW="${P4PASSWD}"
unset P4PASSWD

export P4ROOT P4PORT P4USER P4CHARSET

# p4 client helper pointing at the local server
P4="p4 -p localhost:${P4PORT} -u ${P4USER} -C ${P4CHARSET}"

log() { echo ">> [entrypoint] $*"; }

mkdir -p "${P4ROOT}"

# --- First-run bootstrap -----------------------------------------------------
if [ ! -f "${P4ROOT}/db.domain" ]; then
    log "First run detected -- initializing the Perforce server..."

    # 1) Enable Unicode mode (offline op, before starting the server)
    log "Enabling Unicode mode..."
    p4d -r "${P4ROOT}" -xi

    # 1b) Set the server ID (offline). Without it p4d logs a
    #     "topologyRegistration / No entries made in db.topology" warning on
    #     every start. Together with the server spec created below, the server
    #     registers itself cleanly in the topology.
    log "Setting the server ID to '${P4SERVERID}'..."
    p4d -r "${P4ROOT}" -xD "${P4SERVERID}"

    # 2) Start a temporary p4d (background) only to configure it
    log "Starting a temporary p4d for configuration..."
    p4d -r "${P4ROOT}" -p "${P4PORT}" &
    BOOTSTRAP_PID=$!

    # 3) Wait for the server to accept connections (up to ~30s)
    for _ in $(seq 1 30); do
        ${P4} info >/dev/null 2>&1 && break
        sleep 1
    done

    # 4) Create the super-user (the first user on an empty db becomes super)
    log "Creating super-user '${P4USER}'..."
    ${P4} user -i <<USERSPEC
User: ${P4USER}
Email: ${P4USER}@localhost
FullName: Perforce Super User
USERSPEC

    # 5) Set the super-user password (server still at low security)
    log "Setting the super-user password..."
    ${P4} passwd -P "${ADMIN_PW}" "${P4USER}"

    # 6) Log in (creates the ticket -- required after raising security)
    echo "${ADMIN_PW}" | ${P4} login

    # 6b) Register the server spec so the server appears in the topology
    #     (pairs with the server ID set above and clears the db.topology
    #     warning on every start).
    log "Creating the server spec '${P4SERVERID}'..."
    ${P4} server -i <<SERVERSPEC
ServerID: ${P4SERVERID}
Type: server
Name: ${P4SERVERID}
Services: standard
Description:
	Standalone Helix Core server (Unreal Engine ready).
SERVERSPEC

    # 7) Security (level 3 / high) + hardening
    log "Applying security level 3 and hardening..."
    ${P4} configure set security=3
    ${P4} configure set run.users.authorize=1
    ${P4} configure set dm.user.noautocreate=2   # only admins can create users
    ${P4} configure set net.autotune=1

    # 8) Unreal Engine typemap
    #    binary+l  => non-mergeable assets with an EXCLUSIVE lock (file locking)
    #    binary+w  => regular binaries (always writable on the client)
    #    text      => source/config (mergeable as usual)
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

    # 9) Stop the temporary server (the final exec starts it for good)
    log "Bootstrap complete. Stopping the temporary server..."
    ${P4} admin stop
    wait "${BOOTSTRAP_PID}" 2>/dev/null || true
else
    log "Server already initialized -- starting normally."
fi

# --- Start p4d in the foreground (PID 1) -------------------------------------
log "Starting p4d on port ${P4PORT} (root=${P4ROOT})..."
exec p4d -r "${P4ROOT}" -p "${P4PORT}"
