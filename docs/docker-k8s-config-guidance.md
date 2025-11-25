# Docker vs Kubernetes Config Guidance

Purpose

This document explains practical guidelines for deciding what belongs in a Dockerfile (image), a Kubernetes ConfigMap, a Secret, or a Deployment manifest. It is focused on day‑to‑day decisions for a POC (development) environment and notes production differences where relevant.

Principles (short)

- Build-time (image): put everything needed to run the application that does not change per environment (binaries, app code, default assets).
- Runtime (Kubernetes): put environment-specific settings, credentials, and orchestration rules in K8s resources so you can change them without rebuilding images.
- Secrets vs Config: secrets = private (use Secret or an external secret manager), config = non-private (use ConfigMap).
- Deployments express how the app runs in the cluster (replicas, probes, volumes, resources, strategies).

What belongs in the Dockerfile (image)

- Install OS packages, runtime dependencies, compiled code and libraries.
- Bake in code and assets for a specific application version.
- Provide a sensible default configuration if appropriate, but avoid hard-coding environment-specific settings (URLs, credentials).
- Example: `FROM python:3.12` + `pip install -r requirements.txt` + copy app code.

What belongs in a ConfigMap

- Non-sensitive configuration values and small text configuration files.
- Feature flags, service endpoints, TTLs, timeouts, logging levels (if not secret).
- Full config files you may want to edit without rebuilding the image (mount as file from ConfigMap).
- Example uses:
  - `envFrom: configMapRef` to populate environment variables
  - `volumeMount` a `redis.conf` created from a ConfigMap

What belongs in a Secret

- Passwords, API keys, client secrets, certificates and private keys.
- Use Kubernetes Secrets or an external secret manager (HashiCorp Vault, ExternalSecrets, SealedSecrets) and avoid committing secrets to version control.
- Do NOT rely on plain base64 encoding as a security mechanism — base64 is only an encoding, not encryption.
- For DEV you may use sealed secrets tooling or locally-managed Secrets but document that these are DEV-only and rotate them before any public use.

What belongs in Deployment manifests

- Orchestration decisions: `replicas`, `image`, `imagePullPolicy`, `livenessProbe`, `readinessProbe`, `resources`, `volumes`, `nodeSelector`, `tolerations`, and `strategy`.
- Mounts and environment injection: `envFrom` (ConfigMap/Secret) or `volumeMounts` for file configs.
- Do not embed secrets directly in Deployment YAML for production.
- Prefer immutable image tags (not `:latest`) for reproducibility in CI/CD.

Patterns and examples

1. Command-line args in Deployment (simple)

- Pros: quick, explicit in one place
- Cons: harder to change without `kubectl rollout restart`

2. ConfigMap-mounted config file (recommended for tunables)

- Create a ConfigMap with a `redis.conf` key
- Mount it at `/usr/local/etc/redis/redis.conf` and run `redis-server /usr/local/etc/redis/redis.conf`
- Changing the ConfigMap requires pod restart to pick up changes (or mount and have app watch files)

3. Environment vars via ConfigMap

- Use `envFrom: - configMapRef:` so each key becomes an env var inside the container
- Useful for small values like `REDIS_URL`, `REDIS_TTL`, `LOG_LEVEL`

Operational tips

- After updating a ConfigMap that is consumed as env vars, run `kubectl rollout restart deployment/<name> -n <ns>` to make pods pick up the changes.
- For debugging, use `kubectl exec -it deployment/<name> -n <ns> -- env | grep <KEY>` or `kubectl logs -f deployment/<name> -n <ns>`.
- Prefer `tcpSocket` probes for simple TCP services (Redis) unless you need a protocol-level check.
- Use `imagePullPolicy: IfNotPresent` for local POC images built on Docker Desktop. For CI/CD and clusters that pull from registries, use explicit tags and set `imagePullPolicy: Always` in CI to ensure fresh images.
- Prefer immutable tags (e.g., `myapp:20231123-abcdef`) in CI; avoid `latest` in Deployment manifests for reproducible rollbacks.

Dev vs Production notes

- DEV: convenience (local images, simple Secrets, hostPath or default storage class) is OK but must be clearly labeled DEV-only. Document any shortcuts (self-signed certs, default credentials).
- PROD: use networked storage, resource requests/limits, RBAC, encrypted Secrets, external secret manager, TLS everywhere, and scaled replicas.

Quick reference commands

- Apply changes: `kubectl apply -f <file-or-dir>`
- Restart deployment after ConfigMap change: `kubectl rollout restart deployment/<name> -n <ns>`
- View env in pod: `kubectl exec -it deployment/<name> -n <ns> -- env`
- Tail logs: `kubectl logs -f deployment/<name> -n <ns>`

Testing and token examples

- Keycloak token endpoint example (Gateway API deployment):
```bash
curl -X POST http://localhost:8080/auth/realms/api-gateway-poc/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=test-client" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" | jq -r '.access_token'
```

- For CI/automation prefer the confidential client (with client secret) or a service account flow; do not embed dev client secrets in public pipelines.

Phase 3 (Gateway API) notes (short)

- Phase 3 (Gateway API): use Gateway API CRDs and Envoy Gateway controller. Security is declared using `SecurityPolicy` resources. Envoy proxy pods run in `envoy-gateway-system` and are logically owned by the Gateway resource in `api-gateway-poc`.

Behavioral differences to keep in mind:
- JWT enforcement and extAuth behavior are controlled by `SecurityPolicy` in Phase 3; you can make JWT required or optional per route. To support a guest `/auth/me` endpoint, configure the route or security policy to allow optional JWT so extAuth can return `guest` when no token is present.

CI smoke-check recommendation

Add a small smoke-check script that validates the gateway and basic auth flow before running the full test suite. Example checks:
- `curl http://localhost:8080/products` → 200
- `curl http://localhost:8080/auth/me` (no token) → returns JSON with `roles` including `guest` (if auth-me configured as optional)
- Acquire token and call `/auth/me` to verify roles for an authenticated user

Further reading

- Kubernetes docs: ConfigMap, Secret, PersistentVolumeClaim, Deployment
- Dockerfile best practices
- External secrets project and SealedSecrets

Generated for EnvoyK8SPOC Phase 3. Phase 2 (direct Envoy) has been archived — see `docs/archive/` for legacy reference. Keep this guidance concise and revisit when moving to production.