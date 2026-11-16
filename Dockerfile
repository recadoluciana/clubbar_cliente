# Etapa 1: build do Flutter Web
FROM ubuntu:24.04 AS build

# A imagem Cirrus "stable" pode ficar atrás do SDK exigido pelo aplicativo.
# Instale a versão oficial validada também nos builds Android/iOS.
ARG FLUTTER_VERSION=3.50.0
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web && flutter --version

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

ARG API_BASE_URL=https://api.clubbar.com.br
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN sed -i "s|__API_BASE_URL__|${API_BASE_URL%/}|g" /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
