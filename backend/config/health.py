"""Dependency probes never expose configuration, identities, or exception text."""

from uuid import uuid4

from django.core.cache import cache
from django.db import connection
from django.http import JsonResponse
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_safe


@never_cache
@require_safe
def live(request):
    return JsonResponse({"status": "ok"})


@never_cache
@require_safe
def ready(request):
    key = f"readiness:{uuid4().hex}"
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            if cursor.fetchone() != (1,):
                raise RuntimeError("Dependency unavailable")
        cache.set(key, "ok", timeout=5)
        if cache.get(key) != "ok":
            raise RuntimeError("Dependency unavailable")
        cache.delete(key)
    except Exception:
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})
