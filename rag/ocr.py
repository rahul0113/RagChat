"""
OCR support for extracting text from image-based PDFs and scanned documents.
Modular design — swap engines by changing OCR_ENGINE setting.
"""
import io
import logging
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def is_scanned_pdf(pdf_bytes: bytes) -> bool:
    """
    Heuristic: if a PDF produces no extractable text but has images,
    it's likely a scanned document.
    """
    try:
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(pdf_bytes))

        # If any page has text, it's not fully scanned
        for page in reader.pages[:5]:  # Check first 5 pages
            text = page.extract_text()
            if text and text.strip():
                return False

        # Check if PDF has images
        for page in reader.pages[:5]:
            if "/XObject" in (page.get("/Resources") or {}):
                return True

        return True  # No text found, likely scanned
    except Exception:
        return False


def ocr_pdf(pdf_bytes: bytes) -> str:
    """Extract text from a scanned PDF using the configured OCR engine."""
    if not settings.OCR_ENABLED:
        raise ValueError("OCR is disabled. Set OCR_ENABLED=true to enable.")

    engine = settings.OCR_ENGINE
    if engine == "tesseract":
        return _ocr_with_tesseract(pdf_bytes)
    elif engine == "easyocr":
        return _ocr_with_easyocr(pdf_bytes)
    else:
        raise ValueError(f"Unknown OCR engine: {engine}")


def _ocr_with_tesseract(pdf_bytes: bytes) -> str:
    """OCR using pytesseract + Pillow."""
    try:
        import pytesseract
        from PIL import Image
        from pypdf import PdfReader

        reader = PdfReader(io.BytesIO(pdf_bytes))
        all_text = []

        for page_num, page in enumerate(reader.pages):
            # Try to extract images from the page
            images = _extract_images_from_page(page)
            if not images:
                continue

            for img_bytes in images:
                try:
                    img = Image.open(io.BytesIO(img_bytes))
                    text = pytesseract.image_to_string(img)
                    if text.strip():
                        all_text.append(text.strip())
                        logger.debug(f"OCR extracted {len(text)} chars from page {page_num + 1}")
                except Exception as e:
                    logger.warning(f"Failed to OCR image on page {page_num + 1}: {e}")

        if not all_text:
            # Fallback: convert entire PDF pages to images
            try:
                import pdf2image
                images = pdf2image.convert_from_bytes(pdf_bytes, dpi=300)
                for i, img in enumerate(images):
                    text = pytesseract.image_to_string(img)
                    if text.strip():
                        all_text.append(text.strip())
            except ImportError:
                logger.warning("pdf2image not available for full-page OCR fallback")

        return "\n\n".join(all_text) if all_text else ""
    except ImportError as e:
        raise ImportError(f"pytesseract/Pillow required for OCR: {e}")


def _ocr_with_easyocr(pdf_bytes: bytes) -> str:
    """OCR using EasyOCR."""
    try:
        import easyocr
        from pypdf import PdfReader

        reader = PdfReader(io.BytesIO(pdf_bytes))
        reader_ocr = easyocr.Reader(["en"])
        all_text = []

        for page_num, page in enumerate(reader.pages):
            images = _extract_images_from_page(page)
            for img_bytes in images:
                try:
                    results = reader_ocr.readtext(img_bytes)
                    text = " ".join([r[1] for r in results])
                    if text.strip():
                        all_text.append(text.strip())
                except Exception as e:
                    logger.warning(f"EasyOCR failed on page {page_num + 1}: {e}")

        return "\n\n".join(all_text) if all_text else ""
    except ImportError as e:
        raise ImportError(f"easyocr required for this OCR engine: {e}")


def _extract_images_from_page(page) -> list[bytes]:
    """Extract image bytes from a PDF page."""
    images = []
    try:
        resources = page.get("/Resources")
        if not resources:
            return images

        xobjects = resources.get("/XObject")
        if not xobjects:
            return images

        for obj_name in xobjects:
            obj = xobjects[obj_name].get_object()
            if obj.get("/Subtype") == "/Image":
                try:
                    img_data = obj.get_data()
                    if img_data:
                        images.append(img_data)
                except Exception:
                    pass
    except Exception:
        pass
    return images


def ocr_image(image_bytes: bytes) -> str:
    """OCR a single image file."""
    if not settings.OCR_ENABLED:
        return ""

    engine = settings.OCR_ENGINE
    try:
        if engine == "tesseract":
            import pytesseract
            from PIL import Image
            img = Image.open(io.BytesIO(image_bytes))
            return pytesseract.image_to_string(img)
        elif engine == "easyocr":
            import easyocr
            reader = easyocr.Reader(["en"])
            results = reader.readtext(image_bytes)
            return " ".join([r[1] for r in results])
    except Exception as e:
        logger.warning(f"OCR failed: {e}")
        return ""
