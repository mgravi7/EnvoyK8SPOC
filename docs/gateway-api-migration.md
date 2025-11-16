# Gateway API Migration Guide - Phase 3

**Status:** Future - To be completed after Phase 2

This document will cover the migration from direct Envoy deployment (Phase 2) to Kubernetes Gateway API with Envoy Gateway (Phase 3).

## Overview

Phase 3 replaces the direct Envoy Proxy deployment with Kubernetes Gateway API resources, providing:
- Declarative Kubernetes-native configuration
- Dynamic updates without pod restarts
- Standard API (portable across gateway implementations)
- Better integration with Kubernetes ecosystem

## Prerequisites

Before starting Phase 3, ensure Phase 2 is working successfully:
- [ ] All Phase 2 pods running
- [ ] All 90 tests passing
- [ ] Understanding of current Envoy configuration
- [ ] Familiarity with kubectl and Kubernetes concepts

## Migration Path

Phase 3 will involve:

1. Installing Envoy Gateway operator
2. Creating GatewayClass resource
3. Creating Gateway resource (replaces Envoy Deployment)
4. Converting routes to HTTPRoute CRDs
5. Converting security config to SecurityPolicy CRDs
6. Testing and validation
7. Removing Phase 2 Envoy resources

## Resources

This guide will be populated after Phase 2 completion. In the meantime, refer to:

- [Kubernetes Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Envoy Gateway Quickstart](https://gateway.envoyproxy.io/latest/tasks/quickstart/)

## Next Steps

1. Complete Phase 2 deployment
2. Run all tests successfully
3. Document learnings from Phase 2
4. Review Gateway API concepts
5. Plan Phase 3 migration tasks

---

**This document will be completed as part of Phase 3 implementation.**
