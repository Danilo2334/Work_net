"""Proyección de campos públicos estructurados para filtros SQL portables."""
import unicodedata

SELECTION_SECTIONS = ("experience", "education", "skills")


def normalized(text):
    if not isinstance(text, str):
        return ""
    return " ".join("".join(c for c in unicodedata.normalize("NFKD", text).casefold()
                            if not unicodedata.combining(c)).split())


def selection_text(rows, section):
    result = []
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict):
            result.append(normalized(row))
            continue
        title = row.get({"experience": "position", "education": "qualification", "skills": "name"}[section],
                        row.get("title", row.get("name", "")))
        keys = {"experience": ("company", "description"), "education": ("institution",), "skills": ()}[section]
        result.append(" ".join(filter(None, [normalized(title), *[normalized(row.get(k)) for k in keys]])))
    # Una frase no cruza dos registros; no se indexan ID, fechas, nivel ni claves privadas.
    return "\n".join(filter(None, result))


def populate_selection(profile):
    for section in SELECTION_SECTIONS:
        setattr(profile, "selection_" + section, selection_text(getattr(profile, section), section))
