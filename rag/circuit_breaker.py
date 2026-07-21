"""
Circuit breaker pattern for external service calls.
Prevents cascade failures when dependencies are down.

States:
- CLOSED: Normal operation, requests pass through
- OPEN: Service is down, requests fail immediately
- HALF_OPEN: Testing if service has recovered
"""
import time
import logging
import threading
from enum import Enum

logger = logging.getLogger(__name__)


class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"


class CircuitBreaker:
    """
    Circuit breaker to protect against cascade failures.

    Usage:
        breaker = CircuitBreaker(failure_threshold=5, recovery_timeout=60)

        @breaker
        def call_external_service():
            ...
    """

    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        half_open_max_calls: int = 3,
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.half_open_max_calls = half_open_max_calls

        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._last_failure_time = 0
        self._half_open_calls = 0
        self._lock = threading.Lock()

    @property
    def state(self) -> CircuitState:
        with self._lock:
            if self._state == CircuitState.OPEN:
                # Check if recovery timeout has passed
                if time.time() - self._last_failure_time > self.recovery_timeout:
                    self._state = CircuitState.HALF_OPEN
                    self._half_open_calls = 0
                    logger.info(f"Circuit breaker transitioning to HALF_OPEN")
            return self._state

    def _record_success(self):
        with self._lock:
            self._failure_count = 0
            if self._state == CircuitState.HALF_OPEN:
                self._success_count += 1
                if self._success_count >= self.half_open_max_calls:
                    self._state = CircuitState.CLOSED
                    self._success_count = 0
                    logger.info(f"Circuit breaker CLOSED - service recovered")

    def _record_failure(self):
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.time()

            if self._state == CircuitState.HALF_OPEN:
                self._state = CircuitState.OPEN
                logger.warning(f"Circuit breaker OPEN - service still down")
            elif self._failure_count >= self.failure_threshold:
                self._state = CircuitState.OPEN
                logger.warning(f"Circuit breaker OPEN - too many failures ({self._failure_count})")

    def __call__(self, func):
        def wrapper(*args, **kwargs):
            current_state = self.state

            if current_state == CircuitState.OPEN:
                raise CircuitBreakerOpenError(
                    f"Circuit breaker is OPEN. Service unavailable for {self.recovery_timeout}s"
                )

            if current_state == CircuitState.HALF_OPEN:
                with self._lock:
                    if self._half_open_calls >= self.half_open_max_calls:
                        raise CircuitBreakerOpenError("Circuit breaker HALF_OPEN - max calls reached")
                    self._half_open_calls += 1

            try:
                result = func(*args, **kwargs)
                self._record_success()
                return result
            except Exception as e:
                self._record_failure()
                raise

        return wrapper

    def reset(self):
        """Manually reset the circuit breaker."""
        with self._lock:
            self._state = CircuitState.CLOSED
            self._failure_count = 0
            self._success_count = 0
            self._half_open_calls = 0
            logger.info("Circuit breaker manually reset")


class CircuitBreakerOpenError(Exception):
    """Raised when circuit breaker is open."""
    pass


# Pre-configured circuit breakers for common dependencies
qdrant_breaker = CircuitBreaker(failure_threshold=3, recovery_timeout=30)
groq_breaker = CircuitBreaker(failure_threshold=5, recovery_timeout=60)
embedding_breaker = CircuitBreaker(failure_threshold=3, recovery_timeout=30)
