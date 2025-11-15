from typing import Optional

from pydantic import BaseModel


class Document(BaseModel):
    filename: str
    content_type: Optional[str] = None
    size: Optional[int] = None
