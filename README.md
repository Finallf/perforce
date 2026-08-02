# Perforce Helix Core — Unreal Engine ready (Debian slim)

Docker image of the **Perforce Helix Core (`p4d`)** server, ready for **Unreal
Engine** development: Unicode mode, security level 3, **case-sensitive** handling
and the **Unreal typemap** already applied (binary assets get `binary+l` =
exclusive **file locking**).

Built from the **official Perforce binaries** (fetched from the public FTP), on
top of `debian:13-slim` in a multi-stage build.

## Install method

Installed the official way — the Perforce apt repository + the **`p4-server`**
package — and bootstrapped with the official **`configure-p4d.sh`** (which
creates the super-user, sets the password, enables Unicode and keeps
case-sensitivity). The apt repo targets Ubuntu, so the `noble` (24.04) codename
is used on Debian; the packages are plain ELF x86_64 and install on a recent
Debian.

## Build & deploy

Same flow as the other stacks (build → tag `latest` → push to Docker Hub):

```bash
./deploy.sh v1.0.0
```

Releases are also automated on GitHub (semantic-release → CHANGELOG + GitHub
release + Docker Hub push). See `CONTRIBUTING.md` for the commit convention.

The Helix Core version tracks whatever the Perforce apt repo currently ships for
the `p4-server` package.

## Configuration

Set these in the `.env` / Portainer stack env vars:

| Variable | Example | Description |
|----------|---------|-------------|
| `SSD`    | `/mnt/ssd/Tools`     | Base folder for the data (SSD dataset) |
| `PASS`   | `YourStrongPass123`  | `admin` super-user password (min 8, upper + lower + digit) |
| `TZ`     | `America/Sao_Paulo`  | Timezone |

> `p4d` runs as **`PUID:PGID`** (default `1000:1000`), so the `${SSD}/perforce`
> folder ends up owned by that UID/GID on the host — set them to your host user
> to manage the folder directly. The server data lives in `${SSD}/perforce/root`.

> ⚠️ The password and options (unicode, security, case) are written on the
> **first run**. Changing them afterwards requires recreating from scratch
> (delete `${SSD}/perforce`).

## Run

```bash
docker compose up -d
```

Port **1666** (Perforce protocol — no web UI; use **P4V**).

## Connect (P4V / UE)

- **Server (P4PORT):** `<HOST_IP>:1666` — or `ssl:<HOST_IP>:1666` when `P4SSL=true`
- **User:** `admin`  ·  **Charset:** `unicode (utf8)`
- Password: the value set in `PASS`

In Unreal Engine: **Revision Control → Perforce**, same details.

## SSL / public exposure

By default the server runs in plaintext (fine on a trusted LAN or VPN). To
expose it directly on the internet, set **`P4SSL=true`**: the entrypoint
generates a self-signed certificate in `P4SSLDIR` (default `/p4/ssl`, persisted
in the volume) and serves on `ssl:1666`. Clients then connect with
**`ssl:<host>:1666`** and accept the certificate fingerprint on first use
(P4V prompts; the CLI uses `p4 trust -y`).

## Typemap

The Unreal typemap is applied during bootstrap (see `app/entrypoint.sh`):
`.uasset`, `.umap`, `.upk`, `.udk` as `binary+l` (exclusive lock — no two people
edit the same Blueprint at once); other binaries as `binary+w`; source/config as
`text`.
