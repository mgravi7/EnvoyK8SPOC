# Docker vs Kubernetes Config Guidance

Purpose

This document explains practical guidelines for deciding what belongs in a Dockerfile (image), a Kubernetes ConfigMap, a Secret, or a Deployment manifest. It is focused on day‑to‑day decisions for a POC (development) environment and notes production differences where relevant.

Principles (short)

- Build-time (image): put everything needed to run the application that does not change per environment (binaries, app code, default assets).
- Runtime (Kubernetes): put environment-specific settings, credentials, and orchestration rules in K8s resources so you can change them without rebuilding images.
- Secrets vs Config: secrets=private (use Secret), config=non-private (use ConfigMap).
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
- Use Kubernetes Secrets (or external secret manager) and avoid committing secrets to version control.
- For DEV you may use sealed/base64-encoded secrets but document that they are DEV-only.

What belongs in Deployment manifests

- Orchestration decisions: `replicas`, `image`, `imagePullPolicy`, `livenessProbe`, `readinessProbe`, `resources`, `volumes`, `nodeSelector`, `tolerations`, and `strategy`.
- Mounts and environment injection: `envFrom` (ConfigMap/Secret) or `volumeMounts` for file configs.
- Do not embed secrets directly in Deployment YAML for production.

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
- Use `imagePullPolicy: IfNotPresent` for local POC images built on Docker Desktop. Use explicit tags in CI/CD.

Dev vs Production notes

- DEV: convenience (local images, simple Secrets, hostPath or default storage class) is OK but must be clearly labeled DEV-only.
- PROD: use networked storage, resource requests/limits, RBAC, encrypted Secrets, external secret manager, TLS, and scaled replicas.

Quick reference commands

- Apply changes: `kubectl apply -f <file-or-dir>`
- Restart deployment after ConfigMap change: `kubectl rollout restart deployment/<name> -n <ns>`
- View env in pod: `kubectl exec -it deployment/<name> -n <ns> -- env`
- Tail logs: `kubectl logs -f deployment/<name> -n <ns>`

Further reading

- Kubernetes docs: ConfigMap, Secret, PersistentVolumeClaim, Deployment
- Dockerfile best practices


Generated for EnvoyK8SPOC Phase 2. Keep this guidance concise and revisit when moving to production.