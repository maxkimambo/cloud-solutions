FROM ubuntu:23.04

# Install ca-certificates
RUN apt-get update && apt-get install -y ca-certificates

COPY ./build/gcp-log-exporter /app/

# Set default environment variables
ENV PROJECT_ID=""
ENV TOPIC_ID=""
ENV SUB_ID=""
ENV LOG_PATH=/app/gcp.log 
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json
ENTRYPOINT ["/app/gcp-log-exporter"]