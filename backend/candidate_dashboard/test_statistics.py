from datetime import timedelta
from uuid import uuid4
from django.test import TestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.db import connection
from django.utils import timezone
from accounts.models import CompanyProfile, User
from .models import Application, JobOffer, Notification
from .test_applications import ApplicationFixture


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class StatisticsTests(ApplicationFixture, TestCase):
    candidate_url='/api/statistics/candidate/'
    company_url='/api/statistics/company/'

    def dataset(self):
        own=[]
        for i,state in enumerate(Application.Status):
            offer=self.make_offer(title=f'Oferta estadística {i}')
            own.append(Application.objects.create(candidate=self.user,offer=offer,status=state))
            Application.objects.create(candidate=self.other,offer=offer,status=state)
        Application.objects.create(candidate=self.other,offer=self.make_offer(company=self.foreign_company))
        return own

    def test_complete_candidate_counts_private_and_inactive_history_included(self):
        rows=self.dataset()
        JobOffer.objects.filter(pk=rows[0].offer_id).update(status='archived')
        JobOffer.objects.filter(pk=rows[1].offer_id).update(status='closed')
        JobOffer.objects.filter(pk=rows[2].offer_id).update(expires_at=timezone.now()-timedelta(seconds=1))
        r=self.client.get(self.candidate_url);self.assertEqual(r.status_code,200)
        self.assertEqual(r.data['applications_count'],4)
        self.assertEqual(r.data['states'],dict(submitted=1,in_review=1,accepted=1,rejected=1,other=0))
        self.assertEqual(r['Cache-Control'],'private, no-store');self.assertIn('Authorization',r['Vary'])
        self.assertNotIn('offers',r.data)

    def test_company_totals_all_pages_and_per_offer_counts(self):
        self.dataset();self.authenticate(self.company)
        a=self.client.get(self.company_url+'?page_size=2');self.assertEqual(a.status_code,200)
        self.assertEqual(a.data['applications_count'],8);self.assertEqual(a.data['active_offers_count'],5)
        self.assertEqual(a.data['states'],dict(submitted=2,in_review=2,accepted=2,rejected=2,other=0))
        self.assertEqual(a.data['offers']['count'],5);self.assertEqual(a.data['offers']['total_pages'],3)
        seen=[]
        for page in [1,2,3]:
            data=self.client.get(self.company_url+f'?page_size=2&page={page}').data
            self.assertEqual(data['applications_count'],8);self.assertEqual(data['states'],a.data['states'])
            for row in data['offers']['rows']:
                seen.append(row['id']);self.assertEqual(row['applications_count'],sum(row['states'].values()))
        self.assertEqual(len(set(seen)),5);self.assertEqual(len(seen),5)
        self.assertEqual(sum(x['applications_count'] for x in self.client.get(self.company_url).data['offers']['rows']),8)

    def test_active_rule_matches_existing_company_dashboard_at_expiry_boundary(self):
        self.dataset();now=timezone.now()
        for changes in [{'status':'closed'},{'status':'archived'},{'status':'draft'},{'expires_at':now-timedelta(seconds=1)}, {'expires_at':now+timedelta(days=1)}]:
            self.make_offer(**changes)
        self.authenticate(self.company)
        r=self.client.get(self.company_url).data
        self.assertEqual(r['active_offers_count'],6)
        self.assertEqual(r['active_offers_count'],self.client.get('/api/dashboard/company/').data['metrics']['active_offers'])
        self.assertEqual(r['applications_count'],8)

    def test_empty_zero_and_legacy_unknown_state_are_honest(self):
        r=self.client.get(self.candidate_url);self.assertEqual(r.data['applications_count'],0);self.assertEqual(sum(r.data['states'].values()),0)
        self.authenticate(self.foreign_company);r=self.client.get(self.company_url)
        self.assertEqual(r.data['offers']['rows'],[]);self.assertEqual(r.data['active_offers_count'],0)
        self.authenticate(self.user)
        Application.objects.create(candidate=self.user,offer=self.offer,status='historical')
        r=self.client.get(self.candidate_url);self.assertEqual(r.data['applications_count'],1);self.assertEqual(r.data['states']['other'],1)

    def test_real_status_transition_reflects_counts_without_altering_original_pdf(self):
        self.submit();app=Application.objects.get();original=(bytes(app.cv_document),app.created_at)
        self.authenticate(self.company)
        r=self.client.post(f'/api/company/applications/{app.pk}/status/',dict(target_status='in_review',expected_version=0,request_id=str(uuid4()),confirm=True),format='json')
        self.assertEqual(r.status_code,200)
        self.assertEqual(self.client.get(self.company_url).data['states']['in_review'],1)
        self.authenticate(self.user);r=self.client.get(self.candidate_url)
        self.assertEqual((r.data['states']['submitted'],r.data['states']['in_review']),(0,1))
        app.refresh_from_db();self.assertEqual((bytes(app.cv_document),app.created_at),original)

    def test_permissions_revalidated_for_role_email_approval_and_session(self):
        self.assertEqual(self.client.get(self.company_url).status_code,403)
        self.user.email_verified=False;self.user.save(update_fields=['email_verified'])
        self.assertEqual(self.client.get(self.candidate_url).status_code,403)
        self.authenticate(self.company);self.assertEqual(self.client.get(self.candidate_url).status_code,403)
        for state in ['pending','rejected']:
            CompanyProfile.objects.filter(company=self.company).update(state=state)
            self.assertEqual(self.client.get(self.company_url).status_code,403)
        admin=User.objects.create_user('admin@statistics.test','Test12345!',is_staff=True,email_verified=True)
        self.authenticate(admin);self.assertEqual(self.client.get(self.candidate_url).status_code,403);self.assertEqual(self.client.get(self.company_url).status_code,403)
        self.client.credentials()
        for url in [self.candidate_url,self.company_url]:self.assertEqual(self.client.get(url).status_code,401)

    def test_strict_parameters_and_read_only(self):
        self.assertEqual(self.client.get(self.candidate_url+'?candidate_id=1').status_code,400)
        self.authenticate(self.company)
        for q in ['page=0','page=-1','page=1&page=1','page_size=51','page_size=true','page=999','company_id=1','status=accepted']:
            self.assertEqual(self.client.get(self.company_url+'?'+q).status_code,400,q)
        self.assertEqual(self.client.post(self.company_url,{},format='json').status_code,405)

    def test_aggregate_sql_excludes_personal_fields_and_reads_do_not_mutate(self):
        self.dataset();self.authenticate(self.company)
        before=list(Notification.objects.values());apps=list(Application.objects.values())
        with CaptureQueriesContext(connection) as queries:r=self.client.get(self.company_url)
        self.assertEqual(r.status_code,200)
        sql=' '.join(q['sql'] for q in queries.captured_queries)
        self.assertNotIn('cv_document',sql);self.assertNotIn('professional_summary',sql)
        self.assertNotIn('candidate__full_name',str(r.data));self.assertNotIn('email',str(r.data))
        self.assertEqual(list(Notification.objects.values()),before);self.assertEqual(list(Application.objects.values()),apps)
