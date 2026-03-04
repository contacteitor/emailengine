# =============================================================================
# EmailEngine - Dockerfile optimizado para Kubernetes (multi-stage)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: deps — instala dependencias de producción (cacheado si package.json no cambia)
# -----------------------------------------------------------------------------
FROM --platform=${TARGETPLATFORM} node:22-alpine AS deps

WORKDIR /emailengine

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# -----------------------------------------------------------------------------
# Stage 2: builder — copia código y genera version-info
# -----------------------------------------------------------------------------
FROM --platform=${TARGETPLATFORM} node:22-alpine AS builder

ARG COMMIT_SHA
WORKDIR /emailengine

COPY --from=deps /emailengine/node_modules ./node_modules

COPY config config
COPY data data
COPY lib lib
COPY static static
COPY translations translations
COPY views views
COPY workers workers
COPY LICENSE_EMAILENGINE.txt .
COPY package.json .
COPY sbom.json .
COPY server.js .
COPY update-info.sh .

RUN mkdir -p .git/refs/heads && \
    echo "${COMMIT_SHA:-unknown}" > .git/refs/heads/master && \
    chmod +x ./update-info.sh && \
    ./update-info.sh && \
    node -e "require('./node_modules/dotenv')" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Stage 3: production — imagen final mínima
# -----------------------------------------------------------------------------
FROM --platform=${TARGETPLATFORM} node:22-alpine AS production

ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH
ARG COMMIT_SHA
ARG BUILD_TIME

LABEL org.opencontainers.image.title="EmailEngine" \
      org.opencontainers.image.description="Email Sync Engine - Clientify" \
      org.opencontainers.image.vendor="Clientify" \
      org.opencontainers.image.source="https://github.com/contacteitor/emailengine" \
      org.opencontainers.image.revision="${COMMIT_SHA}" \
      org.opencontainers.image.created="${BUILD_TIME}"

RUN apk add --no-cache dumb-init curl

RUN addgroup -S emailenginegroup && adduser -S emailengineuser -G emailenginegroup

WORKDIR /emailengine

COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/node_modules ./node_modules
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/config ./config
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/data ./data
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/lib ./lib
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/static ./static
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/translations ./translations
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/views ./views
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/workers ./workers
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/server.js ./server.js
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/package.json ./package.json
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/sbom.json ./sbom.json
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/version-info.json ./version-info.json
COPY --from=builder --chown=emailengineuser:emailenginegroup /emailengine/LICENSE_EMAILENGINE.txt ./LICENSE_EMAILENGINE.txt

USER emailengineuser

ENV NODE_ENV=production \
    EENGINE_HOST=0.0.0.0 \
    EENGINE_API_PROXY=true

EXPOSE 3000 2525 2993

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD curl -sf http://localhost:3000/health || exit 1

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "/emailengine/server.js"]
