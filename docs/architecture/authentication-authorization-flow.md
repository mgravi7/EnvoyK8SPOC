# Authentication & Authorization Flow

This document illustrates the comprehensive authentication and authorization flow in the API Gateway POC, showing how security is implemented across multiple layers. The canonical deployment is Kubernetes Gateway API with Envoy Gateway (Envoy proxy data plane managed by the operator in the `envoy-gateway-system` namespace).

## Overview

The system implements a layered security approach:

1. **Authentication Layer**: Keycloak handles user authentication and JWT token issuance
2. **Gateway JWT Validation**: Envoy (data plane) validates JWT token signatures and expiration
3. **Gateway Authorization**: Envoy calls Authorization Service for role lookup via ext_authz
4. **Role Caching**: Redis caches user roles (5-minute TTL) for performance
5. **Gateway RBAC**: Envoy enforces role-based routing using injected role headers
6. **Service Authorization**: Individual services implement business logic authorization
7. **Data Access Layer**: Secure data operations with clean separation of concerns

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User as User<br/>(role: "user")
    participant Keycloak as Keycloak<br/>Identity Provider
    participant Envoy as Envoy Gateway<br/>API Gateway
    participant AuthZService as Authorization Service<br/>Port 9000
    participant Redis as Redis Cache<br/>Role Cache
    participant AuthZData as AuthZ Data Access<br/>Role Database
    participant CustomerAPI as Customer Service<br/>FastAPI
    participant AuthModule as JWT Auth Module<br/>(shared/auth.py)
    participant DataAccess as Customer Data Access<br/>(customer_data_access.py)

    Note over User, DataAccess: Authentication with Keycloak
    
    User->>+Keycloak: POST /realms/api-gateway-poc/protocol/openid-connect/token<br/>client_id: test-client<br/>username: testuser<br/>password: testpass<br/>grant_type: password
    
    Keycloak->>Keycloak: Validate credentials<br/>NOTE: Roles NOT in JWT (IT policy restriction)
    
    Keycloak->>-User: Return JWT Token<br/>{ "email": "testuser@example.com",<br/>  "exp": 1761529888, ... }<br/>NO roles in token

    Note over User, DataAccess: API request with JWT

    User->>+Envoy: GET /customers/2<br/>Authorization: Bearer <jwt_token>
    
    Note over Envoy: Envoy Gateway JWT Validation
    
    Envoy->>Envoy: Extract JWT from Authorization header
    
    Envoy->>+Keycloak: Validate JWT signature<br/>GET /realms/api-gateway-poc/protocol/openid-connect/certs
    Keycloak->>-Envoy: Return JWKS (public keys)
 
    Envoy->>Envoy: Verify JWT signature<br/>Check token expiration<br/>Extract email from JWT
    
    alt JWT Invalid or Expired
        Envoy->>User: 401 Unauthorized<br/>Invalid or expired token
    else JWT Valid - Call ext_authz for Role Lookup
        Note over Envoy, AuthZData: External Authorization (ext_authz)
        
        Envoy->>+AuthZService: ext_authz: POST /authz/roles<br/>Authorization: Bearer <jwt_token><br/>x-request-id: <uuid>
        
        AuthZService->>AuthZService: Extract email from JWT<br/>email: testuser@example.com
        
        AuthZService->>+Redis: GET user:platform-roles:testuser@example.com
        
        alt Cache Hit
            Redis->>-AuthZService: Return cached roles: ["user"]
            Note over AuthZService: Cache hit - skip database query
        else Cache Miss
            Redis->>AuthZService: Cache miss (null)
            AuthZService->>+AuthZData: get_user_roles("testuser@example.com")
            AuthZData->>AuthZData: Query role database<br/>(currently mocked)
            AuthZData->>-AuthZService: Return roles: ["user"]
            AuthZService->>Redis: SET user:platform-roles:testuser@example.com<br/>["user"] EX 300
            Note over AuthZService: Cache result for 5 minutes
        end
        
        AuthZService->>-Envoy: 200 OK<br/>x-user-email: testuser@example.com<br/>x-user-roles: user
        
        Note over Envoy: Envoy RBAC Filter
        
        Envoy->>Envoy: Check RBAC policy<br/>x-user-roles header contains "user"<br/>Access granted
        
        alt Missing Required Role
            Envoy->>User: 403 Forbidden<br/>Insufficient permissions
        else Has Required Role - Forward Request
            Note over Envoy: Role check passed - inject headers
            Envoy->>+CustomerAPI: GET /customers/2<br/>Authorization: Bearer <jwt_token><br/>x-user-email: testuser@example.com<br/>x-user-roles: user
        
            Note over CustomerAPI, DataAccess: Service-Level Authorization

            CustomerAPI->>+AuthModule: get_current_user(authorization_header)
            
            AuthModule->>AuthModule: Extract Bearer token<br/>Split JWT into parts<br/>Base64 decode payload
            
            AuthModule->>AuthModule: Parse JWT payload:<br/>{ "email": "testuser@example.com" }<br/>NOTE: Roles come from x-user-roles header,<br/>not from JWT
            
            AuthModule->>-CustomerAPI: Return JWTPayload object<br/>email: testuser@example.com<br/>roles: ["user"] (from x-user-roles header)

            CustomerAPI->>CustomerAPI: Log: "Fetching customer ID: 2<br/>(requested by: testuser@example.com)"