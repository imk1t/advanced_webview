import 'dart:convert';
import 'dart:typed_data';

import 'package:advanced_webview/advanced_webview.dart';
import 'package:advanced_webview/src/platform/event_dispatcher.dart';
import 'package:advanced_webview/src/platform/messages.g.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_host_api.dart';

// A self-signed P-256 certificate (C=JP, O=Example Inc, CN=example.test,
// serial 12345) valid from 2026-11-17 to 2036-11-14.
const _certificate =
    'MIIBtzCCAV2gAwIBAgICMDkwCgYIKoZIzj0EAwIwOjELMAkGA1UEBhMCSlAxFDASBgNVBAoMC0V4YW1wbGUgSW5jMRUwEwYDVQQDDAxleGFtcGxlLnRlc3QwHhcNMjYxMTE3MTYyMTQxWhcNMzYxMTE0MTYyMTQxWjA6MQswCQYDVQQGEwJKUDEUMBIGA1UECgwLRXhhbXBsZSBJbmMxFTATBgNVBAMMDGV4YW1wbGUudGVzdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABCAYq4WX8WLBBWAqO6/qXowFM489Wbf0RsVXzg2qvRjLii1DYcfdtofaHocrClJzRwXbwSMkAQ59ioB6nY24bOCjUzBRMB0GA1UdDgQWBBSpuQCVUFRngf1ijkFS1bN9sjN6djAfBgNVHSMEGDAWgBSpuQCVUFRngf1ijkFS1bN9sjN6djAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIBKNeSQv+Gq+FyZ+rFj/c3uJbsFvPHkDC6/NCrs3nConAiEAtFlBOqNHWgb7eR4WASwoNnUyrsxgrfspR7MvYQ8G7go=';
const _sha256 =
    'd57e88f65cfee660bf2d6f2a5ee89978fe5579fa54ecbe0d0bc0e2f3f598aff5';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final der = base64Decode(_certificate);

  group('WebViewCertificate.fromDer', () {
    test('reads subject, issuer and validity', () {
      final certificate = WebViewCertificate.fromDer(der, sha256: _sha256);

      expect(certificate.subject, 'C=JP, O=Example Inc, CN=example.test');
      expect(certificate.issuer, 'C=JP, O=Example Inc, CN=example.test');
      expect(certificate.notBefore, DateTime.utc(2026, 11, 17, 16, 21, 41));
      expect(certificate.notAfter, DateTime.utc(2036, 11, 14, 16, 21, 41));
      expect(certificate.sha256, _sha256);
      expect(certificate.der, der);
    });

    test('isValidAt compares with the validity period', () {
      final certificate = WebViewCertificate.fromDer(der, sha256: _sha256);

      expect(certificate.isValidAt(DateTime.utc(2030)), isTrue);
      expect(certificate.isValidAt(DateTime.utc(2026)), isFalse);
      expect(certificate.isValidAt(DateTime.utc(2040)), isFalse);
    });

    test('rejects data that is not a certificate', () {
      expect(
        () => WebViewCertificate.fromDer(Uint8List(0), sha256: ''),
        throwsFormatException,
      );
      expect(
        () => WebViewCertificate.fromDer(
          Uint8List.fromList([0x30, 0x03, 0x01]),
          sha256: '',
        ),
        throwsFormatException,
      );
      expect(
        () => WebViewCertificate.fromDer(
          Uint8List.fromList(der.sublist(0, 40)),
          sha256: '',
        ),
        throwsFormatException,
      );
    });
  });

  group('AdvancedWebViewController.getCertificate', () {
    test('returns the parsed certificate', () async {
      final hostApi = FakeHostApi();
      hostApi.certificate = CertificateMessage(der: der, sha256: _sha256);
      final controller = AdvancedWebViewController(
        hostApi: hostApi,
        dispatcher: WebViewEventDispatcher(),
      );
      addTearDown(controller.dispose);

      final certificate = await controller.getCertificate();

      expect(certificate?.subject, contains('CN=example.test'));
      expect(certificate?.sha256, _sha256);
    });

    test('returns null when the page has no certificate', () async {
      final controller = AdvancedWebViewController(
        hostApi: FakeHostApi(),
        dispatcher: WebViewEventDispatcher(),
      );
      addTearDown(controller.dispose);

      expect(await controller.getCertificate(), isNull);
    });
  });
}
