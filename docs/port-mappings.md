# Port Mappings

This document lists Kubernetes service and pod port mappings for the repository, plus applicable Docker Compose host mappings (for local Docker Desktop / docker-compose setups).

| Component | Namespace | K8s Service (file) | Type | Service Port → TargetPort | Pod containerPort(s) (deployment) | Exposed outside cluster? | docker-compose host mapping |
|---|---:|---|---|---:|---:|---:|---:|
| Envoy (API Gateway) | `api-gateway-poc` (Phase 2) | `kubernetes/07-envoy-gateway/envoy-service.yaml` | LoadBalancer | 8080 → 8080 (http), 9901 → 9901 (admin) | 8080, 9901 (`kubernetes/07-envoy-gateway/envoy-deployment.yaml`) | Yes — LoadBalancer (Docker Desktop exposes on localhost:8080 and localhost:9901) | `gateway`: `"8080:8080", "9901:9901"` |
| Keycloak (IAM) | `api-gateway-poc` | `kubernetes/04-iam/keycloak-service.yaml` | LoadBalancer | 8180 → 8080 (http), 9000 → 9000 (management) | 8080, 9000 (`kubernetes/04-iam/keycloak-deployment.yaml`) | Yes — LoadBalancer (localhost:8180 and localhost:9000 via Docker Desktop) | `keycloak`: `"8180:8080"` |
| AuthZ service | `api-gateway-poc` | `kubernetes/05-authz/authz-service.yaml` | ClusterIP | 9000 → 9000 | 9000 (`kubernetes/05-authz/authz-deployment.yaml`) | No — internal only | `authz-service`: no ports exposed |
| Customer service | `api-gateway-poc` | `kubernetes/06-services/customer-service.yaml` | ClusterIP | 8000 → 8000 | 8000 (`kubernetes/06-services/customer-deployment.yaml`) | No — internal only | `customer-service`: `"8001:8000"` |
| Product service | `api-gateway-poc` | `kubernetes/06-services/product-service.yaml` | ClusterIP | 8000 → 8000 | 8000 (`kubernetes/06-services/product-deployment.yaml`) | No — internal only | `product-service`: `"8002:8000"` |
| Redis | `api-gateway-poc` | `kubernetes/03-data/redis-service.yaml` | ClusterIP | 6379 → 6379 | 6379 (`kubernetes/03-data/redis-deployment.yaml`) | No — internal only | `redis`: no ports exposed |

Notes:
- No `nodePort` values are configured in Kubernetes manifests; external access is provided by `LoadBalancer` services which Docker Desktop maps to localhost when running locally.
- `docker-compose.yml` host port mappings are included in the rightmost column and apply only to the Docker Compose local setup.
- Readiness/liveness probe ports are the same as the service/pod ports listed above (see each deployment manifest for details).
- Management ports:
  - Keycloak management port `9000` is exposed via the LoadBalancer service and accessible on localhost:9000.
  - Envoy admin port `9901` is exposed for development convenience; restrict access in production.

Phase 2 vs Phase 3 (Envoy) note:
- The Envoy service shown above (`kubernetes/07-envoy-gateway/envoy-service.yaml`) corresponds to the Phase 2 manual Envoy Deployment. In Phase 3 (Gateway API) the Envoy proxy pods are created and managed by the Envoy Gateway controller and typically run in the `envoy-gateway-system` namespace. The Gateway (in `api-gateway-poc`) logically owns those proxies and the Gateway controller creates the data-plane Service and Deployment. When debugging or inspecting ports in Phase 3, check `-n envoy-gateway-system` for proxy pods (use the label selector `gateway.envoyproxy.io/owning-gateway-name=api-gateway`).

Keycloak docker-compose vs Kubernetes mapping:
- The docker-compose setup maps Keycloak host port `8180` to container port `8080` for local convenience. The Kubernetes Service exposes both `8180` (mapped to container 8080) and `9000` (management). The compose file intentionally omits the management port mapping; in Kubernetes the management port is available via the LoadBalancer service (on Docker Desktop this appears on localhost:9000).

LoadBalancer behavior and environment differences:
- Docker Desktop maps LoadBalancer services to localhost for convenience. In other Kubernetes environments (cloud clusters, kind, minikube), LoadBalancer behavior differs; you may need to use `kubectl port-forward`, `NodePort`, or the cloud provider's ExternalIP to reach services externally.

Dev-only / security note:
- For this Proof of Concept the Envoy admin port (`9901`) is intentionally exposed for development and debugging convenience.
- Do NOT expose the admin interface publicly in production. Recommended mitigations for production environments:
  - Bind the admin interface to localhost or a secure management network.
  - Do not publish the admin port via a LoadBalancer; keep it ClusterIP or remove the service for the admin listener.
  - Apply NetworkPolicy or firewall rules to restrict access to trusted maintenance/management hosts.
  - Consider placing an authentication/authorization proxy in front of admin endpoints.

Generated from repository manifests on branch `doc/updates`.