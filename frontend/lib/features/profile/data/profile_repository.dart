import 'dart:typed_data';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/profile/domain/profile.dart';
import 'package:worknet/features/profile/data/profile_model.dart';

class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this.api);
  final WorkNetApi api;
  Future<CandidateProfile> _call(
    String token,
    String path, {
    String? method,
    Map<String, dynamic>? data,
  }) async => ProfileModel.parse(
    await api.request(
      'profile/candidate/$path',
      token: token,
      method: method,
      data: data,
    ),
  );
  @override
  Future<CandidateProfile> load(String token) => _call(token, '');
  @override
  Future<CandidateProfile> summary(
    String token,
    String text, {
    required bool create,
  }) => _call(
    token,
    '',
    method: create ? 'POST' : 'PATCH',
    data: {'professional_summary': text.trim()},
  );
  @override
  Future<CandidateProfile> saveRecord(
    String token,
    String section,
    Map<String, dynamic> fields, {
    String? id,
  }) => _call(
    token,
    '$section/${id == null ? '' : '$id/'}',
    method: id == null ? 'POST' : 'PATCH',
    data: fields,
  );
  @override
  Future<CandidateProfile> deleteRecord(
    String token,
    String section,
    String id,
  ) => _call(token, '$section/$id/', method: 'DELETE');
  @override
  Future<CandidateProfile> clear(String token) =>
      _call(token, '', method: 'DELETE');
  @override
  Future<CandidateProfile> upload(
    String token,
    Uint8List bytes,
    String filename,
  ) async => ProfileModel.parse(
    await api.uploadProfilePhoto(bytes, filename, token: token),
  );
  @override
  Future<CandidateProfile> removePhoto(String token) =>
      _call(token, 'photo/', method: 'DELETE');
  @override
  Future<Uint8List> photo(String token) => api.profilePhoto(token: token);
}
