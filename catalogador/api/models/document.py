from pydantic import BaseModel
from typing import Optional


class Document(BaseModel):
    filename: str
    content_type: Optional[str] = None
    size: Optional[int] = None
