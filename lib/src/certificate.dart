import 'dart:convert';
import 'dart:typed_data';

/// The TLS certificate a server presented for the current page.
///
/// [subject] and [issuer] are read from the DER encoding on both platforms, so
/// they look the same everywhere: `CN=example.com, O=Example Inc, C=US`.
class WebViewCertificate {
  const WebViewCertificate({
    required this.subject,
    required this.issuer,
    required this.notBefore,
    required this.notAfter,
    required this.sha256,
    required this.der,
  });

  /// Reads a DER encoded X.509 certificate. Throws a [FormatException] when
  /// [der] is not one.
  factory WebViewCertificate.fromDer(Uint8List der, {required String sha256}) {
    try {
      final certificate = _Der(der).read(0x30);
      final tbs = certificate.read(0x30);
      if (tbs.peek == 0xA0) tbs.read(0xA0); // version
      tbs.read(0x02); // serial number
      tbs.read(0x30); // signature algorithm
      final issuer = _name(tbs.read(0x30));
      final validity = tbs.read(0x30);
      final notBefore = _time(validity);
      final notAfter = _time(validity);
      final subject = _name(tbs.read(0x30));
      return WebViewCertificate(
        subject: subject,
        issuer: issuer,
        notBefore: notBefore,
        notAfter: notAfter,
        sha256: sha256,
        der: der,
      );
    } on RangeError {
      throw const FormatException('Not a valid X.509 certificate');
    }
  }

  /// Who the certificate was issued to, for example `CN=example.com`.
  final String subject;

  /// Who issued the certificate.
  final String issuer;

  /// Start of the validity period, in UTC.
  final DateTime notBefore;

  /// End of the validity period, in UTC.
  final DateTime notAfter;

  /// SHA-256 fingerprint of [der] as lower-case hex, without separators.
  final String sha256;

  /// The certificate, DER encoded.
  final Uint8List der;

  /// Whether the validity period includes [now] (the current time by default).
  bool isValidAt([DateTime? now]) {
    final time = (now ?? DateTime.now()).toUtc();
    return !time.isBefore(notBefore) && !time.isAfter(notAfter);
  }

  @override
  String toString() =>
      'WebViewCertificate($subject, issuer: $issuer, $notBefore - $notAfter)';

  static const _names = {
    '2.5.4.3': 'CN',
    '2.5.4.6': 'C',
    '2.5.4.7': 'L',
    '2.5.4.8': 'ST',
    '2.5.4.10': 'O',
    '2.5.4.11': 'OU',
    '1.2.840.113549.1.9.1': 'E',
  };

  static String _name(_Der name) {
    final parts = <String>[];
    while (!name.isDone) {
      final set = name.read(0x31);
      while (!set.isDone) {
        final pair = set.read(0x30);
        final oid = _oid(pair.read(0x06).bytes);
        final value = pair.readAny();
        parts.add('${_names[oid] ?? oid}=${_string(value)}');
      }
    }
    return parts.join(', ');
  }

  static String _oid(Uint8List bytes) {
    final parts = <int>[];
    var value = 0;
    for (final byte in bytes) {
      value = (value << 7) | (byte & 0x7F);
      if (byte & 0x80 == 0) {
        parts.add(value);
        value = 0;
      }
    }
    if (parts.isEmpty) return '';
    final first = parts.first;
    final head = first < 80 ? [first ~/ 40, first % 40] : [2, first - 80];
    return [...head, ...parts.skip(1)].join('.');
  }

  static String _string(({int tag, Uint8List bytes}) value) {
    if (value.tag == 0x1E) {
      // BMPString: UTF-16 big endian.
      final units = <int>[
        for (var i = 0; i + 1 < value.bytes.length; i += 2)
          (value.bytes[i] << 8) | value.bytes[i + 1],
      ];
      return String.fromCharCodes(units);
    }
    return utf8.decode(value.bytes, allowMalformed: true);
  }

  static DateTime _time(_Der validity) {
    final value = validity.readAny();
    final text = ascii.decode(value.bytes);
    // UTCTime (0x17) is YYMMDDHHMMSSZ, GeneralizedTime (0x18) YYYYMMDDHHMMSSZ.
    final long = value.tag == 0x18;
    var offset = 0;
    int next(int length) {
      final part = int.parse(text.substring(offset, offset + length));
      offset += length;
      return part;
    }

    var year = next(long ? 4 : 2);
    if (!long) year += year < 50 ? 2000 : 1900;
    return DateTime.utc(year, next(2), next(2), next(2), next(2), next(2));
  }
}

/// A cursor over DER encoded data.
class _Der {
  _Der(this._data);

  final Uint8List _data;
  int _offset = 0;

  bool get isDone => _offset >= _data.length;

  int get peek => _data[_offset];

  /// Reads one element with [tag] and returns a reader over its content, which
  /// is also its raw [bytes].
  _Der read(int tag) {
    final element = readAny();
    if (element.tag != tag) {
      throw const FormatException('Not a valid X.509 certificate');
    }
    return _Der(element.bytes);
  }

  Uint8List get bytes => _data;

  ({int tag, Uint8List bytes}) readAny() {
    final tag = _data[_offset++];
    var length = _data[_offset++];
    if (length & 0x80 != 0) {
      final count = length & 0x7F;
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _data[_offset++];
      }
    }
    final content = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return (tag: tag, bytes: content);
  }
}
