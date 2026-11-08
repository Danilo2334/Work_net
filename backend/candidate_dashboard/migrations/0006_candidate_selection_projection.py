import unicodedata
from django.db import migrations, models


def backfill(apps, schema_editor):
    Profile = apps.get_model("candidate_dashboard", "CandidateProfile")
    def norm(value):
        return " ".join("".join(c for c in unicodedata.normalize("NFKD", value).casefold()
                                 if not unicodedata.combining(c)).split()) if isinstance(value, str) else ""
    fields = ("selection_experience", "selection_education", "selection_skills")
    for profile in Profile.objects.using(schema_editor.connection.alias).only("id", "experience", "education", "skills").iterator(chunk_size=200):
        for section, title_key, extras in [("experience", "position", ("company", "description")),
                                           ("education", "qualification", ("institution",)), ("skills", "name", ())]:
            rows = getattr(profile, section)
            values = []
            for row in rows if isinstance(rows, list) else []:
                if isinstance(row, dict):
                    title = row.get(title_key, row.get("title", row.get("name", "")))
                    values.append(" ".join(filter(None, [norm(title), *[norm(row.get(k)) for k in extras]])))
                else:
                    values.append(norm(row))
            setattr(profile, "selection_" + section, "\n".join(filter(None, values)))
        profile.save(update_fields=fields, using=schema_editor.connection.alias)


class Migration(migrations.Migration):
    dependencies = [("candidate_dashboard", "0005_application_status_catalog")]
    operations = [
        *[migrations.AddField(model_name="candidateprofile", name="selection_" + section,
                             field=models.TextField(default="", blank=True, editable=False))
          for section in ("experience", "education", "skills")],
        migrations.RunPython(backfill, migrations.RunPython.noop),
    ]
