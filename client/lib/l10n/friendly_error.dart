import 'package:dio/dio.dart';

import '../services/auth_service.dart' as auth;
import '../services/purchase_api.dart' as purchase;
import 'l10n.dart';

/// One sentence a person can act on, for any error a screen may get.
///
/// Screens used to print `error.toString()`, which for a failed request is a
/// paragraph about `DioException` and `RequestOptions`. This keeps that out of
/// the UI: what went wrong in words, and what to do.
String friendlyError(AppLocalizations l10n, Object? error) {
  // Already words (a screen worded it itself): shown as it is.
  if (error is String) return error;
  if (error is LocalizedError) return error.localized(l10n);
  if (error is auth.AuthRequired || error is purchase.AuthRequired) {
    return l10n.errSession;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return l10n.errNetwork;
      case DioExceptionType.cancel:
        return l10n.commonError;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      case DioExceptionType.badResponse:
        break;
    }
    final status = error.response?.statusCode;
    if (status == null) {
      // No response and no type we know: almost always the network.
      return error.error is Exception ? l10n.errNetwork : l10n.commonError;
    }
    if (status == 401) return l10n.errSession;
    if (status == 403) return l10n.errForbidden;
    if (status == 404) return l10n.errNotFound;
    if (status >= 500) return l10n.errServer;
    return l10n.commonError;
  }
  return l10n.commonError;
}
