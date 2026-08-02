# --- Build stage: compile the Flutter app for web ---
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Pull dependencies first for better layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source and build the release web bundle.
# API_BASE_URL is baked in at build time (see lib/config.dart) instead of
# being hardcoded in source - override it via the API_BASE_URL build arg
# (wired through docker-compose.yml -> .env) for non-local deployments.
ARG API_BASE_URL=http://localhost:3000
COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# --- Runtime stage: serve the compiled web app with nginx ---
FROM nginx:alpine

RUN apk add --no-cache curl

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=5 \
  CMD curl -f http://localhost:80/ || exit 1
