from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class Customer(BaseModel):
    id: int
    name: str
    email: str
    phone: Optional[str] = None
    created_at: datetime
    
class CustomerCreate(BaseModel):
    name: str
    email: str
    phone: Optional[str] = None
    
class CustomerResponse(BaseModel):
    id: int
    name: str
    email: str
    phone: Optional[str] = None
    created_at: datetime