"""
Authentication utilities for JWT token handling
"""
import base64
import json
from typing import Dict, List, Optional
from fastapi import Header, HTTPException, status


class JWTPayload:
    """Represents decoded JWT payload with helper methods"""
  
    def __init__(self, payload: Dict):
        self.payload = payload
        self.email = payload.get("email")
        self.preferred_username = payload.get("preferred_username")
        self.name = payload.get("name")
        self.sub = payload.get("sub")
     
        # Extract roles from realm_access
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


def decode_jwt_payload(token: str) -> JWTPayload:
    """
    Decode JWT token payload without verification.
    
    Note: This assumes the token has already been validated by Envoy/Gateway.
    We only decode to extract user information.
  
    Args:
        token: JWT token string (without 'Bearer ' prefix)
    
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
        
        return JWTPayload(payload)
    
    except (ValueError, json.JSONDecodeError, Exception) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )


async def get_current_user(authorization: Optional[str] = Header(None)) -> JWTPayload:
    """
    FastAPI dependency to extract current user from JWT token.
    
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
