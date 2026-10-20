<p align="center">
  <a href="https://hub.docker.com/r/senlabs/flarum/tags?page=1&ordering=last_updated"><img src="https://img.shields.io/github/v/tag/sen-laboratories/docker-flarum?label=version&style=flat-square" alt="Latest Version"></a>
  <a href="https://github.com/sen-laboratories/docker-flarum/actions?workflow=build"><img src="https://img.shields.io/github/actions/workflow/status/sen-laboratories/docker-flarum/build.yml?branch=main&label=build&logo=github&style=flat-square" alt="Build Status"></a>
  <a href="https://hub.docker.com/r/senlabs/flarum/"><img src="https://img.shields.io/docker/pulls/senlabs/flarum.svg?style=flat-square&logo=docker" alt="Docker Pulls"></a>
</p>

## About

Docker image for [Flarum](https://flarum.org/) 2.0, the next-generation forum
software that makes online discussion fun.

This is the SEN Labs flavor of [crazy-max/docker-flarum](https://github.com/crazy-max/docker-flarum) (thanks!),
which is still on Flarum 1.8. It differs in these points:

| | |
|---|---|
| Flarum | 2.0.x (`v2.0.2`), with the extensions of the 2.0 skeleton (approval, bbcode, deck, emoji, flags, gdpr, likes, lock, markdown, mentions, messages, nicknames, realtime, statistics, sticky, subscriptions, suspend, tags, ...) |
| Extra extensions | [`fof/oauth`](https://github.com/FriendsOfFlarum/oauth), [`sen-labs/oauth-authelia`](https://github.com/sen-laboratories/flarum-oauth-authelia) v1.0.2 (Authelia OIDC login), `fof/follow-tags`, `fof/links`, `fof/gamification` |
| Runtime | Alpine 3.24, PHP 8.5, nginx, s6-overlay |
| Database | MariaDB (recommended 11.8+, tested with 10.11, 11.8 and 13.0) or MySQL; the driver is detected, see `DB_DRIVER` |
| Realtime | optional websocket daemon as s6 service, see [Realtime](#realtime) |

`fof/links` and `fof/gamification` have no stable 2.0 release yet, so they are installed as release candidate and beta.

> [!TIP] 
> Want to be notified of new releases? Check out 🔔 [Diun (Docker Image Update Notifier)](https://github.com/crazy-max/diun)
> project!

___

* [Features](#features)
* [Build locally](#build-locally)
* [Image](#image)
* [Environment variables](#environment-variables)
  * [General](#general)
  * [Flarum](#flarum)
  * [Realtime](#realtime)
  * [Database](#database)
* [Volumes](#volumes)
* [Ports](#ports)
* [Usage](#usage)
  * [Docker Compose](#docker-compose)
  * [Command line](#command-line)
* [Upgrade](#upgrade)
* [Notes](#notes)
  * [First launch](#first-launch)
  * [Manage extensions](#manage-extensions)
  * [Sending mails with SMTP](#sending-mails-with-smtp)
* [Contributing](#contributing)
* [License](#license)

## Features

* Flarum 2.0 on PHP 8.5, run as non-root user
* Multi-platform image
* Optional [Realtime](#realtime) websocket service
* Authelia OIDC login through `sen-labs/oauth-authelia`
* [s6-overlay](https://github.com/just-containers/s6-overlay/) as process supervisor
* [msmtpd SMTP relay](https://github.com/crazy-max/docker-msmtpd) image to send emails
* [Traefik](https://github.com/containous/traefik-library-image) as reverse proxy and creation/renewal of Let's Encrypt certificates (see [this template](examples/traefik))

## Build locally

```shell
git clone https://github.com/sen-laboratories/docker-flarum.git
cd docker-flarum

# Build image and output to docker (default)
docker buildx bake

# Build multi-platform image
docker buildx bake image-all
```

## Image

| Registry                                                                                          | Image                      |
|---------------------------------------------------------------------------------------------------|----------------------------|
| [Docker Hub](https://hub.docker.com/r/senlabs/flarum/)                                            | `senlabs/flarum`           |
| [GitHub Container Registry](https://github.com/orgs/sen-laboratories/packages/container/package/flarum) | `ghcr.io/sen-laboratories/flarum` |

Tags: `latest` and the Flarum version (e.g. `2.0.2`) from the `main` branch, `edge` for the latest build.

Following platforms for this image are available:

```
$ docker buildx imagetools inspect senlabs/flarum --format "{{json .Manifest}}" | \
  jq -r '.manifests[] | select(.platform.os != null and .platform.os != "unknown") | .platform | "\(.os)/\(.architecture)\(if .variant then "/" + .variant else "" end)"'

linux/amd64
linux/arm/v6
linux/arm/v7
linux/arm64
```

## Environment variables

### General

* `TZ`: The timezone assigned to the container (default `UTC`)
* `PUID`: Flarum user id (default `1000`)
* `PGID`: Flarum group id (default `1000`)
* `MEMORY_LIMIT`: PHP memory limit (default `256M`)
* `UPLOAD_MAX_SIZE`: Upload max size (default `16M`)
* `CLEAR_ENV`: Clear environment in FPM workers (default `yes`)
* `OPCACHE_MEM_SIZE`: PHP OpCache memory consumption (default `128`)
* `LISTEN_IPV6`: Enable IPv6 for Nginx (default `true`)
* `REAL_IP_FROM`: Trusted addresses that are known to send correct replacement addresses (default `0.0.0.0/32`)
* `REAL_IP_HEADER`: Request header field whose value will be used to replace the client address (default `X-Forwarded-For`)
* `LOG_IP_VAR`: Use another variable to retrieve the remote IP address for access [log_format](http://nginx.org/en/docs/http/ngx_http_log_module.html#log_format) on Nginx. (default `remote_addr`)

### Flarum

* `FLARUM_DEBUG`: Enables or disables debug mode, used to troubleshoot issues (default `false`)
* `FLARUM_BASE_URL`: The URL to your Flarum installation **required**
* `FLARUM_FORUM_TITLE`: Flarum forum title, only used during first installation (default `Flarum Dockerized`)
* `FLARUM_API_PATH`: Flarum api path (default `api`)
* `FLARUM_ADMIN_PATH`: Flarum admin path (default `admin`)
* `FLARUM_POWEREDBY_HEADER`: Set Flarum's `X-Powered-By` header (default `true`)
* `FLARUM_REFERRER_POLICY`: Referrer policy (default `same-origin`)
* `FLARUM_COOKIE_SAMESITE`: Set `SameSite` attribute of `Set-Cookie` (default `lax`)

### Realtime

The `flarum/realtime` extension needs a websocket daemon. With `FLARUM_REALTIME=true` it is started as an s6 service
(it waits until the extension is enabled and restarts itself whenever an extension is toggled) and nginx proxies
the browser's websocket route `/app/<key>` to it, so no extra port has to be published. Enable the extension
(`php flarum extension:enable flarum-realtime`); reverse proxies in front of the container must pass websocket upgrades.

* `FLARUM_REALTIME`: Run the Realtime websocket daemon (default `false`)
* `FLARUM_REALTIME_PORT`: Port the daemon listens on, localhost only (default `6001`)
* `FLARUM_REALTIME_JS_PORT`: Port the browser connects to (default: port of `FLARUM_BASE_URL`, `443` for https, `80` for http)

### Database

* `DB_HOST`: MySQL database hostname / IP address **required**
* `DB_PORT`: MySQL database port (default `3306`)
* `DB_DRIVER`: Flarum database driver, `mysql` or `mariadb` (default: detected from the server version)
* `DB_NAME`: MySQL database name (default `flarum`)
* `DB_USER`: MySQL user (default `flarum`)
* `DB_PASSWORD`: MySQL password
* `DB_PREFIX`: MySQL database prefix (default `flarum_`)
* `DB_NOPREFIX`: Enforce no prefix for the MySQL database (default `false`)
* `DB_TIMEOUT`: Time in seconds after which we stop trying to reach the MySQL server (useful for clusters, default `60`)

> [!NOTE]
> `DB_USER_FILE` and `DB_PASSWORD_FILE` can be used to fill in the value from a
> file, especially for Docker's secrets feature.

## Volumes

* `/data`: Contains assets, extensions and storage

> [!WARNING]
> Note that the volume should be owned by the user/group with the specified
> `PUID` and `PGID`. If you don't give the volume correct permissions, the
> container may not start.

## Ports

* `8000`: HTTP port

## Usage

### Docker Compose

Docker compose is the recommended way to run this image. You can use the following
[docker compose template](examples/compose/compose.yml), then run the container:

```bash
docker compose up -d
docker compose logs -f
```

### Command line

You can also use the following minimal command:

```bash
docker run -d -p 8000:8000 --name flarum \
  -v $(pwd)/data:/data \
  -e "DB_HOST=db" \
  -e "FLARUM_BASE_URL=http://127.0.0.1:8000" \
  senlabs/flarum:latest
```

> [!WARNING]
> `db` must be a running MariaDB (recommended, 11.8 or later) or MySQL instance. Official `mariadb` images 11 and later
> have no `mysqld` command anymore, use `mariadbd` if you set a `command`.

## Upgrade

Recreate the container to upgrade; pending database migrations of Flarum and its extensions run on start:

```bash
docker compose pull
docker compose up -d
```

Take a backup first (a ZFS snapshot of the `/data` and database volumes, or a `mariadb-dump`), migrations cannot be
undone by going back to an older image.

Upgrading from Flarum 1.x with this image is not supported, follow the
[Flarum 2.0 upgrade guide](https://docs.flarum.org/2.x/update) first. Pin the image to a Flarum version (e.g.
`senlabs/flarum:2.0.2`) to decide yourself when to upgrade. The database driver (`mysql` or `mariadb`) is written to
`config.php` on every start from the detected server, so a switch between the two needs no manual edit.

## Notes

### First launch

On first launch, an initial administrator user will be created:

| Login    | Password |
|----------|----------|
| `flarum` | `flarum` |

### Manage extensions

You can install [Flarum extensions](https://extiverse.com/) from the command line using a
[specially crafted script](rootfs/usr/local/bin/extension) with this image:

`docker compose exec flarum extension require <package> [<package> ...]`

To remove one or more extensions:

`docker compose exec flarum extension remove <package> [<package> ...]`

To list all extensions:

`docker compose exec flarum extension list`

Example with [`fof/upload`](https://extiverse.com/extension/fof/upload) extension:

```
$ docker compose exec flarum extension require fof/upload
Using version ^1.0 for fof/upload
./composer.json has been updated
Running composer update fof/upload
Loading composer repositories with package information
Updating dependencies
Lock file operations: 5 installs, 0 updates, 0 removals
  - Locking fof/upload (1.0.0)
  - Locking guzzlehttp/guzzle (7.3.0)
  - Locking guzzlehttp/promises (1.4.1)
  - Locking psr/http-client (1.0.1)
  - Locking softcreatr/php-mime-detector (3.2.0)
Writing lock file
Installing dependencies from lock file (including require-dev)
Package operations: 5 installs, 0 updates, 0 removals
  - Downloading softcreatr/php-mime-detector (3.2.0)
  - Downloading psr/http-client (1.0.1)
  - Downloading guzzlehttp/promises (1.4.1)
  - Downloading guzzlehttp/guzzle (7.3.0)
  - Downloading fof/upload (1.0.0)
  - Installing softcreatr/php-mime-detector (3.2.0): Extracting archive
  - Installing psr/http-client (1.0.1): Extracting archive
  - Installing guzzlehttp/promises (1.4.1): Extracting archive
  - Installing guzzlehttp/guzzle (7.3.0): Extracting archive
  - Installing fof/upload (1.0.0): Extracting archive
2 package suggestions were added by new dependencies, use `composer suggest` to see details.
Generating autoload files
70 packages you are using are looking for funding.
Use the `composer fund` command to find out more!
fof/upload extension added
Clearing the cache...
```

> [!WARNING]
> You cannot use [Bazaar marketplace extension](https://discuss.flarum.org/d/5151-bazaar-the-extension-marketplace)
> to install extensions for now.

### Sending mails with SMTP

You can use our SMTP relay `msmtpd` service published on port `2500` and
declared in our [`compose.yml`](examples/compose/compose.yml):

![](.github/smtp-settings.png)

## Contributing

Issues and pull requests are welcome. The most basic way to show your support is to star the project.

This image is based on [crazy-max/docker-flarum](https://github.com/crazy-max/docker-flarum), consider
[sponsoring](https://github.com/sponsors/crazy-max) the upstream author as well.

## License

MIT. See `LICENSE` for more details.
