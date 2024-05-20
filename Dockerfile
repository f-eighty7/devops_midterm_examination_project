FROM ubuntu:latest

RUN  apt-get update && \
    apt-get install -y wget git && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O /usr/local/bin/gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x /usr/local/bin/gitea

EXPOSE 3000

RUN adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/git \
    git

RUN mkdir -p /var/lib/gitea/{custom,data,log} && \
    chown -R git:git /var/lib/gitea/ && \
    chmod -R 750 /var/lib/gitea/ && \
    mkdir /etc/gitea && \
    chown root:git /etc/gitea && \
    chmod 770 /etc/gitea

CMD ["gitea", "web", "-c", "/etc/gitea/app.ini"]