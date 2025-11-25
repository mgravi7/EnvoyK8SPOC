# EnvoyK8SPOC - Project Plan

## Project Overview

**Name:** EnvoyK8SPOC (Envoy Gateway + Kubernetes Proof of Concept)  
**Purpose:** Learning and demonstrating migration from Docker Compose to Kubernetes-native architecture with Envoy Gateway  
**Dev Environment:** Windows 11/MacOS (development), Linux (deployment)  
**Container Runtime:** Docker Desktop with Kubernetes  
**Type:** Proof of Concept & Learning Project

---

## Current State Assessment

- **Phase 1 COMPLETE - Working in Docker Compose.** All services run together via `docker-compose.yml` for local development and quick iteration.
- **Phase 2 (deprecated) - Direct Envoy.** Phase 2 manifests (direct Envoy Deployment) are archived and removed from the main deployment flow to reduce complexity for downstream teams.
- **Phase 3 STANDARD - Gateway API (Envoy Gateway).** Kubernetes Gateway API resources, SecurityPolicies, and deployment scripts are present under `kubernetes/08-gateway-api/` and `scripts/*/deploy-k8s.*`. Helm-based Envoy Gateway operator installation (v1.6.0) is the recommended approach for Docker Desktop local clusters.
- **Services:** `customer-service`, `product-service`, `authz-service`, `keycloak`, and `redis` are implemented as FastAPI/containers and have Kubernetes manifests in `kubernetes/06-services/`, `kubernetes/05-authz/`, `kubernetes/04-iam/`, and `kubernetes/03-data/` respectively.
- **Authentication/Authorization:** JWT authentication (Keycloak) and external authorization (authz-service + Redis caching) are implemented and integrated with the gateway in Phase 3.
- **Tests:** Unit and integration tests live in `tests/` (unit + integration). The test suite is substantial for a POC (100+ tests). Run `pytest -q` in the `tests/` directory to get the current totals and to validate the workspace against a deployed gateway.
- **Shared Libraries:** `shared/auth.py` and `shared/common.py` provide cross-service utilities used across services.

**Branch:** `feature/cleanup` (current workspace branch)
**Repository:** https://github.com/mgravi7/EnvoyK8SPOC

---

## Implementation Plan (Minimal cleanup and standardization)

1. Rename deployment scripts to a single deploy command:
   - `scripts/bash/deploy-k8s.sh` and `scripts/powershell/deploy-k8s.ps1` (Phase 3-only)

2. Simplify scripts to assume Phase 3 (Gateway API) only:
   - Remove Phase 2 detection and deletion prompts from `verify-deployment`, `cleanup-k8s`, `test-endpoints`, and other helper scripts.

3. Remove Phase 2 manifests and empty folders:
   - Delete `kubernetes/07-envoy-gateway/` and any empty directories under `kubernetes/` (e.g., empty `kubernetes/04-iam/` if applicable).
   - Move historical Phase 2 notes to `docs/archive/` (already present).

4. Keep native Docker support:
   - Retain `docker-compose.yml` and `services/gateway/envoy.yaml` for local Docker runs.

5. Documentation updates:
   - Update `docs/kubernetes-deployment.md` and `scripts/README.md` to reflect the single Phase 3 deployment via Helm + `deploy-k8s.sh`.

6. No CI changes required (per your instruction).

---

## Next Steps (I will implement now on `feature/cleanup` branch):

- Create `deploy-k8s.sh` and `deploy-k8s.ps1` (done)
- Update `test-endpoints` and `verify-deployment` scripts to assume Phase 3 only (done)
- Simplify cleanup scripts to Phase 3 only (done)
- Update `scripts/README.md` (done)
- Delete `kubernetes/07-envoy-gateway/` and remove empty kubernetes folders (next step)

I will now remove the Phase 2 manifest directory and any empty folders in `kubernetes/` per your confirmation.
