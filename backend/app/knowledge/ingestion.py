import io
import re


def chunks(text: str, size: int = 1200, overlap: int = 150) -> list[str]:
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", text).strip()
    return [text[i:i + size] for i in range(0, len(text), size - overlap) if text[i:i + size].strip()]


def extract(data: bytes, filename: str, mime: str) -> str:
    from pypdf import PdfReader
    suffix = filename.lower().rsplit(".", 1)[-1]
    if suffix == "pdf" and mime == "application/pdf" and data.startswith(b"%PDF-"):
        reader = PdfReader(io.BytesIO(data))
        if reader.is_encrypted or len(reader.pages) > 50:
            raise ValueError("pdf_limit")
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
    elif suffix in {"txt", "md"} and mime in {"text/plain", "text/markdown"} and b"\x00" not in data:
        text = data.decode("utf-8")
    else:
        raise ValueError("unsupported_document")
    if not text.strip() or len(text) > 100_000:
        raise ValueError("document_text_limit")
    return text
