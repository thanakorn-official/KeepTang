class SlipOcrResult {
  const SlipOcrResult({
    this.title,
    this.amount,
    this.date,
    this.hasTime = false,
    this.transactionNumber,
    this.looksLikeTransferSlip = false,
    this.hasSlipHint = false,
    this.referenceConfidence = 0,
    this.timestampConfidence = 0,
  });

  final String? title;
  final double? amount;
  final DateTime? date;
  final bool hasTime;
  final String? transactionNumber;
  final bool looksLikeTransferSlip;
  final bool hasSlipHint;
  final int referenceConfidence;
  final int timestampConfidence;

  String? get referenceNumber => transactionNumber;
  bool get hasTruncatedReference => transactionNumber?.endsWith('…') ?? false;
}

class SlipOcrParser {
  static SlipOcrResult merge(SlipOcrResult primary, SlipOcrResult fallback) {
    // A complete timestamp takes priority. Keep the date and time together.
    final dateSource = fallback.date != null &&
            (primary.date == null ||
                (fallback.hasTime && !primary.hasTime) ||
                (fallback.hasTime == primary.hasTime &&
                    fallback.timestampConfidence > primary.timestampConfidence))
        ? fallback
        : primary;
    final primaryNumber = primary.referenceNumber;
    final fallbackNumber = fallback.referenceNumber;
    final completesVisiblePrefix = primary.hasTruncatedReference &&
        fallbackNumber != null &&
        !fallback.hasTruncatedReference &&
        fallbackNumber.toLowerCase().startsWith(primaryNumber!
            .substring(0, primaryNumber.length - 1)
            .toLowerCase());
    final referenceSource = fallbackNumber != null &&
            (primaryNumber == null ||
                fallback.referenceConfidence > primary.referenceConfidence ||
                (fallback.referenceConfidence == primary.referenceConfidence &&
                    completesVisiblePrefix))
        ? fallback
        : primary;

    return SlipOcrResult(
      title: primary.title ?? fallback.title,
      amount: primary.amount ?? fallback.amount,
      date: dateSource.date,
      hasTime: dateSource.hasTime,
      timestampConfidence: dateSource.timestampConfidence,
      transactionNumber: referenceSource.referenceNumber,
      referenceConfidence: referenceSource.referenceConfidence,
      looksLikeTransferSlip:
          primary.looksLikeTransferSlip || fallback.looksLikeTransferSlip,
      hasSlipHint: primary.hasSlipHint || fallback.hasSlipHint,
    );
  }

  static final _amountPattern =
      RegExp(r'(?<!\d)(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?(?!\d)');
  static const _clockPeriod =
      r'(?:[ap]\.?\s*m\.?(?![A-Za-z])|นาฬิกา|น\s*\.?(?![\u0E00-\u0E7F]))';
  static const _clockQualifier = '(?:\\s*($_clockPeriod))?';
  static final _timePattern = RegExp(
    r'(?<![+\d:])(\d{1,2})\s*:\s*(\d{2})(?:\s*:\s*(\d{2}))?'
    '$_clockQualifier'
    r'(?![\d:])',
    caseSensitive: false,
  );
  static final _dottedTimePattern = RegExp(
    r'(?<![\d.,])(\d{1,2})\s*\.\s*(\d{2})(?:\s*\.\s*(\d{2}))?'
    '$_clockQualifier'
    r'(?![\d.])',
    caseSensitive: false,
  );
  static final _amountCue = RegExp(
      r'\b(?:amount|total)\b|\btransfer(?=\s*(?:[:=]|\d))|ยอดเงิน|จำนวนเงิน|ยอดโอน|ยอดรวม|จำนวน',
      caseSensitive: false);
  static final _paidAmountCue = RegExp(r'จำนวน\s*เงิน\s*ที่\s*ชำระ');
  static final _bahtCurrencyCue = RegExp(
    r'\bTHB\b|\bbaht\b|฿|บาท',
    caseSensitive: false,
  );
  static final _nonAmountCue = RegExp(
    r'\bbalance\b|\bfee\b|\breference\b|\bref\b|ยอดคงเหลือ|ค่าธรรมเนียม|เลขอ้างอิง',
    caseSensitive: false,
  );
  // OCR may insert spaces even inside a Thai word or split off a vowel mark.
  static const _thaiReferencePrefix =
      r'(?:หมาย\s*เลข|เลข(?:\s*ท\s*ี\s*่?)?|ร\s*ห\s*ั?\s*ส)\s*';
  static const _thaiReferenceWord = r'อ\s*้?\s*า\s*ง\s*อ\s*ิ?\s*ง';
  static const _thaiTransactionScope =
      r'(?:ของ\s*)?(?:(?:การ\s*)?(?:ทำ\s*)?รายการ(?:\s*โอน(?:\s*เงิน)?)?'
      r'|(?:การ\s*)?โอน(?:\s*เงิน)?|(?:การ\s*ทำ\s*)?ธุรกรรม)';
  static const _englishReferenceWord = r'ref(?:\s*er\s*ence)?';
  static const _englishIdWord = r'(?:number|n\s*o|id|code)';
  static const _englishTransactionWord =
      r'(?:trans\s*ac\s*tion|trans\s*fer|trans|txn|trn)';
  static final _specificReferenceCue = RegExp(
    '\\b$_englishTransactionWord\\s*\\.?\\s*'
    '(?:$_englishReferenceWord(?:\\s*\\.?\\s*$_englishIdWord)?|$_englishIdWord)\\b'
    r'|\b(?:transaction|transfer)\b(?=\s*#)'
    r'|\btransaction\b(?=\s*:)'
    '|$_thaiReferencePrefix(?:$_thaiReferenceWord\\s*)?$_thaiTransactionScope',
    caseSensitive: false,
  );
  static final _transactionNumberCue = RegExp(
    '${_specificReferenceCue.pattern}|'
    '\\b$_englishReferenceWord\\b(?!\\s*[-_/])(?:\\s*\\.?\\s*$_englishIdWord\\b)?'
    r'|\bRRN\b(?!\s*[-_/])'
    '|$_thaiReferencePrefix$_thaiReferenceWord(?:\\s*ที่)?',
    caseSensitive: false,
  );
  static final _explicitReferenceCue = RegExp(
    '$_thaiReferencePrefix$_thaiReferenceWord|\\bRRN\\b',
    caseSensitive: false,
  );
  static final _truncatedReference = RegExp(r'\s*(?:\.{2,}|…+)\s*$');
  static final _referencePrefix = RegExp(r'^[\s.:：#=|()–—-]+');
  static final _referenceValuePrefix = RegExp(r'^[.:#=(| ]+');
  static final _numberedReference = RegExp(r'^\d{1,2}\s*[:：=#]');
  static final _referenceToken =
      RegExp(r'^[A-Z0-9_/-]+$', caseSensitive: false);
  static final _referenceSeparator = RegExp(r'[_/-]');
  static final _referenceSpacing = RegExp(r'[\s\u200B\u2060\uFEFF]+');
  static final _nonTransactionIdCue = RegExp(
    r'^(?:account|acct|tax|invoice|order|customer|biller|merchant)(?=$|[\s.:#=])'
    r'|^(?:เลข\s*(?:ที่\s*)?บัญชี|บัญชี|ภาษี|เลขประจำตัว|(?:g\s*[-–]?\s*)?wallet\s*id|วอล\s*เล็?ท\s*ไอดี)',
    caseSensitive: false,
  );
  static final _referenceNeighborCue = RegExp(
    '${_nonTransactionIdCue.pattern}|'
    r'^(?:fee|date|time|amount|total|from|to)(?=$|[\s.:#=])'
    r'|^(?:จำนวนเงิน|ค่าธรรมเนียม|วันที่|เวลา|ยอดเงิน)',
    caseSensitive: false,
  );
  static final _referenceValueSuffix = RegExp(r'[,;)](?=\s|$)|[|•]');
  static final _accountOrTaxNumber = RegExp(
    r'^(?:\d{3}-\d-\d{5}-\d|\d-\d{4}-\d{5}-\d{2}-\d)$',
  );
  static final _commonAccountOrTaxLength = RegExp(r'^(?:\d{10}|\d{13})$');
  static final _maskedAccountNumber = RegExp(r'^[Xx0-9_/-]+$');
  static final _transactionNumberValue = RegExp(
    r'^[A-Z0-9][A-Z0-9_/-]{4,58}[A-Z0-9]$',
    caseSensitive: false,
  );
  static final _referenceDigit = RegExp(r'\d');
  static final _referenceLetters = RegExp(r'[A-Za-z]');
  static final _onlyReferenceDigits = RegExp(r'^\d+$');
  static final _longUnlabeledReference =
      RegExp(r'^[A-Z0-9][A-Z0-9-]{14,}[A-Z0-9]$');
  static final _transferSlipCue = RegExp(
    r'\b(?:(?:transfer|payment|transaction)\s+'
    r'(?:successful(?:ly)?|success|complete(?:d)?|confirmation)'
    r'|(?:successful|completed)\s+(?:transfer|payment)'
    r'|(?:bank\s+)?transfer\s+receipt)\b'
    r'|โอน\s*(?:เงิน\s*)?สำเร็จ|ชำระ\s*เงิน\s*สำเร็จ|(?:ทำ\s*)?รายการ\s*สำเร็จ'
    r'|สลิป\s*โอน\s*เงิน|หลักฐาน\s*การ\s*โอน',
    caseSensitive: false,
  );
  static final _bankCue = RegExp(
    r'\b(?:kbank|kasikorn(?:bank)?|scb|krung\s?thai|krung\s?sri|ttb|promptpay'
    r'|bangkok bank|government savings bank)\b'
    r'|ธนาคาร|พร้อม\s*เพย์|กสิกร\s*ไทย|ไทย\s*พาณิชย์|กรุง\s*ศรี|กรุง\s*ไทย',
    caseSensitive: false,
  );
  static final _walletSlipCue = RegExp(
    r'\b(?:true\s*money|paotang\s*pay|k\s*plus)\b|ทรู\s*มันนี่|เป๋า\s*ตัง',
    caseSensitive: false,
  );
  static final _transferPartiesCue = RegExp(
    r'\b(?:sender|recipient|beneficiary|payer|payee)\b'
    r'|ผู้\s*โอน|ผู้\s*รับ\s*(?:โอน|เงิน)|บัญชี\s*(?:ต้นทาง|ปลายทาง)',
    caseSensitive: false,
  );
  static final _descriptionLabel = RegExp(
    r'^(?:transaction (?:name|description)|payment for'
    r'|description|memo|notes?|remark|purpose)\b'
    r'|^(?:ชื่อ\s*รายการ|รายละเอียด(?:\s*(?:รายการ|การ\s*โอน))?'
    r'|วัตถุประสงค์|บันทึก(?:\s*ช่วย\s*จำ)?|หมาย\s*เหตุ)',
    caseSensitive: false,
  );
  static final _merchantLabel = RegExp(
    r"^(?:merchant(?:['’]s)?(?: name)?|shop name|biller(?: name)?)\b"
    r'|^(?:(?:ชื่อ\s*)?(?:ร้าน\s*ค้า|ผู้\s*ให้\s*บริการ))',
    caseSensitive: false,
  );
  static final _recipientLabel = RegExp(
    r"^(?:(?:recipient|beneficiary|payee)(?:['’]s)?(?: name)?"
    r'|transferred to|paid to|to)\b'
    r'|^(?:(?:ชื่อ\s*)?ผู้\s*รับ(?:\s*(?:โอน|เงิน))?|บัญชี\s*ปลายทาง'
    r'|โอน\s*ถึง|ไป\s*ยัง|ถึง)',
    caseSensitive: false,
  );
  static final _senderLabel = RegExp(
    r"^(?:(?:sender|payer)(?:['’]s)?(?: name)?|received from|from)\b"
    r'|^(?:(?:ชื่อ\s*)?ผู้\s*โอน|บัญชี\s*ต้นทาง|รับ\s*เงิน\s*จาก|โอน\s*จาก|จาก)',
    caseSensitive: false,
  );
  static final _incomingCue = RegExp(
    r'^(?:money received|(?:payment|transfer) received|received from)\b'
    r'|^(?:ได้รับ\s*เงิน|รับ\s*โอน\s*เงิน\s*สำเร็จ|รับ\s*เงิน\s*จาก)',
    caseSensitive: false,
  );
  static final _namedParty = RegExp(
    r'^(?:(?:mr|mrs|ms|miss)(?:\.\s*|\s+)'
    r'|(?:นาย|นางสาว|นาง|น\s*\.\s*ส\s*\.|คุณ|บริษัท|บจก\.|หจก\.)\s*)',
    caseSensitive: false,
  );
  static final _bankNameOnly = RegExp(
    r'^(?:(?:ธนาคาร\s*|ธ\.\s*)?(?:กสิกร\s*ไทย|ไทย\s*พาณิชย์|กรุงเทพ|กรุง\s*ไทย'
    r'|กรุง\s*ศรี(?:อยุธยา)?|ทหาร\s*ไทย\s*ธนชาต|ออมสิน)|พร้อม\s*เพย์|k\+|k plus|kbank'
    r'|kasikorn(?:\s?bank)?|scb(?: easy)?|siam commercial bank|krung\s?thai(?: bank)?'
    r'|krung\s?sri|ttb(?: touch)?|promptpay|bangkok bank|government savings bank)'
    r'(?:\s+pcl\.?)?$',
    caseSensitive: false,
  );
  static final _titleMetadata = RegExp(
    r'^(?:(?:amount|total|balance|fee|date|time|account(?:\s+(?:no|number))?'
    r'|tax id|id|payment method)\b\s*(?=[:：#=\d]|$)'
    r'|(?:scan (?:qr|to)|verify (?:this|the))\b'
    r'|(?:ยอดเงิน|จำนวนเงิน|ค่าธรรมเนียม|ยอดคงเหลือ|วันที่|เวลา|เลขบัญชี'
    r'|หมายเลขบัญชี|เลขประจำตัวผู้เสียภาษี|สแกนคิวอาร์|พร้อมเพย์(?=\s*[:：\d])))',
    caseSensitive: false,
  );
  static final _titleSeparators = RegExp(r'^[\s:：=|–—-]+');
  static final _titleNamePrefix = RegExp(
    r'^(?:name|account name|ชื่อ|ชื่อบัญชี)\s*[:：=]\s*',
    caseSensitive: false,
  );
  static final _titleWhitespace = RegExp(r'\s+');
  static final _maskedAccountEnd = RegExp(
    r'(?:^|\s+)(?=[xX*×•\d -]*[xX*×•][xX*×•\d -]*$)'
    r'[xX*×•\d][xX*×•\d -]{4,}$',
  );
  static final _titleLetters = RegExp(r'[A-Za-zก-ฮ]');
  static final _amountOnly = RegExp(
    r'^(?:฿|THB\s*)?[\d,.\s]+(?:บาท|THB|baht|฿)?$',
    caseSensitive: false,
  );
  static final _compactCode =
      RegExp(r'^(?=[A-Za-z0-9_/-]*\d{4})[A-Za-z0-9_/-]{8,}$');
  static final _placeholderTitle = RegExp(
    r'^(?:n/?a|none|null|transfer|payment|thb|baht|บาท|ไม่มี|ไม่ระบุ|โอนเงิน|ชำระเงิน)$',
    caseSensitive: false,
  );
  static final _titleTrailingField = RegExp(
    r'\s+(?:account(?:\s+(?:no|number))?|amount|fee|ref(?:erence)?|เลขบัญชี'
    r'|จำนวนเงิน|เลขอ้างอิง)\s*[:：=]',
    caseSensitive: false,
  );
  static const _yearEra =
      r'พ\s*\.?\s*ศ\s*\.?|ค\s*\.?\s*ศ\s*\.?|B\.?\s*E\.?|A\.?\s*D\.?|C\.?\s*E\.?';
  static const _namedDateGap = r'[\s,./-]*';
  static const _dayOrdinal = r'(?:st|nd|rd|th)?';
  static const _namedYear = r'(\d{4}|\d{2})(?!\d|\s*[:.]\s*\d)';
  static const _namedYearPrefix =
      "$_namedDateGap(?:ปี\\s*)?(?:($_yearEra)\\s*)?['’]?";
  static const _monthFirstYearPrefix =
      "[\\s,./-]+(?:ปี\\s*)?(?:($_yearEra)\\s*)?['’]?";
  static final _datePattern = RegExp(
    r'(?<![A-Za-z\d])(\d{1,4})\s*([./-])\s*(\d{1,2})\s*[./-]\s*'
    '(?:($_yearEra)\\s*)?'
    r'(\d{2,4})(?!\d)',
    caseSensitive: false,
  );
  static final _monthTokens = _monthNumbers.keys.map(_monthPattern).join('|');
  static final _englishMonthTokens = _monthNumbers.keys
      .where((month) => month.codeUnitAt(0) < 0x0E00)
      .map(_monthPattern)
      .join('|');
  static final _dayFirstDateHead = r'(?<![A-Za-z\d])(\d{1,2})'
      '$_dayOrdinal$_namedDateGap(?:เดือน\\s*)?($_monthTokens)';
  static final _monthFirstDateHead =
      '\\b($_englishMonthTokens)$_namedDateGap(\\d{1,2})(?!\\d)$_dayOrdinal';
  static final _textDatePattern = RegExp(
    '$_dayFirstDateHead$_namedYearPrefix$_namedYear',
    caseSensitive: false,
  );
  static final _monthFirstDatePattern = RegExp(
    '$_monthFirstDateHead$_monthFirstYearPrefix$_namedYear',
    caseSensitive: false,
  );
  static final _yearFirstNamedDatePattern = RegExp(
    r'(?<![A-Za-z\d])(\d{4})'
    '$_namedDateGap($_monthTokens)$_namedDateGap(\\d{1,2})$_dayOrdinal'
    r'(?!\d|\s*[:.]\s*\d)',
    caseSensitive: false,
  );
  static final _splitDateHead = RegExp(
    '(?:$_dayFirstDateHead|$_monthFirstDateHead)$_namedYearPrefix\$'
    r'|(?<![A-Za-z\d])\d{1,2}\s*[./-]\s*\d{1,2}\s*[./-]$',
    caseSensitive: false,
  );
  static final _splitDateYear = RegExp(
    '^$_namedYearPrefix$_namedYear',
    caseSensitive: false,
  );
  static final _transactionDateCue = RegExp(
    r'\b(?:transaction|transfer|payment)\s+(?:date|timestamp)\b'
    r'|\bdate\s+of\s+(?:transaction|transfer|payment)\b'
    r'|\b(?:paid|transferred)\s+on\b'
    r'|วัน\s*(?:ที่|เวลา)?\s*(?:ที่\s*)?(?:(?:ทำ\s*)?รายการ|(?:การ\s*)?โอน|ชำระ\s*เงิน)'
    r'|(?:ทำ\s*รายการ|โอน(?:\s*เงิน)?|ชำระ\s*เงิน)\s*เมื่อ',
    caseSensitive: false,
  );
  static final _dateCue = RegExp(
    r'\bdate\b|วัน\s*(?:ที่|เวลา)',
    caseSensitive: false,
  );
  static final _transactionClockCue = RegExp(
    r'\b(?:transaction|transfer|payment)\s+time\b'
    r'|\btime\s+of\s+(?:transaction|transfer|payment)\b'
    r'|เว\s*ลา\s*(?:(?:ทำ\s*)?รายการ|(?:การ\s*)?โอน|ชำระ\s*เงิน)',
    caseSensitive: false,
  );
  static final _clockCue = RegExp(
    r'\btime\b|เว\s*ลา|นาฬิกา',
    caseSensitive: false,
  );
  static final _nonTransactionDateCue = RegExp(
    r'\b(?:expiry|expires|expiration|valid\s+until|due\s+date|birthday|'
    r'printed|statement\s+date|generated(?:\s+at)?)\b'
    r'|(?:วัน\s*(?:ที่)?\s*|เวลา\s*)?(?:หมด\s*อายุ|ครบ\s*กำหนด)'
    r'|วัน\s*เกิด|วัน\s*ที่\s*(?:พิมพ์|ออก\s*เอกสาร|บันทึก\s*ภาพ)',
    caseSensitive: false,
  );
  static final _ignoredTimestampCue = RegExp(
    '${_nonTransactionDateCue.pattern}|${_transactionNumberCue.pattern}|'
    r'\b(?:fee|balance|amount|total|account|tax\s+id)\b'
    r'|ค่าธรรมเนียม|ยอดคงเหลือ|จำนวนเงิน|ยอดเงิน|เลขบัญชี',
    caseSensitive: false,
  );
  static final _dateFieldCue = RegExp(
    '${_transactionDateCue.pattern}|${_ignoredTimestampCue.pattern}|${_dateCue.pattern}',
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
    final titleLines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line
            .replaceAll('\u200B', '')
            .replaceAll('\u0E4D\u0E32', 'ำ')
            .trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final lines = titleLines.map(_normalizeDigits).toList();

    final amount = _findAmount(lines);
    final timestamp = _findTimestamp(_joinSplitDateLines(lines));
    final date = timestamp?.date;
    final hasTransferConfirmation = lines.any(_transferSlipCue.hasMatch);
    final hasBankName = lines.any(_bankCue.hasMatch);
    final hasWalletName = lines.any(_walletSlipCue.hasMatch);
    final labeledReference = _findTransactionNumber(lines);
    final reference = labeledReference?.value ??
        (amount != null &&
                date != null &&
                (hasTransferConfirmation || hasBankName)
            ? _findUnlabeledReference(lines)
            : null);
    final hasWalletDetails =
        labeledReference != null && timestamp?.hasTime == true && hasWalletName;
    final hasBankTransferDetails = reference != null &&
        hasBankName &&
        lines.any(_transferPartiesCue.hasMatch);

    return SlipOcrResult(
      title: _findTitle(
        titleLines
            .map((line) => line.replaceAll(_titleWhitespace, ' '))
            .toList(),
        isTransfer: hasTransferConfirmation ||
            hasBankTransferDetails ||
            (hasBankName && amount != null && date != null),
      ),
      amount: amount,
      date: date,
      hasTime: timestamp?.hasTime ?? false,
      transactionNumber: reference,
      referenceConfidence:
          labeledReference?.confidence ?? (reference == null ? 0 : 1),
      timestampConfidence: timestamp?.confidence ?? 0,
      hasSlipHint: hasTransferConfirmation || hasBankName || hasWalletName,
      looksLikeTransferSlip: amount != null &&
          ((hasTransferConfirmation && (date != null || reference != null)) ||
              hasBankTransferDetails ||
              hasWalletDetails),
    );
  }

  static String? _findTitle(List<String> lines, {required bool isTransfer}) {
    final incoming = lines.any(_incomingCue.hasMatch);
    final labels = [
      _descriptionLabel,
      _merchantLabel,
      if (incoming) _senderLabel,
      _recipientLabel,
    ];
    for (final label in labels) {
      for (var index = 0; index < lines.length; index++) {
        final match = label.firstMatch(lines[index]);
        if (match == null) continue;
        final inline = lines[index]
            .substring(match.end)
            .replaceFirst(_titleSeparators, '')
            .trim();
        final name = _cleanTitle(inline);
        if (name != null) return name;
        if (inline.isNotEmpty && !_bankNameOnly.hasMatch(inline)) continue;

        // A logo or bank name may appear between a party label and its value.
        for (var next = index + 1;
            next <= index + 2 && next < lines.length;
            next++) {
          final line = lines[next];
          if (_isTitleField(line) || _titleMetadata.hasMatch(line)) break;
          if (_bankNameOnly.hasMatch(line)) continue;
          final nextName = _cleanTitle(line);
          if (nextName != null) return nextName;
          break;
        }
      }
    }

    if (!isTransfer) return null;
    // Some bank slips show the sender and recipient names with no labels.
    // Only use this ordering when both rows clearly look like party names.
    final seen = <String>{};
    final names = lines
        .where(_namedParty.hasMatch)
        .map(_cleanTitle)
        .whereType<String>()
        .where(seen.add)
        .toList();
    if (names.length != 2) return null;
    return incoming ? names.first : names.last;
  }

  static bool _isTitleField(String line) =>
      _descriptionLabel.hasMatch(line) ||
      _merchantLabel.hasMatch(line) ||
      _recipientLabel.hasMatch(line) ||
      _senderLabel.hasMatch(line);

  static String? _cleanTitle(String value) {
    final trailingField = _titleTrailingField.firstMatch(value);
    final beforeMetadata =
        trailingField == null ? value : value.substring(0, trailingField.start);
    final text = beforeMetadata
        .replaceFirst(_titleSeparators, '')
        .replaceFirst(_titleNamePrefix, '')
        .replaceFirst(_maskedAccountEnd, '')
        .replaceAll(_titleWhitespace, ' ')
        .trim();
    if (text.isEmpty ||
        text.length > 100 ||
        !_titleLetters.hasMatch(text) ||
        _isTitleField(text) ||
        _titleMetadata.hasMatch(text) ||
        _transactionNumberCue.hasMatch(text) ||
        _transferSlipCue.hasMatch(text) ||
        _bankNameOnly.hasMatch(text) ||
        _placeholderTitle.hasMatch(text) ||
        _compactCode.hasMatch(text) ||
        _amountOnly.hasMatch(text) ||
        _datePattern.hasMatch(text) ||
        _textDatePattern.matchAsPrefix(text) != null ||
        _monthFirstDatePattern.matchAsPrefix(text) != null ||
        _yearFirstNamedDatePattern.matchAsPrefix(text) != null ||
        _timePattern.hasMatch(text)) {
      return null;
    }
    return text;
  }

  static String _normalizeDigits(String text) {
    const thaiDigits = '๐๑๒๓๔๕๖๗๘๙';
    return text
        .replaceAllMapped(RegExp('[๐-๙０-９]'), (match) {
          final digit = match.group(0)!;
          final thai = thaiDigits.indexOf(digit);
          return '${thai >= 0 ? thai : digit.codeUnitAt(0) - 0xFF10}';
        })
        .replaceAll('：', ':')
        .replaceAll('／', '/')
        .replaceAll('．', '.')
        .replaceAll(RegExp(r'[‐‑‒–—−]'), '-');
  }

  static double? _findAmount(List<String> lines) {
    var bestScore = -1;
    double? bestAmount;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final hasCue = _amountCue.hasMatch(line);
      if (_isNonAmountLine(line)) continue;

      final candidates = _amountPattern
          .allMatches(line)
          .map((match) => (value: match.group(0)!, context: line))
          .toList();
      if (candidates.isEmpty &&
          hasCue &&
          index + 1 < lines.length &&
          !_isNonAmountLine(lines[index + 1])) {
        candidates.addAll(
          _amountPattern.allMatches(lines[index + 1]).map((match) => (
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
            (_paidAmountCue.hasMatch(candidate.context) ? 40 : 0) +
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

  static bool _isNonAmountLine(String line) =>
      _datePattern.hasMatch(line) ||
      _textDatePattern.hasMatch(line) ||
      _monthFirstDatePattern.hasMatch(line) ||
      _yearFirstNamedDatePattern.hasMatch(line) ||
      _splitDateHead.hasMatch(line) ||
      _timePattern.hasMatch(line) ||
      _clockCue.matchAsPrefix(line) != null ||
      _transactionClockCue.matchAsPrefix(line) != null ||
      _clockIn(line) != null ||
      _nonAmountCue.hasMatch(line) ||
      _transactionNumberCue.hasMatch(line);

  static List<String> _joinSplitDateLines(List<String> lines) {
    final joined = <String>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (index + 1 < lines.length &&
          _splitDateHead.hasMatch(line) &&
          _datesInLine(line).isEmpty) {
        final continuation = lines[index + 1];
        final year = _splitDateYear.firstMatch(continuation);
        if (year != null) {
          final trailing = continuation.substring(year.end).trim();
          if (trailing.isEmpty ||
              _clockIn(trailing) != null ||
              _clockCue.matchAsPrefix(trailing) != null) {
            final combined = '$line $continuation';
            if (_datesInLine(combined).isNotEmpty) {
              joined.add(combined);
              index++;
              continue;
            }
          }
        }
      }
      joined.add(line);
    }
    return joined;
  }

  static ({DateTime date, bool hasTime, int confidence})? _findTimestamp(
    List<String> lines,
  ) {
    final datesByLine = lines.map(_datesInLine).toList();
    final fieldsByLine =
        lines.map((line) => _dateFieldCue.allMatches(line).toList()).toList();
    DateTime? bestDate;
    Duration? bestClock;
    var bestScore = -1;
    final possibleDates = <DateTime>{};

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final dates = datesByLine[index];
      final fields = fieldsByLine[index];
      for (var position = 0; position < dates.length; position++) {
        final match = dates[position];
        final field =
            fields.where((field) => field.end <= match.start).lastOrNull;
        // A field label can be on the preceding line, above its value.
        final previousField = index > 0 && datesByLine[index - 1].isEmpty
            ? fieldsByLine[index - 1].lastOrNull
            : null;
        final inheritedLabel = previousField != null &&
                lines[index - 1]
                    .substring(previousField.end)
                    .replaceFirst(_titleSeparators, '')
                    .isEmpty
            ? previousField.group(0)
            : null;
        final label = field?.group(0) ?? inheritedLabel;
        if (label != null && _ignoredTimestampCue.hasMatch(label)) continue;
        possibleDates.add(match.date);

        final nextField =
            fields.where((field) => field.start >= match.end).firstOrNull;
        var end = nextField?.start ?? line.length;
        if (position + 1 < dates.length && dates[position + 1].start < end) {
          end = dates[position + 1].start;
        }
        var clock = _clockIn(line.substring(match.end, end));
        if (clock == null && position == 0) {
          clock = _clockIn(line.substring(field?.end ?? 0, match.start));
        }
        if (clock == null && end == line.length) {
          clock = _clockOnFollowingLines(
            lines,
            index,
            hasClockLabel: _clockCue.hasMatch(line.substring(match.end, end)),
          );
        }
        if (clock == null && position == 0 && index > 0) {
          final previousLine = lines[index - 1];
          final previousClockIsSeparate = _clockCue.hasMatch(previousLine) &&
              !_dateFieldCue.hasMatch(previousLine) &&
              (index < 2 || !_ignoredTimestampCue.hasMatch(lines[index - 2]));
          if (previousClockIsSeparate) clock = _clockIn(previousLine);
        }

        final priority = label == null
            ? 0
            : _transactionDateCue.hasMatch(label)
                ? 2
                : 1;
        final score = priority * 2 + (clock == null ? 0 : 1);
        if (score > bestScore) {
          bestScore = score;
          bestDate = match.date;
          bestClock = clock;
        }
      }
    }
    if (bestDate == null) return null;

    // A separately printed transaction time is safe to use when there is
    // just one date, or the chosen date is explicitly a transaction date.
    if (bestClock == null && (possibleDates.length == 1 || bestScore >= 4)) {
      bestClock = _separateTransactionClock(lines);
    }
    if (bestClock == null) {
      return (date: bestDate, hasTime: false, confidence: bestScore);
    }
    return (
      date: DateTime(
        bestDate.year,
        bestDate.month,
        bestDate.day,
        bestClock.inHours,
        bestClock.inMinutes % 60,
        bestClock.inSeconds % 60,
      ),
      hasTime: true,
      confidence: bestScore | 1,
    );
  }

  static final _clockPadding = RegExp(
    r'^[\s,;@|()‐‑‒–—−-]*(?:T|at|เมื่อ)?[\s,;@|()‐‑‒–—−-]*$',
    caseSensitive: false,
  );
  static final _clockSuffix =
      RegExp('^\\s*$_clockPeriod', caseSensitive: false);

  static Duration? _clockIn(String text, {bool hasClockLabel = false}) {
    for (final pattern in [_timePattern, _dottedTimePattern]) {
      for (final match in pattern.allMatches(text)) {
        final prefix = text.substring(0, match.start);
        final inlineLabel =
            _clockCue.hasMatch(prefix) && !_referenceDigit.hasMatch(prefix);
        if (!_clockPadding.hasMatch(prefix) && !inlineLabel) {
          continue;
        }
        final qualifier = match.group(4)?.toLowerCase();
        if (pattern == _dottedTimePattern &&
            !hasClockLabel &&
            !inlineLabel &&
            qualifier == null) {
          continue;
        }
        var hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final second = int.tryParse(match.group(3) ?? '') ?? 0;
        if (minute > 59 || second > 59) continue;
        if (qualifier?.startsWith('a') == true ||
            qualifier?.startsWith('p') == true) {
          if (hour < 1 || hour > 12) continue;
          hour = hour % 12 + (qualifier!.startsWith('p') ? 12 : 0);
        }
        if (hour > 23) continue;
        return Duration(hours: hour, minutes: minute, seconds: second);
      }
    }
    return null;
  }

  static Duration? _clockOnFollowingLines(
    List<String> lines,
    int index, {
    bool hasClockLabel = false,
  }) {
    for (var next = index + 1;
        next < lines.length && next <= index + 2;
        next++) {
      final line = lines[next];
      if (_dateFieldCue.hasMatch(line) ||
          (!hasClockLabel && _datesInLine(line).isNotEmpty)) {
        break;
      }
      final time = _clockIn(line, hasClockLabel: hasClockLabel);
      if (time != null) return time;
      if (!_clockCue.hasMatch(line) || _referenceDigit.hasMatch(line)) break;
      hasClockLabel = true;
    }
    return null;
  }

  static Duration? _separateTransactionClock(List<String> lines) {
    final clocks = <Duration>{};
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final label = _transactionClockCue.firstMatch(line);
      if (label == null || _ignoredTimestampCue.hasMatch(line)) continue;
      final value =
          line.substring(label.end).replaceFirst(_titleSeparators, '');
      final time = _clockIn(value, hasClockLabel: true) ??
          (value.isEmpty
              ? _clockOnFollowingLines(lines, index, hasClockLabel: true)
              : null);
      if (time != null) clocks.add(time);
    }
    return clocks.length == 1 ? clocks.single : null;
  }

  static String _monthPattern(String month) {
    if (month.codeUnitAt(0) < 0x0E00) return '${RegExp.escape(month)}\\.?';
    final characters = month.split('').map(RegExp.escape);
    return month.length <= 3
        ? '${characters.take(month.length - 1).join(r'\s*')}\\s*\\.?\\s*${characters.last}\\.?'
        : characters.join(r'\s*');
  }

  static List<({DateTime date, int start, int end})> _datesInLine(String line) {
    final dates = <({DateTime date, int start, int end})>[];
    void add(DateTime? date, RegExpMatch match) {
      if (date == null) return;
      dates.add((date: date, start: match.start, end: match.end));
    }

    for (final match in _datePattern.allMatches(line)) {
      final first = int.parse(match.group(1)!);
      final second = int.parse(match.group(3)!);
      final third = int.parse(match.group(5)!);
      final isYearFirst = match.group(1)!.length == 4;
      final year = isYearFirst ? first : third;
      final era = match.group(4);
      final dayFirst = isYearFirst ||
          _isBuddhistYear(year, era) ||
          first > 12 ||
          second <= 12;
      if (match.group(2) == '.' &&
          match.group(5)!.length == 2 &&
          (_clockSuffix.hasMatch(line.substring(match.end)) ||
              _clockCue.hasMatch(line.substring(0, match.start)))) {
        continue;
      }
      add(
        _makeDate(
          day: isYearFirst ? third : (dayFirst ? first : second),
          month: dayFirst ? second : first,
          year: year,
          era: era,
        ),
        match,
      );
    }

    for (final match in _textDatePattern.allMatches(line)) {
      final month = _monthFromToken(match.group(2)!);
      if (month == null) continue;
      add(
        _makeDate(
          day: int.parse(match.group(1)!),
          month: month,
          year: int.parse(match.group(4)!),
          era: match.group(3),
        ),
        match,
      );
    }

    for (final match in _monthFirstDatePattern.allMatches(line)) {
      final month = _monthFromToken(match.group(1)!);
      if (month == null) continue;
      add(
        _makeDate(
          day: int.parse(match.group(2)!),
          month: month,
          year: int.parse(match.group(4)!),
          era: match.group(3),
        ),
        match,
      );
    }
    for (final match in _yearFirstNamedDatePattern.allMatches(line)) {
      final month = _monthFromToken(match.group(2)!);
      if (month == null) continue;
      add(
        _makeDate(
          day: int.parse(match.group(3)!),
          month: month,
          year: int.parse(match.group(1)!),
        ),
        match,
      );
    }
    dates.sort((a, b) {
      final startOrder = a.start.compareTo(b.start);
      return startOrder == 0 ? b.end.compareTo(a.end) : startOrder;
    });
    // Competing date styles can match overlapping parts of one timestamp.
    // Keep the earlier complete match so a second value cannot split it.
    final distinctDates = <({DateTime date, int start, int end})>[];
    for (final candidate in dates) {
      if (distinctDates.isEmpty || candidate.start >= distinctDates.last.end) {
        distinctDates.add(candidate);
      }
    }
    return distinctDates;
  }

  static int? _monthFromToken(String token) =>
      _monthNumbers[token.toLowerCase().replaceAll(RegExp(r'[.\s]'), '')];

  static bool _isBuddhistYear(int year, String? era) {
    if (era != null) {
      return era.startsWith('พ') || era.toLowerCase().startsWith('b');
    }
    return year >= 2400 || (year >= 50 && year < 100);
  }

  static DateTime? _makeDate({
    required int day,
    required int month,
    required int year,
    String? era,
  }) {
    final buddhistEra = _isBuddhistYear(year, era);
    if (year < 100) {
      year += buddhistEra ? 2500 - 543 : 2000;
    } else if (buddhistEra) {
      year -= 543;
    }

    if (year < 1900 || year > 2199 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static ({String value, int confidence})? _findTransactionNumber(
    List<String> lines,
  ) {
    final normalized = lines.map(_normalizeReferenceLine).toList();
    ({String value, int confidence})? best;
    for (var index = 0; index < normalized.length; index++) {
      var text = normalized[index];
      final firstLineLength = text.length;
      for (var lastLine = index;
          lastLine < normalized.length && lastLine <= index + 2;
          lastLine++) {
        final lastLineStart = lastLine == index ? 0 : text.length + 1;
        if (lastLine != index) text = '$text ${normalized[lastLine]}';
        for (final label in _transactionNumberCue.allMatches(text)) {
          // Combine lines only when the label itself crosses their boundaries.
          if (lastLine != index &&
              (label.start >= firstLineLength || label.end <= lastLineStart)) {
            continue;
          }
          final isSpecific = _specificReferenceCue.matchAsPrefix(
                text,
                label.start,
              ) !=
              null;
          final isExplicit = _explicitReferenceCue.hasMatch(label.group(0)!);
          final value = text
              .substring(label.end)
              .replaceFirst(_referencePrefix, '')
              .trim();
          if (_numberedReference.hasMatch(value) ||
              _isReferenceQualifier(text, label.start)) {
            continue;
          }
          final reference = _referenceAfterLabel(
            normalized,
            lastLine,
            value,
            allowTruncated: isExplicit,
          );
          if (reference == null) continue;
          // A wallet receipt can print both the internal transaction number
          // and a separate reference number. Use the reference in that case.
          final confidence = isExplicit && isSpecific
              ? 5
              : isExplicit
                  ? 4
                  : isSpecific
                      ? 3
                      : 2;
          if (best == null || confidence > best.confidence) {
            best = (value: reference, confidence: confidence);
          }
        }
      }
    }
    return best;
  }

  static bool _isReferenceQualifier(String text, int labelStart) {
    final preceding =
        text.substring(0, labelStart).split(_referenceValueSuffix).last.trim();
    if (_nonTransactionIdCue.hasMatch(preceding)) return true;
    // A date or time already printed before the reference is its own field,
    // even when OCR did not retain any separator between the two labels.
    return _referenceNeighborCue.hasMatch(preceding) &&
        _datesInLine(preceding).isEmpty &&
        _clockIn(preceding) == null;
  }

  static String _normalizeReferenceLine(String text) {
    final ascii = String.fromCharCodes(
      text.runes.map(
          (char) => char >= 0xFF01 && char <= 0xFF5E ? char - 0xFEE0 : char),
    );
    return ascii
        .replaceAll(RegExp(r'[‐‑‒–—−]'), '-')
        .replaceAll(_referenceSpacing, ' ')
        .trim();
  }

  static String? _referenceAfterLabel(
    List<String> lines,
    int labelLine,
    String inline, {
    required bool allowTruncated,
  }) {
    final valueLine = inline.isEmpty ? labelLine + 1 : labelLine;
    if (valueLine >= lines.length) return null;
    var value = (inline.isEmpty ? lines[valueLine] : inline)
        .replaceFirst(_referenceValuePrefix, '');
    final truncated = _truncatedReference.firstMatch(value);
    if (truncated != null) {
      if (!allowTruncated) return null;
      value = value.substring(0, truncated.start);
    }
    final fragment = _referenceFragment(
      value,
      standalone: inline.isEmpty,
    );
    if (fragment == null) return null;

    final reference = _validReference(fragment);
    if (truncated != null) return reference == null ? null : '$reference…';
    if (valueLine + 1 >= lines.length) return reference;
    final continuation = _referenceFragment(
      lines[valueLine + 1],
      standalone: true,
    );
    if (continuation == null) return reference;
    final hasSplitSeparator =
        _referenceSeparator.hasMatch(fragment[fragment.length - 1]) ||
            _referenceSeparator.hasMatch(continuation[0]);
    final isLongNumericCode = _onlyReferenceDigits.hasMatch(fragment) &&
        _onlyReferenceDigits.hasMatch(continuation) &&
        fragment.length + continuation.length >= 16;
    final likelyCodeFragment = fragment.length < 16 &&
        continuation.length >= 4 &&
        !_commonAccountOrTaxLength.hasMatch(continuation) &&
        (reference == null ||
            _referenceSeparator.hasMatch(fragment) ||
            _referenceLetters.hasMatch(continuation) ||
            isLongNumericCode);
    if (hasSplitSeparator || likelyCodeFragment) {
      return _validReference('$fragment$continuation') ?? reference;
    }
    return reference;
  }

  static String? _referenceFragment(
    String value, {
    required bool standalone,
  }) {
    final nextLabel = _transactionNumberCue.firstMatch(value);
    if (_referenceNeighborCue.hasMatch(value) ||
        nextLabel?.start == 0 ||
        (_textDatePattern.matchAsPrefix(value) != null ||
                _monthFirstDatePattern.matchAsPrefix(value) != null ||
                _yearFirstNamedDatePattern.matchAsPrefix(value) != null) &&
            _datesInLine(value).isNotEmpty) {
      return null;
    }
    final punctuation = _referenceValueSuffix.firstMatch(value);
    var end = value.length;
    if (nextLabel != null) end = nextLabel.start;
    if (punctuation != null && punctuation.start < end) end = punctuation.start;
    if (standalone &&
        (nextLabel != null ||
            (punctuation != null &&
                value.substring(punctuation.end).trim().isNotEmpty))) {
      return null;
    }
    final tokens = value.substring(0, end).trim().split(' ');
    final compact = StringBuffer();
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      final isCode = _referenceToken.hasMatch(token) &&
          !_referenceNeighborCue.hasMatch(token) &&
          (_referenceDigit.hasMatch(token) ||
              _referenceSeparator.hasMatch(token) ||
              (token.length == 1 && token == token.toUpperCase()) ||
              (token.length <= 6 &&
                  index + 1 < tokens.length &&
                  (_referenceDigit.hasMatch(tokens[index + 1]) ||
                      _referenceSeparator.hasMatch(tokens[index + 1]))));
      if (!isCode) {
        if (standalone ||
            _datePattern.hasMatch(token) ||
            token.startsWith('.')) {
          return null;
        }
        break;
      }
      compact.write(token);
    }

    final fragment = compact.toString();
    if (fragment.isEmpty ||
        _datePattern.firstMatch(fragment)?.group(0) == fragment ||
        _accountOrTaxNumber.hasMatch(fragment) ||
        (fragment.toLowerCase().contains('xx') &&
            _maskedAccountNumber.hasMatch(fragment))) {
      return null;
    }
    return fragment;
  }

  static String? _validReference(String value) =>
      _transactionNumberValue.hasMatch(value) && _referenceDigit.hasMatch(value)
          ? value
          : null;

  static String? _findUnlabeledReference(List<String> lines) {
    // Latin OCR can omit Thai labels. Only use a long standalone code if the
    // slip also contains an amount, a date, and a transfer or bank cue.
    final candidates = <String>{};
    for (var index = 0; index < lines.length; index++) {
      if (index > 0 && _nonTransactionIdCue.hasMatch(lines[index - 1])) {
        continue;
      }
      final line = _normalizeReferenceLine(lines[index]);
      final fragment = _referenceFragment(line, standalone: true);
      if (fragment != null &&
          _longUnlabeledReference.hasMatch(fragment) &&
          _validReference(fragment) != null) {
        candidates.add(fragment);
      }
    }
    return candidates.length == 1 ? candidates.single : null;
  }
}
