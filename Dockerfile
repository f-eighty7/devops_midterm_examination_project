# Use an official Ubuntu as a parent image
FROM ubuntu:20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download Gitea binary
RUN wget -O /usr/local/bin/gitea https://dl.gitea.io/gitea/1.22/gitea-1.22-linux-amd64 && \
    chmod +x /usr/local/bin/gitea

# Expose Gitea port
EXPOSE 3000
EXPOSE 22

# Add git user
RUN adduser \
    --system \
    --shell /bin/bash \
    --gecos 'Git Version Control' \
    --group \
    --disabled-password \
    --home /home/git \
    git

# Create necessary directories and set permissions
RUN mkdir -p /var/lib/gitea/{custom,data,log} && \
    chown -R git:git /var/lib/gitea/ && \
    chmod -R 750 /var/lib/gitea/ && \
    mkdir /etc/gitea && \
    chown root:git /etc/gitea && \
    chmod 770 /etc/gitea

# Set the Gitea user
USER git

# Set working directory
WORKDIR /var/lib/gitea

# Run Gitea
CMD ["gitea", "web", "-c", "/etc/gitea/app.ini"]
