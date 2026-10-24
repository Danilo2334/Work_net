"""Plantillas de CV con texto escapado y paginación automática."""
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape

import reportlab
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer


FONT_DIRECTORY = Path(reportlab.__file__).parent / "fonts"
pdfmetrics.registerFont(TTFont("WorkNetCV", str(FONT_DIRECTORY / "Vera.ttf")))
pdfmetrics.registerFont(TTFont("WorkNetCV-Bold", str(FONT_DIRECTORY / "VeraBd.ttf")))
pdfmetrics.registerFontFamily("WorkNetCV", normal="WorkNetCV", bold="WorkNetCV-Bold")

PALETTE = {"text": colors.HexColor("#253238"), "muted": colors.HexColor("#59656b"), "brand": colors.HexColor("#087f70")}
TEMPLATES = {
    "clasica": {"alignment": TA_CENTER, "name_size": 22, "margin": 48, "accent": PALETTE["text"], "rules": True},
    "moderna": {"alignment": TA_LEFT, "name_size": 25, "margin": 58, "accent": PALETTE["brand"], "rules": True},
    "minimalista": {"alignment": TA_LEFT, "name_size": 20, "margin": 54, "accent": PALETTE["text"], "rules": False},
}
LEVELS = {"basico": "Básico", "intermedio": "Intermedio", "avanzado": "Avanzado", "nativo": "Nativo"}


def safe_text(value):
    return escape(str(value or "")).replace("\n", "<br/>")


def period(record):
    start, end = record.get("start_date"), record.get("end_date")
    if not start and not end:
        return ""
    return " - ".join(str(value) for value in (start or "", end or "Actualidad"))


def render_curriculum(template, data):
    theme = TEMPLATES[template]
    output = BytesIO()
    margin = theme["margin"]
    document = SimpleDocTemplate(
        output, pagesize=A4, leftMargin=margin, rightMargin=margin,
        topMargin=44, bottomMargin=46, title="Currículum", author=data["personal"]["full_name"],
    )
    body = ParagraphStyle("body", fontName="WorkNetCV", fontSize=9.5, leading=14,
                          textColor=PALETTE["text"], spaceAfter=6, splitLongWords=True)
    name = ParagraphStyle("name", parent=body, fontName="WorkNetCV-Bold", fontSize=theme["name_size"],
                          leading=theme["name_size"] + 6, alignment=theme["alignment"], spaceAfter=9)
    contact = ParagraphStyle("contact", parent=body, fontSize=8.5, leading=13,
                             alignment=theme["alignment"], textColor=PALETTE["muted"], spaceAfter=4)
    heading = ParagraphStyle("heading", parent=body, fontName="WorkNetCV-Bold", fontSize=10.5,
                             textColor=theme["accent"], spaceBefore=13, spaceAfter=6, keepWithNext=True)
    entry = ParagraphStyle("entry", parent=body, fontName="WorkNetCV-Bold", spaceAfter=2, keepWithNext=True)
    detail = ParagraphStyle("detail", parent=body, fontSize=8.5, leading=12, textColor=PALETTE["muted"])
    story = [Paragraph(safe_text(data["personal"]["full_name"]), name)]
    contacts = [data["personal"].get(key, "") for key in ("email", "phone", "location", "website")]
    if any(contacts):
        story.append(Paragraph(" · ".join(safe_text(value) for value in contacts if value), contact))
    story.append(Spacer(1, 8))

    def section(title):
        story.append(Paragraph(safe_text(title), heading))
        if theme["rules"]:
            rule = HRFlowable(width="100%", thickness=.5, color=theme["accent"], spaceAfter=7)
            rule.keepWithNext = True
            story.append(rule)

    if data.get("professional_summary"):
        section("Perfil profesional")
        story.append(Paragraph(safe_text(data["professional_summary"]), body))
    for key, title, main, organization in (
        ("experience", "Experiencia", "position", "company"),
        ("education", "Educación", "qualification", "institution"),
        ("certifications", "Certificaciones", "title", "issuer"),
    ):
        if not data.get(key):
            continue
        section(title)
        for row in data[key]:
            story.append(Paragraph(safe_text(row[main]), entry))
            dates = row.get("issue_date", "") if key == "certifications" else period(row)
            subtitle = " · ".join(safe_text(value) for value in (row.get(organization), dates) if value)
            # Un párrafo vacío mantiene el título unido al flujo siguiente.
            story.append(Paragraph(subtitle or " ", detail))
            if row.get("description"):
                story.append(Paragraph(safe_text(row["description"]), body))
            story.append(Spacer(1, 4))
    for key, title in (("skills", "Habilidades"), ("languages", "Idiomas")):
        if not data.get(key):
            continue
        section(title)
        for row in data[key]:
            level = LEVELS.get(row.get("level"), row.get("level", ""))
            story.append(Paragraph(" · ".join(safe_text(value) for value in (row["name"], level) if value), body))
    for extra in data.get("extra_sections", []):
        section(extra["title"])
        story.append(Paragraph(safe_text(extra["content"]), body))

    def page_decoration(canvas, doc):
        canvas.saveState()
        if template == "moderna":
            canvas.setFillColor(PALETTE["brand"])
            canvas.rect(26, 40, 4, A4[1] - 80, stroke=0, fill=1)
        canvas.setFont("WorkNetCV", 8)
        canvas.setFillColor(PALETTE["muted"])
        canvas.drawRightString(A4[0] - margin, 25, str(doc.page))
        canvas.restoreState()

    document.build(story, onFirstPage=page_decoration, onLaterPages=page_decoration)
    return output.getvalue()
