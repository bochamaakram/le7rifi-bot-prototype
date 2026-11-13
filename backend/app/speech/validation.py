import json
import array
import subprocess
import tempfile
from pathlib import Path


class InvalidAudio(ValueError):
    pass


FORMATS = {"audio/wav": ("wav", ".wav"), "audio/x-wav": ("wav", ".wav"),
           "audio/mp4": ("mov,mp4,m4a,3gp,3g2,mj2", ".m4a"),
           "audio/mpeg": ("mp3", ".mp3"), "audio/webm": ("matroska,webm", ".webm")}


def validate_audio(data: bytes, mime: str, max_bytes: int, max_seconds: int) -> tuple[float, str]:
    if mime not in FORMATS:
        raise InvalidAudio("unsupported_audio_format")
    if not data or len(data) > max_bytes:
        raise InvalidAudio("invalid_audio_size")
    expected, suffix = FORMATS[mime]
    with tempfile.TemporaryDirectory(prefix="le7rayfi-audio-") as directory:
        path = Path(directory) / ("recording" + suffix)
        path.write_bytes(data)
        try:
            result = subprocess.run(["ffprobe", "-v", "error", "-protocol_whitelist", "file,pipe",
                "-show_entries", "format=duration,format_name:stream=codec_type", "-of", "json", str(path)],
                capture_output=True, timeout=5, check=True)
            info = json.loads(result.stdout)
            duration = float(info["format"]["duration"])
            if info["format"]["format_name"] != expected:
                raise InvalidAudio("audio_type_mismatch")
            if not any(s["codec_type"] == "audio" for s in info["streams"]):
                raise InvalidAudio("invalid_audio")
            if not 0.1 <= duration <= max_seconds:
                raise InvalidAudio("audio_duration_limit")
            # Decode first: malformed/truncated files must never reach a paid provider.
            decoded = subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-protocol_whitelist", "file,pipe",
                "-i", str(path), "-t", str(max_seconds + 1), "-ac", "1", "-ar", "16000", "-f", "s16le", "pipe:1"],
                capture_output=True, timeout=10, check=True)
            samples = array.array("h", decoded.stdout)
            actual_duration = len(samples) / 16000
            if not 0.1 <= actual_duration <= max_seconds:
                raise InvalidAudio("audio_duration_limit")
            if not samples or max(abs(value) for value in samples) <= 16:
                raise InvalidAudio("no_speech_detected")
            return actual_duration, "recording" + suffix
        except InvalidAudio:
            raise
        except (OSError, subprocess.SubprocessError, ValueError, KeyError):
            raise InvalidAudio("invalid_audio") from None
