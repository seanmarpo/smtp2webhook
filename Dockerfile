# Build stage - Use Alpine for smaller base
FROM rust:alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    openssl-dev \
    openssl-libs-static \
    pkgconfig

WORKDIR /build

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src ./src

# Build the application natively on Alpine (no cross-compilation)
RUN cargo build --release

# Runtime stage - Minimal Alpine (~15MB total)
FROM alpine:latest

# Install only CA certificates for HTTPS webhook requests
RUN apk add --no-cache ca-certificates tzdata && \
    rm -rf /var/cache/apk/*

# Create a non-root user
RUN adduser -D -u 1000 smtp2webhook

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /build/target/release/smtp2webhook /app/smtp2webhook

# Copy example configuration
COPY config.toml.example /app/config.toml.example

# Change ownership
RUN chown -R smtp2webhook:smtp2webhook /app

USER smtp2webhook

# Expose SMTP port (default 2525, can be overridden via config)
EXPOSE 2525

# Run the application
ENTRYPOINT ["/app/smtp2webhook"]
CMD ["/app/config.toml"]
