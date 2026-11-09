from django.db import models
# Create your models here.
from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractUser


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("El correo electrónico es obligatorio.")

        email = self.normalize_email(email)

        user = self.model(
            email=email,
            **extra_fields
        )

        user.set_password(password)
        user.save(using=self._db)

        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        extra_fields.setdefault("email_verified", True)

        return self.create_user(
            email,
            password,
            **extra_fields
        )


class User(AbstractUser):

    class Role(models.TextChoices):
        CANDIDATO = "candidato", "Candidato"
        EMPRESA = "empresa", "Empresa"

    username = None

    full_name = models.CharField(
        max_length=150
    )

    email = models.EmailField(
        unique=True
    )

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        blank=True,
        default="",
    )

    email_verified = models.BooleanField(
        default=False
    )

    push_notifications = models.BooleanField(default=True)
    # Revokes API and Django-admin grants whenever administrative authority changes.
    admin_revision = models.PositiveIntegerField(default=0, editable=False)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.email


class CompanyProfile(models.Model):
    class State(models.TextChoices):
        PENDING = "pending", "Pendiente"
        APPROVED = "approved", "Aprobada"
        REJECTED = "rejected", "Rechazada"

    company = models.OneToOneField(User, on_delete=models.CASCADE)
    legal_name = models.CharField(max_length=200, blank=True)
    tax_id = models.CharField(max_length=20, blank=True)
    sector = models.CharField(max_length=120, blank=True)
    location = models.CharField(max_length=200, blank=True)
    contact_email = models.EmailField(blank=True)
    description = models.TextField(max_length=2000, blank=True)
    website = models.URLField(blank=True)
    social_links = models.JSONField(default=list, blank=True)
    logo_data = models.BinaryField(default=bytes, blank=True, editable=False)
    state = models.CharField(max_length=12, choices=State.choices, default=State.PENDING)
    rejection_reason = models.TextField(blank=True)
    submitted_at = models.DateTimeField(null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name="company_decisions")
    version = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["tax_id"], condition=~models.Q(tax_id=""), name="unique_company_tax_id")]


class CompanyReview(models.Model):
    profile = models.ForeignKey(CompanyProfile, on_delete=models.CASCADE)
    actor = models.ForeignKey(User, null=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=12)
    reason = models.TextField(blank=True)
    snapshot = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)


class AdminAccess(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    role = models.CharField(max_length=12, default="revisor")
    permissions = models.JSONField(default=list)
    version = models.PositiveIntegerField(default=0)


class AdminChallenge(models.Model):
    import uuid
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    password_hash = models.CharField(max_length=64)
    revision = models.PositiveIntegerField()
    expires_at = models.DateTimeField()
    consumed = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)


class AdminMFASession(models.Model):
    token = models.OneToOneField("authtoken.Token", on_delete=models.CASCADE)
    revision = models.PositiveIntegerField()
    password_hash = models.CharField(max_length=64)
    expires_at = models.DateTimeField()


class AdminRecoveryCode(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    digest = models.CharField(max_length=64)


class AdminEvent(models.Model):
    actor = models.ForeignKey(User, null=True, on_delete=models.SET_NULL, related_name="admin_actions")
    target = models.ForeignKey(User, null=True, on_delete=models.SET_NULL, related_name="admin_changes")
    action = models.CharField(max_length=40)
    created_at = models.DateTimeField(auto_now_add=True)
