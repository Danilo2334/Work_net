import csv
from io import BytesIO, StringIO
from unittest.mock import patch

from django.db import connection
from django.test import TestCase, override_settings
from django.test.utils import CaptureQueriesContext
from pypdf import PdfReader

from accounts.models import CompanyProfile, User
from .exports import csv_cell
from .models import Application, CandidateProfile
from .test_applications import ApplicationFixture


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class ExportTests(ApplicationFixture, TestCase):
    def setUp(self):
        super().setUp()
        self.user.full_name = 'Ángela, "QA" <&>'
        self.user.save(update_fields=['full_name'])
        CandidateProfile.objects.create(candidate=self.user, experience=[{'position':'Ingeniera Backend'}],
            education=[{'qualification':'Ingeniería'}],skills=[{'name':'Python'}])
        CandidateProfile.objects.create(candidate=self.other, experience=[{'position':'Ventas'}],skills=[{'name':'Excel'}])
        self.a = Application.objects.create(candidate=self.user,offer=self.offer,cv_filename='CV ángela.pdf')
        self.b = Application.objects.create(candidate=self.other,offer=self.offer,status='in_review')
        self.url = f'/api/company/offers/{self.offer.pk}/applications/export/'
        self.list_url = f'/api/company/offers/{self.offer.pk}/applications/'
        self.authenticate(self.company)

    def csv(self, query=''):
        r=self.client.get(self.url+'?file_type=csv'+query)
        self.assertEqual(r.status_code,200)
        return list(csv.reader(StringIO(r.content.decode('utf-8-sig'))))

    def test_export_matches_all_pages_and_each_canonical_filter_order(self):
        for i in range(12):
            u=User.objects.create_user(f'row{i}@hu025.test',full_name='Zeta QA',role='candidato',email_verified=True)
            Application.objects.create(candidate=u,offer=self.offer)
        for q in ('', '&experience=INGENIERA','&education=ingenieria','&skill=pYtHon',
                  '&experience=Backend&education=ingenieria&skill=Python'):
            for order in ('newest','oldest','name','name_desc'):
                query=q+'&order='+order
                ids=[]
                first=self.client.get(self.list_url+'?page_size=5'+query).data
                for page in range(1,first['total_pages']+1):
                    ids.extend(x['id'] for x in self.client.get(self.list_url+f'?page_size=5&page={page}'+query).data['applications'])
                self.assertEqual([int(x[2]) for x in self.csv(query)[1:]],ids)

    def test_csv_unicode_quoting_utc_and_only_authorized_fields(self):
        rows=self.csv('&order=oldest')
        self.assertEqual(len(rows[0]),7)
        self.assertEqual(rows[1][3],self.user.full_name)
        self.assertEqual(rows[1][-1],'CV ángela.pdf')
        self.assertTrue(rows[1][4].endswith(' UTC'))
        self.assertNotIn(self.user.email,str(rows))
        self.assertNotIn('LocalTest123',str(rows))
        self.assertNotIn('sha256',str(rows))

    def test_csv_neutralizes_formula_prefixes_after_whitespace_and_controls(self):
        for value in ['=1+1','+SUM(A1)','-1+2','@SUM(A1)','  =cmd','\t=1','\r\n+1','\ufeff=1','\u200b@SUM(A1)']:
            self.assertTrue(csv_cell(value).startswith("'"),repr(value))
        for value in ['Ángela','Normal, con comas','Nombre "QA"','123']:
            self.assertEqual(csv_cell(value),value)
        self.user.full_name=' =1+1';self.user.save(update_fields=['full_name'])
        self.offer.title='@Oferta';self.offer.save(update_fields=['title'])
        self.assertEqual(self.csv('&order=oldest')[1][3],"' =1+1")
        self.assertEqual(self.csv()[1][1],"'@Oferta")

    def test_pdf_multi_page_wraps_long_special_names_and_matches_order(self):
        for i in range(55):
            name = (f'Persona {i:03d} '+('NombreLargoÁé <&> '*10))[:User._meta.get_field('full_name').max_length]
            u=User.objects.create_user(f'pdf{i}@hu025.test',full_name=name,role='candidato',email_verified=True)
            filename = ('CV-'+('extenso '*20))[:Application._meta.get_field('cv_filename').max_length-4]+'.pdf'
            Application.objects.create(candidate=u,offer=self.offer,cv_filename=filename)
        r=self.client.get(self.url+'?file_type=pdf&order=oldest')
        self.assertEqual(r.status_code,200)
        reader=PdfReader(BytesIO(r.content));text='\n'.join(p.extract_text() for p in reader.pages)
        self.assertGreater(len(reader.pages),1)
        self.assertIn(self.user.full_name,text)
        self.assertIn('57 coincidencias.',text)
        self.assertLess(text.index('Persona 000'),text.index('Persona 054'))
        self.assertIn('NombreLargoÁé <&>',text)
        self.assertNotIn(self.user.email,text)
        self.assertTrue(all('Página ' in p.extract_text() for p in reader.pages))

    def test_no_data_limit_and_strict_parameters_return_json_without_file(self):
        for q in ('file_type=csv&skill=Ausente','file_type=doc','file_type=csv&file_type=pdf',
                  'file_type=csv&page=2','file_type=pdf&page_size=10','file_type=pdf&order=otro',
                  'file_type=csv&email=si','file_type=csv&skill=%0A','file_type=pdf&experience='+'a'*101,''):
            r=self.client.get(self.url+'?'+q)
            self.assertEqual(r.status_code,400,q)
            self.assertNotIn('Content-Disposition',r)
        with patch('candidate_dashboard.exports.MAX_EXPORT_ROWS',1):
            self.assertEqual(self.client.get(self.url+'?file_type=pdf').status_code,400)

    def test_roles_approval_foreign_offer_revocation_and_methods(self):
        for user in (self.user,self.other):
            self.authenticate(user);self.assertEqual(self.client.get(self.url+'?file_type=csv').status_code,403)
        self.authenticate(self.foreign_company)
        self.assertEqual(self.client.get(self.url+'?file_type=pdf').status_code,404)
        self.authenticate(self.company)
        for state in ('pending','rejected'):
            CompanyProfile.objects.filter(company=self.company).update(state=state)
            self.assertEqual(self.client.get(self.url+'?file_type=csv').status_code,403)
        CompanyProfile.objects.filter(company=self.company).update(state='approved')
        self.assertEqual(self.client.post(self.url,{},format='json').status_code,405)
        self.client.post('/api/logout/',{},format='json')
        self.assertEqual(self.client.get(self.url+'?file_type=pdf').status_code,401)

    def test_inactive_offers_download_headers_private_and_error_headers(self):
        for state in ('published','closed','archived','draft'):
            self.offer.status=state;self.offer.save(update_fields=['status'])
            for ext,mime in [('csv','text/csv'),('pdf','application/pdf')]:
                r=self.client.get(self.url+'?file_type='+ext)
                self.assertEqual(r.status_code,200)
                self.assertEqual(r['Content-Type'].split(';')[0],mime)
                self.assertEqual(r['Content-Disposition'],f'attachment; filename="postulantes-oferta-{self.offer.pk}.{ext}"')
                self.assertEqual(r['X-Export-Count'],'2')
                self.assertEqual(r['X-Export-Scope'],'all_filtered_applicants')
                self.assertEqual(r['Cache-Control'],'private, no-store')
                self.assertEqual(r['X-Content-Type-Options'],'nosniff')
                self.assertEqual(r['Access-Control-Expose-Headers'],'Content-Disposition, X-Export-Count, X-Export-Scope')
        self.client.credentials();r=self.client.get(self.url+'?file_type=csv')
        self.assertEqual(r['Cache-Control'],'private, no-store')
        self.assertIn('Authorization',r['Vary'])

    def test_projection_never_fetches_documents_profiles_or_contact_data(self):
        with CaptureQueriesContext(connection) as queries:
            self.assertEqual(self.client.get(self.url+'?file_type=csv').status_code,200)
        sql='\n'.join(x['sql'] for x in queries if 'candidate_dashboard_application' in x['sql'])
        for field in ('cv_document','cv_sha256','password','professional_summary','candidateprofile'):
            self.assertNotIn(field,sql)
        self.assertIn('LIMIT 5001',sql)
