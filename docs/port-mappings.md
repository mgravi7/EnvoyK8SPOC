# Port Mappings

This document lists Kubernetes service and pod port mappings for the repository, plus applicable Docker Compose host mappings (for local Docker Desktop / docker-compose setups).

| Component | Namespace | K8s Service (file) | Type | Service Port → TargetPort | Pod containerPort(s) (deployment) | Exposed outside cluster? | docker-compose host mapping |
|---|---:|---|---|---:|---:|---:|---:|
| Envoy (API Gateway / Envoy Gateway data plane) | `envoy-gateway-system` (created by Gateway controller) | `kubernetes/08-gateway-api/02-gateway.yaml` (Gateway owns generated Service/Deployment) | LoadBalancer (created by Gateway controller) | 8080 → 8080 (http). Admin port 9901 may be present on proxy pods for debugging. | 8080 (http), 9901 (admin, debug) — actual generated Deployment/Service names are created by the Envoy Gateway controller | Yes — LoadBalancer (Docker Desktop maps to localhost:8080). The Gateway controller creates the data‑plane Service in `envoy-gateway-system`. | `gateway`: "8080:8080" (Docker Compose local mapping, legacy/local only) |
| Keycloak (IAM) | `api-gateway-poc` | `kubernetes/04-iam/keycloak-service.yaml` | LoadBalancer | 8180 → 8080 (http), 9000 → 9000 (management) | 8080, 9000 (`kubernetes/04-iam/keycloak-deployment.yaml`) | Yes — LoadBalancer (localhost:8180 and localhost:9000 via Docker Desktop) | `keycloak`: "8180:8080" |
| AuthZ service | `api-gateway-poc` | `kubernetes/05-authz/authz-service.yaml` | ClusterIP | 9000 → 9000 | 9000 (`kubernetes/05-authz/authz-deployment.yaml`) | No — internal only | `authz-service`: no ports exposed |
| Customer service | `api-gateway-poc` | `kubernetes/06-services/customer-service.yaml` | ClusterIP | 8000 → 8000 | 8000 (`kubernetes/06-services/customer-deployment.yaml`) | No — internal only | `customer-service`: "8001:8000" |
| Product service | `api-gateway-poc` | `kubernetes/06-services/product-service.yaml` | ClusterIP | 8000 → 8000 | 8000 (`kubernetes/06-services/product-deployment.yaml`) | No — internal only | `product-service`: "8002:8000" |
| Redis | `api-gateway-poc` | `kubernetes/03-data/redis-service.yaml` | ClusterIP | 6379 → 6379 | 6379 (`kubernetes/03-data/redis-deployment.yaml`) | No — internal only | `redis`: no ports exposed |

Notes:
- No `nodePort` values are configured in Kubernetes manifests; external access is provided by `LoadBalancer` services which Docker Desktop maps to localhost when running locally.
- `docker-compose.yml` host port mappings are included in the rightmost column and apply only to the Docker Compose local setup (legacy/local use).
- Readiness/liveness probe ports are the same as the service/pod ports listed above (see each deployment manifest for details).
- Management/admin ports:
  - Keycloak management port `9000` is exposed via the LoadBalancer service and accessible on localhost:9000 when using Docker Desktop.
  - Envoy admin port `9901` may be available on the generated proxy pods for debugging. In Phase 3 the data‑plane proxies are managed by the Envoy Gateway controller; do not rely on the admin port being publicly exposed in production.

Phase 3 (Gateway API) note:
- In Phase 3 the Envoy proxy pods and their Service/Deployment are created and managed by the Envoy Gateway controller and typically run in the `envoy-gateway-system` namespace. The Gateway resource in `api-gateway-poc` logically owns those proxies — use the label selector `gateway.envoyproxy.io/owning-gateway-name=api-gateway` to find the proxy pods and services.

Historical / legacy info:
- Legacy Phase 2 (direct Envoy) notes have been archived. See `docs/archive/` for legacy material if you need details about the manual Envoy Deployment and static `envoy.yaml` configuration.

LoadBalancer behavior and environment differences:
- Docker Desktop maps LoadBalancer services to localhost for convenience. In other Kubernetes environments (cloud clusters, kind, minikube), LoadBalancer behavior differs; you may need to use `kubectl port-forward`, `NodePort`, or the cloud provider's ExternalIP to reach services externally.

Dev-only / security note:
- For this Proof of Concept any admin/admin or management ports are exposed for development and debugging convenience.
- Do NOT expose admin interfaces publicly in production. Recommended mitigations for production environments:
  - Bind management/admin interfaces to localhost or a secure management network.
  - Do not publish admin ports via a LoadBalancer; keep them ClusterIP or remove the service for the admin listener.
  - Apply NetworkPolicy or firewall rules to restrict access to trusted maintenance/management hosts.
  - Consider placing an authentication/authorization proxy in front of admin endpoints.

Generated from repository manifests on branch `doc/updates`.