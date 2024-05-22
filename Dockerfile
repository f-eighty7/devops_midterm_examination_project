FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y wget git sqlite3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x gitea

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

USER git

WORKDIR /var/lib/gitea

EXPOSE 3000
EXPOSE 22

CMD ["gitea", "web", "-c", "/etc/gitea/app.ini"]
