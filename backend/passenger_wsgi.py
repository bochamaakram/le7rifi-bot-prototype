"""Select this startup file and `application` in cPanel Setup Python App."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.passenger import create_application

try:
    application = create_application()
except Exception:
    # Do not let Passenger print settings inputs or connection strings.
    raise RuntimeError("Backend startup failed. Check private hosting configuration against docs/O2SWITCH.md.") from None
