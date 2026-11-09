"""HU025: documento acotado, con las mismas coincidencias y orden de HU020."""
import csv
from datetime import timezone as utc_timezone
from io import BytesIO, StringIO
import unicodedata

from django.http import HttpResponse
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import LongTable, Paragraph, SimpleDocTemplate, Spacer, TableStyle

from curriculum.pdf import safe_text  # Fuentes Unicode registradas de la aplicación.
from .applicants import ApplicantParameters, filtered_applicants, owned_offer
from .selection import ApplicationProfileView

MAX_EXPORT_ROWS = 5000
HEADERS = ("Oferta ID", "Oferta", "Postulación ID", "Nombre", "Fecha UTC", "Estado", "CV enviado")
STATES = {"submitted": "Enviada", "in_review": "En revisión", "accepted": "Aceptada", "rejected": "Rechazada"}


class ExportParameters(ApplicantParameters):
    page = page_size = None
    file_type = serializers.ChoiceField(choices=("csv", "pdf"))


def clean_text(value):
    # Evitar controles de terminal/bidi en documentos sin alterar los datos guardados.
    return "".join(" " if unicodedata.category(c).startswith("C") else c for c in str(value or ""))


def csv_cell(value):
    text = clean_text(value)
    # Comillas CSV no impiden que una hoja de cálculo interprete fórmulas.
    if text.lstrip().startswith(("=", "+", "-", "@")):
        text = "'" + text
    return text


def date_label(value):
    return value.astimezone(utc_timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def csv_document(offer, rows):
    output = StringIO(newline="")
    writer = csv.writer(output, lineterminator="\r\n", quoting=csv.QUOTE_ALL)
    writer.writerow(HEADERS)
    for row in rows:
        writer.writerow([csv_cell(v) for v in (offer.pk, offer.title, row["id"], row["candidate__full_name"],
            date_label(row["created_at"]), STATES.get(row["status"], row["status"]), row["cv_filename"] or "No registrado")])
    return output.getvalue().encode("utf-8-sig")


def pdf_document(offer, rows, params, generated_at):
    output = BytesIO()
    page = landscape(A4)
    doc = SimpleDocTemplate(output, pagesize=page, leftMargin=34, rightMargin=34,
                           topMargin=32, bottomMargin=38, title="Postulantes WorkNet", author="WorkNet")
    body = ParagraphStyle("export-body", fontName="WorkNetCV", fontSize=8, leading=11, splitLongWords=True)
    heading = ParagraphStyle("export-title", parent=body, fontName="WorkNetCV-Bold", fontSize=15, leading=19, spaceAfter=10)
    p = lambda value: Paragraph(safe_text(clean_text(value)), body)
    story = [Paragraph("Postulantes de la oferta", heading), p(f"{offer.pk} - {offer.title}"), Spacer(1, 7),
             p(f"{len(rows)} coincidencias. Perfil actual. Todas las páginas. Generado: {date_label(generated_at)}"),
             p("Filtros: " + "; ".join(f"{label}: {params[key] or 'Sin filtro'}" for key,label in
                (("experience","Experiencia"),("education","Educación"),("skill","Habilidad"))) + "; Orden: " + params["order"]),
             Spacer(1, 12)]
    data = [[p(v) for v in ("ID", "Nombre", "Fecha UTC", "Estado", "CV enviado")]]
    for row in rows:
        data.append([p(v) for v in (row["id"], row["candidate__full_name"], date_label(row["created_at"]),
                                   STATES.get(row["status"], row["status"]), row["cv_filename"] or "No registrado")])
    table = LongTable(data, colWidths=[38, 210, 143, 90, page[0]-68-481], repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),colors.HexColor("#dbeee9")),
        ("VALIGN",(0,0),(-1,-1),"TOP"),("BOTTOMPADDING",(0,0),(-1,-1),7),
        ("TOPPADDING",(0,0),(-1,-1),7),("LINEBELOW",(0,0),(-1,0),.7,colors.HexColor("#087f70")),
        ("LINEBELOW",(0,1),(-1,-1),.25,colors.HexColor("#d2d9d7"))]))
    story.append(table)
    def footer(canvas, document):
        canvas.setFont("WorkNetCV",8)
        canvas.drawString(34,20,"WorkNet - Información autorizada de postulantes")
        canvas.drawRightString(page[0]-34,20,f"Página {document.page}")
    doc.build(story,onFirstPage=footer,onLaterPages=footer)
    return output.getvalue()


class CompanyApplicantExportView(ApplicationProfileView):
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Authorization"
        response["X-Content-Type-Options"] = "nosniff"
        response["Access-Control-Expose-Headers"] = "Content-Disposition, X-Export-Count, X-Export-Scope"
        return response

    def get(self, request, offer_id):
        offer = owned_offer(request.user, offer_id)
        serializer = ExportParameters(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        params = serializer.validated_data
        # Proyección explícita: nunca carga CV, correos, perfil completo ni hashes.
        rows = list(filtered_applicants(offer, params).values(
            "id", "candidate__full_name", "created_at", "status", "cv_filename")[:MAX_EXPORT_ROWS+1])
        if not rows:
            raise ValidationError({"detail": "No hay postulantes que coincidan con esta consulta para exportar."})
        if len(rows) > MAX_EXPORT_ROWS:
            raise ValidationError({"detail": f"La exportación admite hasta {MAX_EXPORT_ROWS} coincidencias. Aplica filtros para reducirlas."})
        generated_at = timezone.now()
        file_type = params["file_type"]
        raw = csv_document(offer, rows) if file_type == "csv" else pdf_document(offer, rows, params, generated_at)
        response = HttpResponse(raw, content_type="text/csv; charset=utf-8" if file_type == "csv" else "application/pdf")
        response["Content-Disposition"] = f'attachment; filename="postulantes-oferta-{offer.pk}.{file_type}"'
        response["X-Export-Count"] = str(len(rows))
        response["X-Export-Scope"] = "all_filtered_applicants"
        return response
