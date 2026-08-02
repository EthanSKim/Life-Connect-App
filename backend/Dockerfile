FROM node:20-alpine

# curl is needed for the HEALTHCHECK below (alpine doesn't ship it by default).
# tzdata is needed for TZ below to actually work - alpine ships no timezone
# data at all by default, so without this the TZ env var is silently a no-op.
RUN apk add --no-cache curl tzdata

# The authoritative "today"/"now" for reservations, attendance, and
# finalization all come from Postgres (set to America/New_York in
# docker-compose.yml), not from this container's clock. This is set anyway
# so log timestamps read correctly and any future code that reaches for
# Node's local Date behaves correctly by default rather than defaulting to
# UTC. America/New_York (not a fixed UTC-5 offset) so DST is handled
# automatically.
ENV TZ=America/New_York

WORKDIR /app

# Install dependencies first (better layer caching - only reruns npm install
# when package*.json actually changes)
COPY package*.json ./
RUN npm install --omit=dev

# Copy the rest of the backend source
COPY . .

# Run as a non-root user (node:20-alpine ships a built-in unprivileged 'node' user)
RUN chown -R node:node /app
USER node

EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=5 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "index.js"]
