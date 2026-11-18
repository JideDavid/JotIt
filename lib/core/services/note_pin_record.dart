/// Older installations store the encoded hash directly. Recovery metadata and
/// the hash share one Hive value so a reset commits with one durable write.
String notePinHash(dynamic value) => value is String
    ? value
    : value is Map && value['hash'] is String
    ? value['hash'] as String
    : '';
