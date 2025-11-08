from fastapi import APIRouter, HTTPException, Header, Request
import os
import logging
from engine import trd

router = APIRouter()
logger = logging.getLogger("catalogador.admin")


@router.post('/reload')
def reload_data(request: Request, x_admin_token: str | None = Header(None)):
    """Reload runtime data (TRD JSON) from disk.

    If the environment variable `ADMIN_RELOAD_TOKEN` is set, require the exact
    token to be provided in the `X-Admin-Token` request header. If not set,
    the endpoint will allow unauthenticated reloads (useful for controlled
    internal networks)—but it's recommended to set a token in production.
    """
    # optional auth by env var
    token_required = os.environ.get('ADMIN_RELOAD_TOKEN')
    if token_required:
        if not x_admin_token or x_admin_token != token_required:
            raise HTTPException(status_code=403, detail='Forbidden')

    try:
        logger.info('Reload requested from %s', request.client.host if request.client else 'unknown')
        result = trd.reload_trd_data()
        if not result.get('loaded'):
            raise RuntimeError(result.get('errors') or 'unknown')
        logger.info('Reloaded TRD data: %s', result.get('counts'))
        return {
            'ok': True,
            'counts': result.get('counts', {}),
        }
    except Exception as e:
        logger.exception('Failed to reload TRD data')
        raise HTTPException(status_code=500, detail=str(e))
