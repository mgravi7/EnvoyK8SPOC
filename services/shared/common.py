"""
Shared utilities for all microservices
"""
import logging
import sys
from datetime import datetime
from typing import Dict, Any

def setup_logging(service_name: str, level: str = "INFO") -> logging.Logger:
    """Setup logging configuration for a service"""
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format=f'%(asctime)s - {service_name} - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(service_name)

def create_health_response(service_name: str, additional_info: Dict[str, Any] = None) -> Dict[str, Any]:
    """Create a standardized health check response"""
    response = {
        "status": "healthy",
        "service": service_name,
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }
    
    if additional_info:
        response.update(additional_info)
    
    return response

def create_error_response(message: str, error_code: str = None) -> Dict[str, Any]:
    """Create a standardized error response"""
    response = {
        "error": True,
        "message": message,
        "timestamp": datetime.now().isoformat()
    }
    
    if error_code:
        response["error_code"] = error_code
    
    return response