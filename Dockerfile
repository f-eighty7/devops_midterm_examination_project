FROM ubuntu:20.04

# Set noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y wget git sqlite3 nginx certbot python3-certbot-nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install Gitea
RUN wget -O /usr/local/bin/gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x /usr/local/bin/gitea

EXPOSE 3000
EXPOSE 22
EXPOSE 80
EXPOSE 443

# Create user and directories for Gitea
RUN adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/git \
    git

RUN mkdir -p /var/lib/gitea/{custom,data,log,repositories} && \
    chown -R git:git /var/lib/gitea/ && \
    chmod -R 750 /var/lib/gitea/ && \
    mkdir /etc/gitea && \
    chown root:git /etc/gitea && \
    chmod 770 /etc/gitea

RUN mkdir -p /usr/local/bin/data && \
    chown -R git:git /usr/local/bin/data && \
    chmod -R 750 /usr/local/bin/data

COPY app.ini /etc/gitea/app.ini
RUN chown git:git /etc/gitea/app.ini && chmod 660 /etc/gitea/app.ini

# Remove default NGINX configuration
RUN rm /etc/nginx/sites-enabled/default

# Copy NGINX configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
