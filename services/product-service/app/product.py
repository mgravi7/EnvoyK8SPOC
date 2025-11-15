from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from decimal import Decimal

class Product(BaseModel):
    id: int
    name: str
    description: str
    price: Decimal
    category: str
    stock_quantity: int
    created_at: datetime
    
class ProductCreate(BaseModel):
    name: str
    description: str
    price: Decimal
    category: str
    stock_quantity: int
    
class ProductResponse(BaseModel):
    id: int
    name: str
    description: str
    price: Decimal
    category: str
    stock_quantity: int
    created_at: datetime