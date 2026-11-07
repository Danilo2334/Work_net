from datetime import timedelta
from decimal import Decimal

from django.test import TestCase, override_settings
from django.utils import timezone

from accounts.models import CompanyReview
from .models import Application, JobOffer, SavedOffer, active_offers
from . import test_offers as publishing_tests


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class EditOfferTests(TestCase):
    authenticate = publishing_tests.PublishOfferTests.authenticate
    listing = "/api/company/offers/active/"

    def setUp(self):
        publishing_tests.PublishOfferTests.setUp(self)
        self.offer = JobOffer.objects.create(**self.data, company=self.company, company_name="Empresa QA",
                                            status="published", published_at=timezone.now())
        self.url = f"/api/company/offers/{self.offer.pk}/"

    def stored(self):
        return JobOffer.objects.filter(pk=self.offer.pk).values().get()

    def test_list_and_detail_use_dashboard_active_definition(self):
        now = timezone.now()
        future = JobOffer.objects.create(**self.data, company=self.company, status="published", expires_at=now + timedelta(days=1))
        for state in ("draft", "closed", "archived"):
            JobOffer.objects.create(**self.data, company=self.company, status=state)
        JobOffer.objects.create(**self.data, company=self.company, status="published", expires_at=now)
        ids = set(active_offers(JobOffer.objects.all(), at=now).values_list("id", flat=True))
        self.assertEqual(ids, {self.offer.pk, future.pk})
        result = self.client.get(self.listing)
        self.assertEqual({o["id"] for o in result.data["offers"]}, ids)
        self.assertEqual(result.data["count"], 2)
        self.assertIsNone(result.data["next_page"])
        detail = self.client.get(self.url)
        for key, value in self.data.items():
            self.assertEqual(detail.data["offer"][key], value)
        self.assertIn("no-store", detail["Cache-Control"])
        self.assertIn("Authorization", detail["Vary"])
        self.assertEqual(self.client.get('/api/dashboard/company/').data['metrics']['active_offers'], 2)

    def test_edit_all_fields_preserves_identity_relations_and_approval(self):
        Application.objects.create(candidate=self.company, offer=self.offer)
        SavedOffer.objects.create(candidate=self.company, offer=self.offer)
        before = self.stored()
        changes = dict(title="Oferta actualizada", description="Descripción actualizada", requirements="Requisitos nuevos",
                       salary="1234567.89", location="Bogotá", category="Educación", contract_type="Fijo")
        reviews = CompanyReview.objects.count()
        response = self.client.patch(self.url, changes, format="json")
        self.assertEqual(response.status_code, 200)
        after = self.stored()
        for key in set(before) - set(changes):
            self.assertEqual(before[key], after[key], key)
        for key, value in changes.items():
            self.assertEqual(after[key], Decimal(value) if key == "salary" else value)
        self.assertEqual(self.client.get(self.url).data['offer']['title'], changes['title'])
        self.assertEqual(Application.objects.get().offer_id, self.offer.pk)
        self.assertEqual(SavedOffer.objects.get().offer_id, self.offer.pk)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.state, "approved")
        self.assertEqual(CompanyReview.objects.count(), reviews)
        self.assertEqual(JobOffer.objects.count(), 1)

    def test_partial_update_and_empty_body(self):
        before = self.stored()
        self.assertEqual(self.client.patch(self.url, {"title": "Solo título"}, format="json").status_code, 200)
        self.assertEqual(self.stored(), {**before, "title": "Solo título"})
        self.assertEqual(self.client.patch(self.url, {}, format="json").status_code, 400)

    def test_invalid_fields_never_partially_write(self):
        before = self.stored()
        invalid = {k: [None, "", " "] for k in self.data}
        invalid['salary'] += ['-1', 'NaN', '1.001', '10000000000']
        invalid['title'] += ['x' * 201]
        invalid['description'] += ['x' * 10001]
        invalid['category'] += ['inventada']
        invalid['contract_type'] += ['inventado']
        for field, values in invalid.items():
            for value in values:
                with self.subTest(field=field, value=str(value)[:20]):
                    response = self.client.patch(self.url, {**self.data, 'title': 'No debe persistir', field: value}, format='json')
                    self.assertEqual(response.status_code, 400)
                    self.assertEqual(self.stored(), before)

    def test_readonly_and_unknown_fields_cannot_change_owner_state_or_identity(self):
        before = self.stored()
        for field in ('id','company','company_name','status','published_at','expires_at','unknown'):
            self.assertEqual(self.client.patch(self.url, {'title': 'No guardar', field: 'forged'}, format='json').status_code, 400)
            self.assertEqual(self.stored(), before)

    def test_all_noneditable_states_and_expired_publication_rejected(self):
        for state in ('draft', 'archived', 'closed', 'unknown', 'published'):
            self.offer.status = state
            self.offer.expires_at = timezone.now() - timedelta(seconds=1) if state == 'published' else None
            self.offer.save()
            before = self.stored()
            self.assertEqual(self.client.get(self.url).status_code, 409)
            self.assertEqual(self.client.patch(self.url, {'title': 'No guardar'}, format='json').status_code, 409)
            self.assertEqual(self.client.get(self.listing).data['count'], 0)
            self.assertEqual(self.stored(), before)

    def test_foreign_and_missing_share_not_found_and_query_cannot_change_owner(self):
        other = type(self.company).objects.create_user('otra@offers.test', 'Test123!', role='empresa', email_verified=True)
        foreign = JobOffer.objects.create(**self.data, company=other, status='published')
        for method in ('get','patch'):
            kwargs = {'format':'json'} if method == 'patch' else {}
            a = getattr(self.client, method)(f'/api/company/offers/{foreign.pk}/?company={other.pk}', {}, **kwargs)
            b = getattr(self.client, method)('/api/company/offers/999999/', {}, **kwargs)
            self.assertEqual(a.status_code, 404)
            self.assertEqual(a.data, b.data)
        self.assertEqual([o['id'] for o in self.client.get(self.listing, {'company': other.pk}).data['offers']], [self.offer.pk])

    def test_role_verification_and_approval_are_required_for_all_endpoints(self):
        before = self.stored()
        for role, staff, verified, state in [('candidato', False, True, 'approved'),('empresa', True, True, 'approved'),
                ('empresa', False, False, 'approved'),('empresa', False, True, 'pending'),('empresa', False, True, 'rejected')]:
            self.company.role,self.company.is_staff,self.company.email_verified=role,staff,verified;self.company.save()
            self.profile.state=state;self.profile.save()
            for url in (self.listing,self.url):self.assertEqual(self.client.get(url).status_code,403)
            self.assertEqual(self.client.patch(self.url, {'title':'No guardar'},format='json').status_code,403)
        self.profile.delete()
        self.assertEqual(self.client.get(self.listing).status_code,403)
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code,401)
        self.assertEqual(self.client.get(self.listing).status_code,401)
        self.assertEqual(self.client.patch(self.url, self.data,format='json').status_code,401)
        self.assertEqual(self.stored(), before)

    def test_minimal_consultation_is_paginated_and_does_not_write(self):
        for i in range(22): JobOffer.objects.create(**self.data,company=self.company,status='published')
        before=list(JobOffer.objects.values())
        first=self.client.get(self.listing);second=self.client.get(self.listing,{'page':2})
        self.assertEqual(len(first.data['offers']),20);self.assertEqual(first.data['next_page'],2)
        self.assertEqual(len(second.data['offers']),3);self.assertEqual(second.data['previous_page'],1)
        self.assertEqual(self.client.get(self.listing,{'page':'incorrecta'}).status_code,404)
        self.assertEqual(before,list(JobOffer.objects.values()))
        for method in ('post','put','delete'):
            self.assertEqual(getattr(self.client,method)(self.url,{},format='json').status_code,405)
        self.assertEqual(self.client.post(self.listing,{},format='json').status_code,405)
