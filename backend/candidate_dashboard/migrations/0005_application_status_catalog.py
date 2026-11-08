from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("candidate_dashboard", "0004_application_cv_document_application_cv_filename_and_more")]
    operations = [migrations.AlterField(
        model_name="application", name="status",
        field=models.CharField(max_length=20, default="submitted", choices=[
            ("submitted", "Enviada"), ("in_review", "En revisión"),
            ("accepted", "Aceptada"), ("rejected", "Rechazada"),
        ]),
    )]
