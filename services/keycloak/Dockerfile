FROM quay.io/keycloak/keycloak:latest

# Set environment variables for development mode
ENV KC_BOOTSTRAP_ADMIN_USERNAME=admin
ENV KC_BOOTSTRAP_ADMIN_PASSWORD=admin
ENV KC_HTTP_PORT=8080
ENV KC_HOSTNAME_STRICT=false
ENV KC_HTTP_ENABLED=true
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Copy realm configuration if exists
COPY --chown=keycloak:keycloak realm-export.json /opt/keycloak/data/import/realm-export.json

# Set working directory
WORKDIR /opt/keycloak

# Expose ports
EXPOSE 8080

# Start Keycloak in development mode with realm import
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev", "--import-realm"]
