FROM eclipse-temurin:21-jre-noble

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    nginx \
    gzip \
    osmium-tool \
    && rm -rf /var/lib/apt/lists/*

# Create data directory
RUN mkdir -p /data

# Download Planetiler (latest release - 0.9.3 has better YAML schema support)
RUN curl -L https://github.com/onthegomap/planetiler/releases/download/v0.9.3/planetiler.jar \
    -o /usr/local/bin/planetiler.jar && \
    chmod +x /usr/local/bin/planetiler.jar

# Copy configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY cyclosm-schema.yaml /cyclosm-schema.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
