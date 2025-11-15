"""
Security validation and input sanitization utilities.

Provides security functions for validating inputs, detecting threats,
and enforcing security policies across the API.
"""

import re
from pathlib import Path


class SecurityValidator:
    """Security validation and threat detection utilities."""

    # Common path traversal patterns
    PATH_TRAVERSAL_PATTERNS = [
        r"\.\.",  # Parent directory reference
        r"~",     # Home directory reference
        r"\/\/",  # Double slashes
        r"\\\\",  # Double backslashes
    ]

    # Suspicious file extensions
    DANGEROUS_EXTENSIONS = {
        ".exe", ".bat", ".cmd", ".com", ".pif", ".scr", ".vbs",
        ".js", ".jar", ".dll", ".so", ".dylib", ".app", ".sh",
        ".ps1", ".psm1", ".msi", ".deb", ".rpm"
    }

    # Maximum file sizes (in bytes)
    MAX_FILE_SIZE = 20 * 1024 * 1024  # 20 MB default
    MAX_FILENAME_LENGTH = 255

    @staticmethod
    def validate_filename(filename: str) -> tuple[bool, str | None]:
        """
        Validate filename for security issues.

        Args:
            filename: The filename to validate

        Returns:
            tuple: (is_valid: bool, error_message: str | None)
        """
        if not filename:
            return False, "Filename cannot be empty"

        if len(filename) > SecurityValidator.MAX_FILENAME_LENGTH:
            return False, f"Filename too long (max {SecurityValidator.MAX_FILENAME_LENGTH})"

        # Check for path traversal attempts
        for pattern in SecurityValidator.PATH_TRAVERSAL_PATTERNS:
            if re.search(pattern, filename):
                return False, f"Path traversal detected: {pattern}"

        # Check for null bytes
        if "\x00" in filename:
            return False, "Null byte detected in filename"

        # Check for control characters
        if any(ord(c) < 32 for c in filename if c != '\n' and c != '\r' and c != '\t'):
            return False, "Control characters detected in filename"

        # Check for dangerous extensions
        file_ext = Path(filename).suffix.lower()
        if file_ext in SecurityValidator.DANGEROUS_EXTENSIONS:
            return False, f"Dangerous file extension not allowed: {file_ext}"

        return True, None

    @staticmethod
    def sanitize_filename(filename: str) -> str:
        """
        Sanitize filename by removing or replacing dangerous characters.

        Args:
            filename: The filename to sanitize

        Returns:
            str: Sanitized filename
        """
        if not filename:
            return "unnamed_file"

        # Remove path components
        filename = Path(filename).name

        # Remove or replace dangerous characters
        filename = filename.replace("\x00", "")  # Remove null bytes
        filename = re.sub(r'[<>:"/\\|?*]', '_', filename)  # Replace invalid chars

        # Remove control characters
        filename = ''.join(c for c in filename if ord(c) >= 32 or c in '\n\r\t')

        # Limit length
        if len(filename) > SecurityValidator.MAX_FILENAME_LENGTH:
            name = Path(filename).stem[:200]
            ext = Path(filename).suffix
            filename = f"{name}{ext}"

        # Ensure filename is not empty after sanitization
        if not filename or filename == ".":
            filename = "unnamed_file"

        return filename

    @staticmethod
    def validate_file_size(size_bytes: int, max_size: int | None = None) -> tuple[bool, str | None]:
        """
        Validate file size against limits.

        Args:
            size_bytes: File size in bytes
            max_size: Maximum allowed size (default: MAX_FILE_SIZE)

        Returns:
            tuple: (is_valid: bool, error_message: str | None)
        """
        max_allowed = max_size or SecurityValidator.MAX_FILE_SIZE

        if size_bytes <= 0:
            return False, "File size must be positive"

        if size_bytes > max_allowed:
            max_mb = max_allowed / (1024 * 1024)
            return False, f"File too large (max {max_mb:.1f} MB)"

        return True, None

    @staticmethod
    def validate_content_type(content_type: str, allowed_types: list[str]) -> tuple[bool, str | None]:
        """
        Validate content type against allowed types.

        Args:
            content_type: The MIME type to validate
            allowed_types: List of allowed MIME types or patterns

        Returns:
            tuple: (is_valid: bool, error_message: str | None)
        """
        if not content_type:
            return False, "Content-Type header missing"

        # Normalize content type (remove parameters like charset)
        content_type_base = content_type.split(";")[0].strip().lower()

        for allowed in allowed_types:
            if allowed.endswith("*"):
                # Wildcard match (e.g., "application/*")
                prefix = allowed[:-1]
                if content_type_base.startswith(prefix):
                    return True, None
            elif content_type_base == allowed.lower():
                return True, None

        allowed_list = ", ".join(allowed_types)
        return False, f"Content type not allowed. Allowed: {allowed_list}"

    @staticmethod
    def validate_pdf_header(file_bytes: bytes) -> tuple[bool, str | None]:
        """
        Validate that file starts with PDF magic bytes.

        Args:
            file_bytes: First bytes of the file

        Returns:
            tuple: (is_valid: bool, error_message: str | None)
        """
        if len(file_bytes) < 4:
            return False, "File too small to be valid PDF"

        # PDF files start with %PDF-
        pdf_signature = b"%PDF-"
        if not file_bytes.startswith(pdf_signature):
            return False, "File does not appear to be a valid PDF"

        return True, None

    @staticmethod
    def check_rate_limit(
        identifier: str,
        limit: int,
        window_seconds: int,
        storage: dict[str, list[float]]
    ) -> tuple[bool, int]:
        """
        Check if identifier exceeds rate limit.

        Args:
            identifier: Unique identifier (e.g., IP address, user ID)
            limit: Maximum requests per window
            window_seconds: Time window in seconds
            storage: Dictionary to store timestamps per identifier

        Returns:
            tuple: (is_allowed: bool, remaining_requests: int)
        """
        import time

        now = time.time()
        cutoff = now - window_seconds

        # Initialize or clean old entries
        if identifier not in storage:
            storage[identifier] = []

        # Remove timestamps outside the window
        storage[identifier] = [ts for ts in storage[identifier] if ts > cutoff]

        # Check if limit exceeded
        current_count = len(storage[identifier])
        if current_count >= limit:
            return False, 0

        # Add current timestamp
        storage[identifier].append(now)

        remaining = limit - (current_count + 1)
        return True, remaining


# Global rate limit storage (in production, use Redis or similar)
_RATE_LIMIT_STORAGE: dict[str, list[float]] = {}


def get_rate_limit_storage() -> dict[str, list[float]]:
    """Get global rate limit storage."""
    return _RATE_LIMIT_STORAGE
