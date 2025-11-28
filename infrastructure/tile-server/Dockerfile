FROM eclipse-temurin:21-jre-jammy

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    nginx \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# Download Planetiler (latest release)
RUN curl -L https://github.com/onthegomap/planetiler/releases/download/v0.7.0/planetiler.jar \
    -o /usr/local/bin/planetiler.jar && \
    chmod +x /usr/local/bin/planetiler.jar

# Copy configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
