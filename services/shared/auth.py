"""
Authentication utilities for JWT token handling and role extraction from headers.

Note: This module has been updated to support the external authorization service architecture.
Roles are now extracted from x-user-roles header (populated by authz-service via Envoy)
rather than from JWT claims.

Important: HTTP/2 headers (used by Envoy) are case-sensitive and must be lowercase.
"""
import base64
import json
from typing import Dict, List, Optional
from fastapi import Header, HTTPException, status


class JWTPayload:
    """Represents decoded JWT payload with helper methods"""
  
    def __init__(self, payload: Dict, roles: Optional[List[str]] = None):
        self.payload = payload
        self.email = payload.get("email")
        self.preferred_username = payload.get("preferred_username")
        self.name = payload.get("name")
        self.sub = payload.get("sub")
     
        # Use provided roles or extract from JWT realm_access (for backward compatibility)
        if roles is not None:
            self.roles = roles
        else:
            realm_access = payload.get("realm_access", {})
            self.roles = realm_access.get("roles", [])
    
    def has_role(self, role: str) -> bool:
        """Check if user has a specific role"""
        return role in self.roles
    
    def has_any_role(self, roles: List[str]) -> bool:
        """Check if user has any of the specified roles"""
        return any(role in self.roles for role in roles)
  
    def __repr__(self):
        return f"JWTPayload(email={self.email}, roles={self.roles})"


def decode_jwt_payload(token: str, roles: Optional[List[str]] = None) -> JWTPayload:
    """
    Decode JWT token payload without verification.
    
    Note: This assumes the token has already been validated by Envoy/Gateway.
    We only decode to extract user information.
  
    Args:
        token: JWT token string (without 'Bearer ' prefix)
        roles: Optional list of roles to use instead of extracting from JWT
    
    Returns:
        JWTPayload: Decoded payload with user information
    
    Raises:
        HTTPException: If token cannot be decoded
    """
    try:
        # JWT structure: header.payload.signature
        # We only need the payload (middle part)
        parts = token.split('.')
        if len(parts) != 3:
            raise ValueError("Invalid JWT token format")
        
        # Decode the payload (add padding if needed)
        payload_part = parts[1]
        # Add padding if needed for base64 decoding
        padding = 4 - (len(payload_part) % 4)
        if padding != 4:
            payload_part += '=' * padding
   
        # Decode base64
        decoded_bytes = base64.urlsafe_b64decode(payload_part)
        payload = json.loads(decoded_bytes)
        
        return JWTPayload(payload, roles=roles)
    
    except (ValueError, json.JSONDecodeError, Exception) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )


async def get_current_user(authorization: Optional[str] = Header(None)) -> JWTPayload:
    """
    FastAPI dependency to extract current user from JWT token.
    
    DEPRECATED: Use get_current_user_from_headers() instead for external authz architecture.
    
    The token is expected to be in the Authorization header as 'Bearer <token>'.
    This function assumes the token has already been validated by the API Gateway (Envoy).
    
    Args:
        authorization: Authorization header value
    
    Returns:
        JWTPayload: Decoded JWT payload with user information
    
    Raises:
        HTTPException: If authorization header is missing or invalid
    
    Usage:
        @app.get("/protected")
        def protected_endpoint(current_user: JWTPayload = Depends(get_current_user)):
            return {"email": current_user.email, "roles": current_user.roles}
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )
    
    # Extract token from "Bearer <token>"
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Expected 'Bearer <token>'"
        )
    
    token = parts[1]
    return decode_jwt_payload(token)


async def get_current_user_from_headers(
    authorization: Optional[str] = Header(None),
    x_user_email: Optional[str] = Header(None, alias="x-user-email"),
    x_user_roles: Optional[str] = Header(None, alias="x-user-roles")
) -> JWTPayload:
    """
    FastAPI dependency to extract current user from headers set by Envoy ext_authz filter.
    
    This function is designed for the external authorization service architecture where:
    1. Envoy validates JWT token (optional for some routes)
    2. Envoy calls authz-service to get user roles
    3. Envoy forwards request with x-user-email and x-user-roles headers
    
    The function supports both authenticated users (with JWT) and guest users (without JWT).
    Guest users will have role 'guest' assigned by authz-service.
    
    Headers Expected (set by Envoy, HTTP/2 lowercase):
        authorization: Bearer <jwt-token> (optional, for authenticated users)
        x-user-email: user@example.com (from authz-service, empty for guests)
        x-user-roles: user,customer-manager or guest (comma-separated, from authz-service)
    
    Args:
        authorization: Authorization header value (JWT token, optional)
        x_user_email: User email from authz-service (via Envoy)
        x_user_roles: Comma-separated roles from authz-service (via Envoy)
    
    Returns:
        JWTPayload: User information with roles from authz-service
    
    Usage:
        @app.get("/protected")
        def protected_endpoint(current_user: JWTPayload = Depends(get_current_user_from_headers)):
            return {"email": current_user.email, "roles": current_user.roles}
    """
    # Parse roles from x-user-roles header (comma-separated)
    roles = []
    if x_user_roles:
        roles = [role.strip() for role in x_user_roles.split(",") if role.strip()]
    
    # Handle guest users (no authorization header)
    if not authorization:
        # Only allow guest access if authz-service explicitly set "guest" role
        if "guest" in roles:
            guest_payload = {
                "email": x_user_email or "",
                "preferred_username": "guest",
                "name": "Guest User",
                "sub": "guest"
            }
            return JWTPayload(guest_payload, roles=roles)
        else:
            # No authorization and no guest role - deny access
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing authorization header"
            )
    
    # Extract token from "Bearer <token>"
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        # Invalid authorization format - check if guest role is present
        if "guest" in roles:
            guest_payload = {
                "email": x_user_email or "",
                "preferred_username": "guest",
                "name": "Guest User",
                "sub": "guest"
            }
            return JWTPayload(guest_payload, roles=roles)
        else:
            # Invalid authorization format and no guest role - deny access
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authorization header format. Expected 'Bearer <token>'"
            )
    
    token = parts[1]
    
    # Decode JWT with roles from header
    jwt_payload = decode_jwt_payload(token, roles=roles)
    
    # Use x-user-email from header if available (more reliable than JWT)
    if x_user_email:
        jwt_payload.email = x_user_email
    
    return jwt_payload

