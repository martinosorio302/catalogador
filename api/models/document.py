
from pydantic import BaseModel


class Document(BaseModel):
    filename: str
    content_type: str | None = None
    size: int | None = None
