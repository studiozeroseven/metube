# Base Image
FROM node:lts-alpine as builder

WORKDIR /metube
COPY ui ./
RUN npm ci && \
    node_modules/.bin/ng build --configuration production

# Main Image
FROM python:3.11-alpine

WORKDIR /app

COPY Pipfile* docker-entrypoint.sh ./

RUN sed -i 's/\r$//g' docker-entrypoint.sh && \
    chmod +x docker-entrypoint.sh && \
    apk add --update openssh nano ffmpeg aria2 coreutils shadow su-exec curl rsync && \
    apk add --update --virtual .build-deps gcc g++ musl-dev && \
    pip install --no-cache-dir pipenv && \
    pipenv install --system --deploy --clear && \
    pip uninstall pipenv -y && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    mkdir /.cache && chmod 777 /.cache && \
    mkdir /downloads && chmod 777 /downloads && \
    mkdir /cookies && chmod 777 /cookies && touch /cookies/cookies.txt

# Install dependencies and Tailscale
RUN apk add --no-cache curl iptables && \
    curl -fsSL https://pkgs.tailscale.com/stable/alpine/tailscale-stable.apk -o /tmp/tailscale.apk && \
    apk add --allow-untrusted /tmp/tailscale.apk && \
    rm -f /tmp/tailscale.apk

# Install NFS utilities
RUN apk add --no-cache nfs-utils

# Set up the NFS mount during container startup
COPY app ./app
COPY --from=builder /metube/dist/metube ./ui/dist/metube

ENV UID=1000
ENV GID=1000
ENV UMASK=022
ENV YTDL_OPTIONS='{"cookiefile":"/cookies/cookies.txt"}'
ENV DOWNLOAD_DIR /downloads
ENV STATE_DIR /downloads/.metube
ENV TEMP_DIR /downloads
VOLUME /downloads


# Start Tailscale and the application
CMD ["sh", "-c", "tailscaled & tailscale up --authkey=${TAILSCALE_AUTH_KEY} && tail -f /dev/null", "./docker-entrypoint.sh"]
