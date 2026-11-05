class SlipOcrResult {
  const SlipOcrResult({
    this.amount,
    this.date,
    this.transactionNumber,
  });

  final double? amount;
  final DateTime? date;
  final String? transactionNumber;
}

class SlipOcrParser {
  static const _amountPattern =
      r'(?<!\d)(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?(?!\d)';
  static final _amountCue = RegExp(
      r'amount|total|transfer|ยอดเงิน|จำนวนเงิน|ยอดโอน|จำนวน',
      caseSensitive: false);
  static final _bahtCurrencyCue = RegExp(
    r'\bTHB\b|\bbaht\b|฿|บาท',
    caseSensitive: false,
  );
  static final _nonAmountCue = RegExp(
    r'\bbalance\b|\bfee\b|\breference\b|\bref\b|ยอดคงเหลือ|ค่าธรรมเนียม|เลขอ้างอิง',
    caseSensitive: false,
  );
  static final _transactionNumberCue = RegExp(
    r'\b(?:transaction|trans(?:action)?\s*(?:id|no|number)|reference|ref)\b|เลขที่รายการ|เลขรายการ|เลขอ้างอิง|รหัสอ้างอิง|หมายเลขรายการ',
    caseSensitive: false,
  );
  static final _transactionNumberValue = RegExp(
    r'([A-Z0-9][A-Z0-9/-]{5,})',
    caseSensitive: false,
  );
  static final _datePattern = RegExp(
    r'(?<!\d)(\d{1,4})[./-](\d{1,2})[./-](\d{2,4})(?!\d)',
  );
  static final _textDatePattern = RegExp(
    r'(?<!\d)(\d{1,2})\s+([A-Za-zก-๙.]+)\s+(\d{2,4})(?!\d)',
    caseSensitive: false,
  );
  static final _monthFirstDatePattern = RegExp(
    r'\b([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{2,4})\b',
    caseSensitive: false,
  );
  static final _transactionDateCue = RegExp(
    r'transaction\s+date|date\s+of\s+transaction|วันที่ทำรายการ|วันเวลาทำรายการ|วันทำรายการ',
    caseSensitive: false,
  );
  static final _dateCue = RegExp(
    r'\bdate\b|วันที่|วันเวลา',
    caseSensitive: false,
  );
  static final _nonTransactionDateCue = RegExp(
    r'\b(?:expiry|expires|expiration|valid\s+until|due\s+date|birthday)\b|วันหมดอายุ|วันครบกำหนด|วันเกิด',
    caseSensitive: false,
  );
  static const _monthNumbers = <String, int>{
    'jan': 1,
    'january': 1,
    'มค': 1,
    'มกราคม': 1,
    'feb': 2,
    'february': 2,
    'กพ': 2,
    'กุมภาพันธ์': 2,
    'mar': 3,
    'march': 3,
    'มีค': 3,
    'มีนาคม': 3,
    'apr': 4,
    'april': 4,
    'เมย': 4,
    'เมษายน': 4,
    'may': 5,
    'พค': 5,
    'พฤษภาคม': 5,
    'jun': 6,
    'june': 6,
    'มิย': 6,
    'มิถุนายน': 6,
    'jul': 7,
    'july': 7,
    'กค': 7,
    'กรกฎาคม': 7,
    'aug': 8,
    'august': 8,
    'สค': 8,
    'สิงหาคม': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'กย': 9,
    'กันยายน': 9,
    'oct': 10,
    'october': 10,
    'ตค': 10,
    'ตุลาคม': 10,
    'nov': 11,
    'november': 11,
    'พย': 11,
    'พฤศจิกายน': 11,
    'dec': 12,
    'december': 12,
    'ธค': 12,
    'ธันวาคม': 12,
  };

  static SlipOcrResult parse(String text) {
    final normalizedText = _normalizeDigits(text);
    final lines = normalizedText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return SlipOcrResult(
      amount: _findAmount(lines),
      date: _findDate(lines),
      transactionNumber: _findTransactionNumber(lines),
    );
  }

  static String _normalizeDigits(String text) {
    const thaiDigits = '๐๑๒๓๔๕๖๗๘๙';
    return text.replaceAllMapped(RegExp('[๐-๙]'), (match) {
      final index = thaiDigits.indexOf(match.group(0)!);
      return index < 0 ? match.group(0)! : '$index';
    });
  }

  static double? _findAmount(List<String> lines) {
    var bestScore = -1;
    double? bestAmount;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final hasCue = _amountCue.hasMatch(line);
      if (_datePattern.hasMatch(line) ||
          RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(line) ||
          _nonAmountCue.hasMatch(line)) {
        continue;
      }

      final candidates = RegExp(_amountPattern)
          .allMatches(line)
          .map((match) => (value: match.group(0)!, context: line))
          .toList();
      if (candidates.isEmpty &&
          hasCue &&
          index + 1 < lines.length &&
          !_datePattern.hasMatch(lines[index + 1])) {
        candidates.addAll(
          RegExp(_amountPattern).allMatches(lines[index + 1]).map((match) => (
                value: match.group(0)!,
                context: '${lines[index]} ${lines[index + 1]}',
              )),
        );
      }

      for (final candidate in candidates) {
        final value = double.tryParse(candidate.value.replaceAll(',', ''));
        if (value == null || value <= 0 || value > 1000000000) continue;

        final hasDecimals = candidate.value.contains('.');
        final isGrouped = candidate.value.contains(',');
        final hasBahtCurrency = _bahtCurrencyCue.hasMatch(candidate.context);
        if (!hasCue && !hasDecimals && !isGrouped && !hasBahtCurrency) {
          continue;
        }

        final score = (hasBahtCurrency ? 20 : 0) +
            (hasCue ? 10 : 0) +
            (hasDecimals ? 4 : 0) +
            (isGrouped ? 2 : 0);
        if (score > bestScore) {
          bestScore = score;
          bestAmount = value;
        }
      }
    }

    return bestAmount;
  }

  static DateTime? _findDate(List<String> lines) {
    final candidates = <({DateTime date, int score, int lineIndex})>[];
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final hasTransactionCue = _transactionDateCue.hasMatch(line);
      if (!hasTransactionCue && _nonTransactionDateCue.hasMatch(line)) {
        continue;
      }
      final score = hasTransactionCue ? 2 : (_dateCue.hasMatch(line) ? 1 : 0);

      final dates = _datesInLine(line);
      if (dates.isNotEmpty) {
        for (final date in dates) {
          candidates.add((date: date, score: score, lineIndex: lineIndex));
        }
        continue;
      }

      // Some slips place the date value on the line directly below its label.
      if (score == 0) continue;
      for (var nextIndex = lineIndex + 1;
          nextIndex < lines.length && nextIndex <= lineIndex + 2;
          nextIndex++) {
        if (_nonTransactionDateCue.hasMatch(lines[nextIndex])) break;
        final nextLineDates = _datesInLine(lines[nextIndex]);
        if (nextLineDates.isEmpty) continue;
        for (final date in nextLineDates) {
          candidates.add((
            date: date,
            score: score + (hasTransactionCue ? 2 : 0),
            lineIndex: lineIndex,
          ));
        }
        break;
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      return scoreOrder != 0 ? scoreOrder : a.lineIndex.compareTo(b.lineIndex);
    });
    return candidates.first.date;
  }

  static List<DateTime> _datesInLine(String line) {
    final dates = <DateTime>[];
    for (final match in _datePattern.allMatches(line)) {
      final first = int.parse(match.group(1)!);
      final second = int.parse(match.group(2)!);
      final third = int.parse(match.group(3)!);
      final isYearFirst = match.group(1)!.length == 4;
      final date = _makeDate(
        day: isYearFirst ? third : first,
        month: second,
        year: isYearFirst ? first : third,
      );
      if (date != null) dates.add(date);
    }

    for (final match in _textDatePattern.allMatches(line)) {
      final month =
          _monthNumbers[match.group(2)!.toLowerCase().replaceAll('.', '')];
      if (month == null) continue;
      final date = _makeDate(
        day: int.parse(match.group(1)!),
        month: month,
        year: int.parse(match.group(3)!),
      );
      if (date != null) dates.add(date);
    }

    for (final match in _monthFirstDatePattern.allMatches(line)) {
      final month = _monthNumbers[match.group(1)!.toLowerCase()];
      if (month == null) continue;
      final date = _makeDate(
        day: int.parse(match.group(2)!),
        month: month,
        year: int.parse(match.group(3)!),
      );
      if (date != null) dates.add(date);
    }
    return dates;
  }

  static DateTime? _makeDate({
    required int day,
    required int month,
    required int year,
  }) {
    if (year < 100) {
      year += year >= 50 ? 2500 - 543 : 2000;
    } else if (year >= 2400) {
      year -= 543;
    }

    if (year < 1 || month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String? _findTransactionNumber(List<String> lines) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (!_transactionNumberCue.hasMatch(line)) continue;

      final value = line.replaceFirst(_transactionNumberCue, '');
      final match = _transactionNumberValue.firstMatch(value) ??
          (index + 1 < lines.length
              ? _transactionNumberValue.firstMatch(lines[index + 1])
              : null);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
