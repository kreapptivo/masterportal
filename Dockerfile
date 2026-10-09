ARG NODE_VERSION=24
ARG MP_VERSION=v3.27.1
ARG CONTAINER_REGISTRY=docker.io

# ---- build stage: compile Masterportal from source ----
FROM ${CONTAINER_REGISTRY}/node:${NODE_VERSION}-bookworm-slim AS build
ARG MP_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://bitbucket.org/geowerkstatt-hamburg/masterportal.git \
    --branch ${MP_VERSION} --single-branch --depth 1 /masterportal

WORKDIR /masterportal
RUN npm ci
RUN npm run buildPortal

# The built portal references ../mastercode; with the portal served from the
# webroot and mastercode as a subfolder, the path must be relative to root.
RUN sed -i 's|\.\./mastercode/|mastercode/|g' /masterportal/dist/basic/index.html /masterportal/dist/basic/config.js

# busybox provides a static wget for the HEALTHCHECK (no shell in scratch)
FROM ${CONTAINER_REGISTRY}/busybox:stable-musl AS busybox

# ---- runtime stage: static-web-server (distroless, scratch-based) ----
FROM ${CONTAINER_REGISTRY}/joseluisq/static-web-server:2

ENV SERVER_PORT=8080 \
    SERVER_ROOT=/srv \
    SERVER_HEALTH=true \
    SERVER_LOG_LEVEL=info

COPY --from=build /masterportal/dist/mastercode /srv/mastercode
COPY --from=build /masterportal/dist/basic/ /srv/
COPY --from=busybox /bin/wget /usr/bin/wget

# Non-root for restricted Pod Security Standards; port 8080 is unprivileged.
USER 1000:1000
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/usr/bin/wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/health"]
