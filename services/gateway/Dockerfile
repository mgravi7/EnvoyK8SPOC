FROM envoyproxy/envoy:v1.31-latest

# Copy the Envoy configuration
COPY envoy.yaml /etc/envoy/envoy.yaml

# Expose ports
EXPOSE 8080 9901

# Run Envoy
CMD ["/usr/local/bin/envoy", "-c", "/etc/envoy/envoy.yaml"]