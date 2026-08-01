# Perforce Helix Core — Unreal Engine ready (Debian slim)

Docker image of the **Perforce Helix Core (`p4d`)** server, ready for **Unreal
Engine** development: Unicode mode, security level 3, **case-sensitive** handling
and the **Unreal typemap** already applied (binary assets get `binary+l` =
exclusive **file locking**).

Built from the **official Perforce binaries** (fetched from the public FTP), on
top of `debian:13-slim` in a multi-stage build.

## Why standalone binaries (and not apt)?

Perforce's apt repository only targets **Ubuntu**. To keep the stack's **Debian**
base, the image downloads the official `p4d`/`p4` binaries directly from
`https://ftp.perforce.com/perforce/<release>/bin.linux26x86_64/` — they run on any
modern Linux, and the pinned URL keeps the build reproducible and traceable.

## Build & deploy

Same flow as the other stacks (build → tag `latest` → push to Docker Hub):

```bash
./deploy.sh v1.0.0
```

Releases are also automated on GitHub (semantic-release → CHANGELOG + GitHub
release + Docker Hub push). See `CONTRIBUTING.md` for the commit convention.

To change the Helix Core version, adjust `ARG P4_RELEASE` in the `Dockerfile`
(release list: <https://ftp.perforce.com/perforce/>).

## Configuration

Set these in the `.env` / Portainer stack env vars:

| Variable | Example | Description |
|----------|---------|-------------|
| `SSD`    | `/mnt/ssd/Tools`     | Base folder for the data (SSD dataset) |
| `PASS`   | `YourStrongPass123`  | `admin` super-user password (min 8, upper + lower + digit) |
| `TZ`     | `America/Sao_Paulo`  | Timezone |

> The container runs as **root**, so it writes to the mounted `${SSD}/perforce`
> folder regardless of host ownership. The server data lives in `${SSD}/perforce/root`.

> ⚠️ The password and options (unicode, security, case) are written on the
> **first run**. Changing them afterwards requires recreating from scratch
> (delete `${SSD}/perforce`).

## Run

```bash
docker compose up -d
```

Port **1666** (Perforce protocol — no web UI; use **P4V**).

## Connect (P4V / UE)

- **Server (P4PORT):** `<HOST_IP>:1666`  *(no `ssl:` — plaintext on the LAN)*
- **User:** `admin`  ·  **Charset:** `unicode (utf8)`
- Password: the value set in `PASS`

In Unreal Engine: **Revision Control → Perforce**, same details.

## Security / remote access

The server runs in **plaintext** — best kept behind a **VPN** (e.g. WireGuard)
for remote collaborators, instead of exposing port 1666 to the internet.

## Typemap

The Unreal typemap is applied during bootstrap (see `app/entrypoint.sh`):
`.uasset`, `.umap`, `.upk`, `.udk` as `binary+l` (exclusive lock — no two people
edit the same Blueprint at once); other binaries as `binary+w`; source/config as
`text`.
