"""
Rate limiting middleware for FastAPI.
Implements sliding window rate limiting per IP address.

Limits:
- /chat/* endpoints: 60 requests per minute
- /admin/* endpoints: 30 requests per minute
- Default: 100 requests per minute
"""
import time
import logging
from collections import defaultdict
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

logger = logging.getLogger(__name__)


class RateLimiter:
    """Sliding window rate limiter."""

    def __init__(self, max_requests: int = 100, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._cleanup_interval = 60  # Cleanup every 60 seconds
        self._last_cleanup = time.time()

    def _cleanup(self):
        """Remove old entries outside the window."""
        now = time.time()
        if now - self._last_cleanup < self._cleanup_interval:
            return

        cutoff = now - self.window_seconds
        for ip in list(self._requests.keys()):
            self._requests[ip] = [t for t in self._requests[ip] if t > cutoff]
            if not self._requests[ip]:
                del self._requests[ip]

        self._last_cleanup = now

    def check(self, key: str) -> tuple[bool, int, int]:
        """
        Check if request is allowed.

        Returns:
            (allowed, remaining, reset_seconds)
        """
        self._cleanup()

        now = time.time()
        cutoff = now - self.window_seconds

        # Get requests in window
        requests = self._requests[key]
        window_requests = [t for t in requests if t > cutoff]

        if len(window_requests) >= self.max_requests:
            # Calculate reset time
            oldest = min(window_requests) if window_requests else now
            reset_seconds = int(oldest + self.window_seconds - now) + 1
            return False, 0, max(reset_seconds, 1)

        # Allow request
        self._requests[key].append(now)
        remaining = self.max_requests - len(window_requests) - 1
        return True, remaining, self.window_seconds

    def get_key(self, request: Request) -> str:
        """Get rate limit key from request."""
        # Use client IP
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """FastAPI middleware for rate limiting."""

    def __init__(self, app, default_limit: int = 100, admin_limit: int = 30, chat_limit: int = 60):
        super().__init__(app)
        self.default_limiter = RateLimiter(default_limit)
        self.admin_limiter = RateLimiter(admin_limit)
        self.chat_limiter = RateLimiter(chat_limit)

    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        client_ip = self.default_limiter.get_key(request)

        # Select limiter based on path
        if path.startswith("/chat/"):
            limiter = self.chat_limiter
            key = f"chat:{client_ip}"
        elif path.startswith("/admin/"):
            limiter = self.admin_limiter
            key = f"admin:{client_ip}"
        elif path in ("/health", "/docs", "/openapi.json"):
            # Don't rate limit health checks and docs
            return await call_next(request)
        else:
            limiter = self.default_limiter
            key = f"default:{client_ip}"

        allowed, remaining, reset_seconds = limiter.check(key)

        if not allowed:
            logger.warning(f"Rate limit exceeded for {client_ip} on {path}")
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded. Please try again later.",
                headers={
                    "X-RateLimit-Limit": str(limiter.max_requests),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(reset_seconds),
                    "Retry-After": str(reset_seconds),
                },
            )

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limiter.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_seconds)

        return response
