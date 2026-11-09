import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/applicants/data/applicant_export_repository.dart';
import 'package:worknet/features/applicants/domain/applicant.dart';
import 'package:worknet/features/applicants/domain/applicant_export.dart';
import 'package:worknet/features/applicants/presentation/applicants_page.dart';
import 'applicants_test.dart' show ApplicantsFake;
import 'publish_offer_test.dart' show companySession;

const csvText =
    '\uFEFF"Oferta ID","Oferta","Postulación ID","Nombre","Fecha UTC","Estado","CV enviado"\r\n"3","QA","1","Nombre QA","2026-11-09 UTC","Enviada","No registrado"\r\n';
ApplicantExportFile file(ApplicantExportType type) => ApplicantExportFile(
  bytes: Uint8List.fromList(
    utf8.encode(type == ApplicantExportType.csv ? csvText : '%PDF-1.7 QA'),
  ),
  name: 'postulantes-oferta-3.${type.name}',
  type: type,
  count: 11,
);
Map<String, String> headers(ApplicantExportType type) => {
  'content-type': type == ApplicantExportType.csv
      ? 'text/csv; charset=utf-8'
      : 'application/pdf',
  'content-disposition':
      'attachment; filename="postulantes-oferta-3.${type.name}"',
  'x-export-count': '11',
  'x-export-scope': 'all_filtered_applicants',
};

class ExportFake implements ApplicantExportRepository {
  ApplicantQuery? query;
  int calls = 0;
  ApiFailure? failure;
  Completer<ApplicantExportFile>? pending;
  @override
  Future<ApplicantExportFile> export(
    String token,
    int offerId,
    ApplicantQuery q,
    ApplicantExportType type,
  ) async {
    calls++;
    query = q;
    if (failure != null) throw failure!;
    return pending?.future ?? file(type);
  }
}

class DownloadFake implements ApplicantExportDownload {
  int calls = 0;
  bool cancelled = false, failed = false;
  @override
  Future<bool> save(ApplicantExportFile f) async {
    calls++;
    if (failed) throw Exception('QA');
    return !cancelled;
  }
}

void main() {
  test(
    'transport exports applied filters and stable order, excludes page and private query',
    () async {
      for (final type in ApplicantExportType.values) {
        final api = WorkNetApi(
          client: MockClient((r) async {
            expect(r.url.path, '/api/company/offers/3/applications/export/');
            expect(r.url.queryParameters, {
              'file_type': type.name,
              'order': 'name_desc',
              'experience': 'Ingeniería',
              'education': 'Técnica',
              'skill': 'C++ & QA',
            });
            expect(r.headers['Authorization'], 'Token private-test');
            return http.Response.bytes(
              file(type).bytes,
              200,
              headers: headers(type),
            );
          }),
        );
        final value = await HttpApplicantExportRepository(api).export(
          'private-test',
          3,
          const ApplicantQuery(
            page: 2,
            order: 'name_desc',
            experience: 'Ingeniería',
            education: 'Técnica',
            skill: 'C++ & QA',
          ),
          type,
        );
        expect(value.name, 'postulantes-oferta-3.${type.name}');
        expect(value.count, 11);
      }
    },
  );
  test(
    'binary contract rejects wrong names, MIME, scope, counts, signatures and corrupt CSV',
    () async {
      final variants = <http.Response>[
        for (final entry in {
          'content-type': 'text/html',
          'content-disposition': 'attachment; filename="../../secret.csv"',
          'x-export-count': '0',
          'x-export-scope': 'all_candidates',
        }.entries)
          http.Response.bytes(
            file(ApplicantExportType.csv).bytes,
            200,
            headers: {
              ...headers(ApplicantExportType.csv),
              entry.key: entry.value,
            },
          ),
        http.Response.bytes(
          utf8.encode('wrong header'),
          200,
          headers: headers(ApplicantExportType.csv),
        ),
        http.Response.bytes(
          [255, 254, 0, 0, 0],
          200,
          headers: headers(ApplicantExportType.csv),
        ),
      ];
      for (final response in variants) {
        final repo = HttpApplicantExportRepository(
          WorkNetApi(client: MockClient((_) async => response)),
        );
        await expectLater(
          repo.export('qa', 3, const ApplicantQuery(), ApplicantExportType.csv),
          throwsA(isA<ApiFailure>()),
        );
      }
      final repo = HttpApplicantExportRepository(
        WorkNetApi(
          client: MockClient(
            (_) async => http.Response(
              'json!',
              200,
              headers: headers(ApplicantExportType.pdf),
            ),
          ),
        ),
      );
      await expectLater(
        repo.export('qa', 3, const ApplicantQuery(), ApplicantExportType.pdf),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test(
    'transport preserves no data, foreign offer, revoked session and service failures',
    () async {
      for (final code in [400, 401, 403, 404, 503]) {
        final repo = HttpApplicantExportRepository(
          WorkNetApi(
            client: MockClient(
              (_) async => http.Response(
                '{"detail":"Sin permiso o datos QA"}',
                code,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        );
        await expectLater(
          repo.export('qa', 3, const ApplicantQuery(), ApplicantExportType.csv),
          throwsA(isA<ApiFailure>().having((e) => e.status, 'status', code)),
        );
      }
    },
  );
  testWidgets(
    'both controls export all matches using applied page2 query and preserve list',
    (t) async {
      final session = await companySession(),
          repo = ExportFake(),
          download = DownloadFake();
      await t.pumpWidget(
        MaterialApp(
          home: ApplicantsPage(
            session: session,
            repository: ApplicantsFake(),
            offerId: 3,
            query: const ApplicantQuery(
              page: 2,
              skill: 'Python',
              order: 'name',
            ),
            exports: repo,
            download: download,
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final label in ['Exportar CSV', 'Exportar PDF']) {
        await t.ensureVisible(find.text(label));
        await t.tap(find.text(label));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('export_result')), findsOneWidget);
      }
      expect(repo.query!.page, 2);
      expect(repo.query!.skill, 'Python');
      expect(repo.query!.order, 'name');
      expect(download.calls, 2);
      expect(find.text('11 postulantes encontrados'), findsOneWidget);
    },
  );
  testWidgets('empty matches disable CSV PDF and create no export request', (
    t,
  ) async {
    final session = await companySession(), repo = ExportFake();
    await t.pumpWidget(
      MaterialApp(
        home: ApplicantsPage(
          session: session,
          repository: ApplicantsFake()..count = 0,
          offerId: 3,
          query: const ApplicantQuery(),
          exports: repo,
          download: DownloadFake(),
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final label in ['Exportar CSV', 'Exportar PDF']) {
      final button = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, label),
      );
      expect(button.onPressed, isNull);
    }
    expect(repo.calls, 0);
  });
  testWidgets(
    'failed save and cancellation permit retry without losing applicants',
    (t) async {
      final session = await companySession(),
          repo = ExportFake(),
          download = DownloadFake()..failed = true;
      await t.pumpWidget(
        MaterialApp(
          home: ApplicantsPage(
            session: session,
            repository: ApplicantsFake(),
            offerId: 3,
            query: const ApplicantQuery(),
            exports: repo,
            download: download,
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> press() async {
        await t.ensureVisible(find.text('Exportar CSV'));
        await t.tap(find.text('Exportar CSV'));
        await t.pumpAndSettle();
      }

      await press();
      expect(
        find.text('No pudimos guardar el archivo. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      download.failed = false;
      download.cancelled = true;
      await press();
      expect(
        find.text('Descarga cancelada. Puedes intentarlo de nuevo.'),
        findsOneWidget,
      );
      download.cancelled = false;
      await press();
      expect(download.calls, 3);
      expect(find.text('11 postulantes encontrados'), findsOneWidget);
    },
  );
  testWidgets(
    'pending export cannot duplicate or release a file after session expires',
    (t) async {
      final session = await companySession(),
          repo = ExportFake()..pending = Completer<ApplicantExportFile>(),
          download = DownloadFake();
      await t.pumpWidget(
        MaterialApp(
          home: ApplicantsPage(
            session: session,
            repository: ApplicantsFake(),
            offerId: 3,
            query: const ApplicantQuery(),
            exports: repo,
            download: download,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Exportar CSV'));
      await t.tap(find.text('Exportar CSV'));
      await t.pump();
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Exportar CSV'),
            )
            .onPressed,
        isNull,
      );
      await session.expire();
      await t.pump();
      repo.pending!.complete(file(ApplicantExportType.csv));
      await t.pumpAndSettle();
      expect(repo.calls, 1);
      expect(download.calls, 0);
      expect(find.text('11 postulantes encontrados'), findsNothing);
    },
  );
  testWidgets('401 export expires session and suppresses save', (t) async {
    final session = await companySession(),
        repo = ExportFake()
          ..failure = const ApiFailure('Sesión revocada', status: 401),
        download = DownloadFake();
    await t.pumpWidget(
      MaterialApp(
        home: ApplicantsPage(
          session: session,
          repository: ApplicantsFake(),
          offerId: 3,
          query: const ApplicantQuery(),
          exports: repo,
          download: download,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Exportar CSV'));
    await t.tap(find.text('Exportar CSV'));
    await t.pumpAndSettle();
    expect(session.session, isNull);
    expect(download.calls, 0);
  });
}
