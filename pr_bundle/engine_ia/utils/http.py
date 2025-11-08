"""Small HTTP helper to centralize requests timeouts and error handling.

Usage: from utils.http import get, post, request
These functions return the requests.Response on success or raise a RequestError on failure.
"""

from typing import Optional
import requests


class RequestError(Exception):
    def __init__(
        self, message: str, status: Optional[int] = None, text: Optional[str] = None
    ):
        super().__init__(message)
        self.status = status
        self.text = text


DEFAULT_TIMEOUT = 60


def request(
    method: str, url: str, timeout: Optional[int] = None, **kwargs
) -> requests.Response:
    to = timeout or DEFAULT_TIMEOUT
    try:
        resp = requests.request(method, url, timeout=to, **kwargs)
        resp.raise_for_status()
        return resp
    except requests.exceptions.RequestException as e:
        status = None
        text = None
        if hasattr(e, "response") and e.response is not None:
            status = e.response.status_code
            try:
                text = e.response.text
            except Exception:
                text = None
        raise RequestError(str(e), status=status, text=text)


def get(url: str, timeout: Optional[int] = None, **kwargs) -> requests.Response:
    return request("GET", url, timeout=timeout, **kwargs)


def post(url: str, timeout: Optional[int] = None, **kwargs) -> requests.Response:
    return request("POST", url, timeout=timeout, **kwargs)
