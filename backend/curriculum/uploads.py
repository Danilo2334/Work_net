from io import BytesIO
from pathlib import PurePosixPath
import re
from urllib.parse import urlsplit

from pypdf import PdfReader
from pypdf.errors import PyPdfError
from pypdf.generic import ArrayObject, DictionaryObject, IndirectObject
from rest_framework.exceptions import ValidationError


MAX_UPLOAD_BYTES = 5 * 1024 * 1024
MAX_UPLOAD_PAGES = 50
DISALLOWED_KEYS = {
    "/JS", "/JavaScript", "/AA", "/OpenAction", "/AcroForm", "/XFA",
    "/EmbeddedFiles", "/RichMediaContent", "/RichMediaSettings",
}
DISALLOWED_ACTIONS = {"/JavaScript", "/Launch", "/SubmitForm", "/ImportData", "/GoToE", "/GoToR", "/Rendition"}
DISALLOWED_ANNOTATIONS = {"/FileAttachment", "/Movie", "/Sound", "/Screen", "/RichMedia", "/Widget"}


def check_document_objects(root):
    """Inspecciona acciones y adjuntos sin ejecutar ni descomprimir contenido."""
    pending = [(root, 0)]
    seen = set()
    while pending:
        value, depth = pending.pop()
        if depth > 80 or len(seen) > 20000:
            raise ValueError("Documento demasiado complejo")
        if isinstance(value, IndirectObject):
            key = ("reference", value.idnum, value.generation)
            if key in seen:
                continue
            seen.add(key)
            value = value.get_object()
        if isinstance(value, (DictionaryObject, ArrayObject)):
            key = ("object", id(value))
            if key in seen:
                continue
            seen.add(key)
        if isinstance(value, DictionaryObject):
            if DISALLOWED_KEYS.intersection(value):
                raise ValueError("Contenido activo o adjunto")
            if value.get("/S") in DISALLOWED_ACTIONS or value.get("/Subtype") in DISALLOWED_ANNOTATIONS:
                raise ValueError("Acción o anotación no admitida")
            if "/URI" in value and urlsplit(str(value["/URI"])).scheme.lower() not in {"http", "https", "mailto"}:
                raise ValueError("Enlace no admitido")
            pending.extend((child, depth + 1) for child in value.values())
        elif isinstance(value, ArrayObject):
            pending.extend((child, depth + 1) for child in value)


def validated_pdf(upload):
    if upload.size > MAX_UPLOAD_BYTES:
        raise ValidationError({"file": "El PDF no puede superar 5 MiB."})
    name = PurePosixPath(upload.name.replace("\\", "/")).name
    if PurePosixPath(name).suffix.lower() != ".pdf" or upload.content_type != "application/pdf":
        raise ValidationError({"file": "Selecciona un archivo PDF válido."})
    raw = upload.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise ValidationError({"file": "El PDF no puede superar 5 MiB."})
    try:
        if not raw.startswith(b"%PDF-") or b"%%EOF" not in raw[-1024:]:
            raise ValueError("PDF incompleto")
        reader = PdfReader(BytesIO(raw), strict=True, root_object_recovery_limit=0)
        if reader.is_encrypted or not 1 <= len(reader.pages) <= MAX_UPLOAD_PAGES:
            raise ValueError("PDF cifrado o cantidad de páginas no admitida")
        check_document_objects(reader.root_object)
    except (PyPdfError, ValueError, TypeError, KeyError, IndexError, AttributeError, RecursionError, OverflowError):
        raise ValidationError({"file": "No pudimos validar el PDF. Exporta un documento de 1 a 50 páginas, sin contraseña, formularios, acciones ni adjuntos."})
    safe_name = re.sub(r"[^\w.-]", "_", PurePosixPath(name).stem).strip("._")[:140] or "curriculum"
    return raw, safe_name + ".pdf"
