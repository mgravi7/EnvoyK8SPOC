# Dcoumentation for Envoy APi: https://www.envoyproxy.io/docs/envoy/latest/api-v3/api
FROM envoyproxy/envoy:v1.36.2

# Copy the Envoy configuration
COPY envoy.yaml /etc/envoy/envoy.yaml

# Expose ports
EXPOSE 8080 9901

# Run Envoy
CMD ["/usr/local/bin/envoy", "-c", "/etc/envoy/envoy.yaml"]