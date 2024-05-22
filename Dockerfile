FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y wget git sqlite3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /usr/local/bin/gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x /usr/local/bin/gitea

EXPOSE 3000
EXPOSE 22

RUN adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/git \
    git

RUN mkdir -p /usr/local/bin/gitea/{custom,data,log,repositories} && \
    chown -R git:git /usr/local/bin/gitea/ && \
    chmod -R 750 /usr/local/bin/gitea/ && \
    mkdir /etc/gitea && \
    chown root:git /etc/gitea && \
    chmod 770 /etc/gitea

COPY app.ini /etc/gitea/app.ini

USER git

CMD ["gitea", "web", "-c", "/etc/gitea/app.ini"]