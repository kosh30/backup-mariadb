# Use a smaller base image
FROM debian:bookworm as build
ARG TARGETPLATFORM
ARG BUILDPLATFORM
# Combine RUN commands to minimize layers and clean up in the same layer
SHELL ["/bin/bash", "-c"]
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        bash \
        curl \
        wget; \
    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s ;\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        mariadb-backup \
        mariadb-client; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /backup; \
    chown -R 1000:1000 /backup

RUN if [ "$TARGETPLATFORM" == "linux/arm64" ]; then curl -L https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_linux_arm64.deb -o /tmp/s5cmd.deb; fi
RUN if [ "$TARGETPLATFORM" == "linux/amd64" ]; then curl -L https://github.com/peak/s5cmd/releases/download/v2.2.2/s5cmd_2.2.2_linux_amd64.deb -o /tmp/s5cmd.deb; fi
RUN dpkg -i /tmp/s5cmd.deb; \
    rm /tmp/s5cmd.deb;

COPY resources/perform-backup.sh /
COPY resources/perform-dump-backup.sh /
RUN chmod +x /perform*.sh

# REDUCE IMAGE SIZE
FROM scratch
COPY --from=build / /
WORKDIR /backup
USER 1000:1000
CMD ["sh", "/perform-dump-backup.sh"]
