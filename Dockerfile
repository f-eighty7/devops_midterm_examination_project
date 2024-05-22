FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

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


RUN mkdir -p /var/lib/gitea/data && \
    chown -R git:git /var/lib/gitea/data && \
    chmod -R 750 /var/lib/gitea/data&& \
    mkdir /etc/gitea && \
    chown root:git /etc/gitea && \
    chmod 770 /etc/gitea


COPY app.ini /etc/gitea/app.ini

USER git

WORKDIR /var/lib/gitea

CMD ["gitea", "web", "-c", "/etc/gitea/app.ini"]
