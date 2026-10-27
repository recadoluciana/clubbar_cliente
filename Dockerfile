# Etapa 1: build do Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY . .

RUN flutter pub get

ARG API_BASE_URL=https://api.clubbar.com.br
ARG APP_WEB_URL=https://app.clubbar.com.br
ARG SITE_URL=https://clubbar.com.br
ARG GOOGLE_OAUTH_CLIENT_ID=""
ARG APPLE_SERVICE_ID=""
ARG APPLE_REDIRECT_URI=""

RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=APP_WEB_URL=${APP_WEB_URL} \
    --dart-define=SITE_URL=${SITE_URL} \
    --dart-define=GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID} \
    --dart-define=APPLE_SERVICE_ID=${APPLE_SERVICE_ID} \
    --dart-define=APPLE_REDIRECT_URI=${APPLE_REDIRECT_URI}

# Etapa 2: servidor Nginx
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
