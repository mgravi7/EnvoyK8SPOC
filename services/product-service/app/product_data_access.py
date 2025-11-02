"""
Product Data Access Layer
Handles all data operations for products (currently mock data, future: database)
"""
from typing import List, Optional
from datetime import datetime
from decimal import Decimal
from product_model import Product


class ProductDataAccess:
    """Data access class for product operations"""
    
    def __init__(self):
        # Mock data for now (will be replaced with database)
        self._products_db = [
            Product(
                id=1,
                name="Laptop",
                description="High-performance laptop for professionals",
                price=Decimal("999.99"),
                category="Electronics",
                stock_quantity=50,
                created_at=datetime.now()
            ),
            Product(
                id=2,
                name="Smartphone",
                description="Latest smartphone with advanced features",
                price=Decimal("699.99"),
                category="Electronics",
                stock_quantity=100,
                created_at=datetime.now()
            ),
            Product(
                id=3,
                name="Coffee Maker",
                description="Automatic coffee maker with timer",
                price=Decimal("89.99"),
                category="Appliances",
                stock_quantity=25,
                created_at=datetime.now()
            )
        ]
    
    def get_all_products(self) -> List[Product]:
        """
        Retrieve all products from the data store
        
        Returns:
            List[Product]: All products in the system
        """
        return self._products_db.copy()
    
    def get_product_by_id(self, product_id: int) -> Optional[Product]:
        """
        Retrieve a specific product by ID
        
        Args:
            product_id: The product ID to search for
            
        Returns:
            Optional[Product]: The product if found, None otherwise
        """
        return next(
            (product for product in self._products_db if product.id == product_id), 
            None
        )
    
    def get_products_by_category(self, category: str) -> List[Product]:
        """
        Retrieve products filtered by category (case-insensitive)
        
        Args:
            category: Category name to filter by
            
        Returns:
            List[Product]: Products matching the category
        """
        return [
            product for product in self._products_db 
            if product.category.lower() == category.lower()
        ]
    
    def get_product_count(self) -> int:
        """
        Get the total number of products
        
        Returns:
            int: Total product count
        """
        return len(self._products_db)
    
    def get_available_categories(self) -> List[str]:
        """
        Get list of unique product categories
        
        Returns:
            List[str]: Unique categories in the system
        """
        categories = set(product.category for product in self._products_db)
        return sorted(list(categories))


# Global instance for dependency injection
product_data_access = ProductDataAccess()