class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.fields = const {}});
  final String message;
  final int? status;
  final Map<String, String> fields;
}
