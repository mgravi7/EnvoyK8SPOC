from fastapi import FastAPI, HTTPException
from typing import List
import os
import sys
sys.path.append('/app')

from product_model import ProductResponse
from shared.common import setup_logging, create_health_response
from product_data_access import product_data_access

# Setup logging
logger = setup_logging("product-service")

app = FastAPI(
    title="Product Service",
    description="Microservice for managing products",
    version="1.0.0"
)

@app.get("/products/health")
def health_check():
    """Health check endpoint"""
    logger.info("Health check requested")
    return create_health_response("product-service")

@app.get("/products", response_model=List[ProductResponse])
def get_products():
    """
    Get all products
    
    Note: Authorization handled by Envoy Gateway (requires 'user' role)
    """
    logger.info("Fetching all products")
    
    products = product_data_access.get_all_products()
    logger.info(f"Returning all products. Count: {product_data_access.get_product_count()}")
    
    return products

@app.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: int):
    """
    Get a specific product by ID
    
    Note: Authorization handled by Envoy Gateway (requires 'user' role)
    """
    logger.info(f"Fetching product with ID: {product_id}")
    
    # Find the product using data access layer
    product = product_data_access.get_product_by_id(product_id)
    if not product:
        logger.warning(f"Product not found with ID: {product_id}")
        raise HTTPException(status_code=404, detail="Product not found")
    
    logger.info(f"Successfully retrieved product: {product.name}")
    return product

@app.get("/products/category/{category}", response_model=List[ProductResponse])
def get_products_by_category(category: str):
    """
    Get products by category
    
    Note: Authorization handled by Envoy Gateway (requires 'user' role)
    """
    logger.info(f"Fetching products by category: {category}")
    
    filtered_products = product_data_access.get_products_by_category(category)
    logger.info(f"Found {len(filtered_products)} products in category: {category}")
    
    return filtered_products

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("SERVICE_PORT", 8000))
    logger.info(f"Starting product service on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)