import 'dart:math';

class IdGenerator {
  static final Random _random = Random();

  static String generateId([String prefix = '']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = _random.nextInt(9000) + 1000;
    if (prefix.isNotEmpty) {
      return '${prefix}_${timestamp}_$randomSuffix';
    }
    return '${timestamp}_$randomSuffix';
  }

  static String generateInvoiceNumber(String prefix, int sequence) {
    final year = DateTime.now().year;
    final seqPadded = sequence.toString().padLeft(4, '0');
    return '$prefix-$year-$seqPadded';
  }
}
