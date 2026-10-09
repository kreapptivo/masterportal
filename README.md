# Masterportal Docker Image

A minimal, distroless Docker image serving [Masterportal](https://www.masterportal.org/)
with [static-web-server](https://static-web-server.net/) (scratch-based, ~20 MB
total). The image ships the upstream `basic` example portal without
customization; the portal configuration is expected to be overridden at deploy
time (e.g. via a Kubernetes ConfigMap).

## Build

```sh
docker build -t masterportal .
```

When building with Podman, pass `--format docker` so the `HEALTHCHECK` is
kept — the default OCI image format does not support it.

The Masterportal version is pinned in the `Dockerfile` (`ARG MP_VERSION`),
which is the single source of truth. To build a different version ad hoc,
override the build argument (Bitbucket tag):

```sh
docker build --build-arg MP_VERSION=v3.27.1 -t masterportal:3.27.1 .
```

The build clones the official Masterportal repository at that tag, runs
`npm run buildPortal`, and copies the result into a scratch-based
`joseluisq/static-web-server:2` runtime image. No addons are included.

## Release

The GitHub Actions workflow [`release.yml`](.github/workflows/release.yml) is
triggered manually (*Actions → Release → Run workflow*). It builds the image
and publishes it to `ghcr.io/<owner>/<repo>` tagged with the version (without
the `v` prefix) and `latest`. The version input is optional — left empty, the
`MP_VERSION` default from the `Dockerfile` is used.

## Run

```sh
docker run --rm -p 8080:8080 masterportal
```

- Portal: <http://localhost:8080/>
- Health check: <http://localhost:8080/health> (returns `200 OK`, suited for
  Kubernetes liveness/readiness probes; not written to the access log)

The container listens on port **8080** and runs as a non-root user (UID 1000),
suitable for the Kubernetes *restricted* Pod Security Standard.

The image defines a `HEALTHCHECK` (a static busybox `wget` against `/health`,
every 30 s) for `docker run` / `podman run` / compose. Note that Kubernetes
ignores Dockerfile healthchecks — configure liveness/readiness probes against
`/health` instead.

## Image layout

| Path                      | Content                                          |
| ------------------------- | ------------------------------------------------ |
| `/srv/index.html`         | Portal entry point                               |
| `/srv/config.json`        | Portal configuration (override in Kubernetes)    |
| `/srv/config.js`          | Portal runtime configuration                     |
| `/srv/resources/`         | Global configs (`services.json`, `style.json` …) |
| `/srv/mastercode/<ver>/`  | Built Masterportal code (JS/CSS/assets)          |

## Kubernetes

Mount your portal configuration over the shipped defaults, e.g.:

```yaml
volumeMounts:
  - name: portal-config
    mountPath: /srv/config.json
    subPath: config.json
```

The same pattern works for `config.js` and files under `/srv/resources/`.
