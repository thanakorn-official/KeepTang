import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/transaction_model.dart';
import '../main.dart';
import '../services/guest_service.dart';
import '../services/slip_inbox_service.dart';
import '../services/slip_ocr_parser.dart';
import '../utils/l10n.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  static const _sortOrderPreferenceKey = 'dashboard_sort_order';
  static const _sortOrderOptions = ['newest', 'oldest', 'highest', 'lowest'];

  final ScrollController _dashboardScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot> _transactionsStream;
  QuerySnapshot? _cachedSnapshot;
  List<TransactionModel> _cachedParsedTransactions = [];
  List<TransactionModel> _cachedAvailableTransactions = [];
  final Map<String, TransactionModel> _cachedTransactionsById = {};
  String? _cachedPendingDeleteKey;
  List<TransactionModel>? _cachedAccountSource;
  String? _cachedAccountScope;
  List<TransactionModel> _cachedAccountTransactions = [];
  List<TransactionModel>? _cachedGroupSource;
  String? _cachedGroupType;
  List<TransactionModel> _cachedGroupTransactions = [];
  List<TransactionModel>? _cachedVisibleSource;
  String? _cachedVisibleKey;
  List<TransactionModel> _cachedVisibleTransactions = [];
  List<dynamic> _cachedVisibleListItems = [];
  List<TransactionModel> _cachedFilteredScopeTransactions = [];
  int _selectedPaymentPage = 0;
  double _accountSwipeDistance = 0;
  int _overviewSlideDirection = 1;
  String? _selectedChartCategory;
  String? _focusedCategoryAtPointerDown;

  final Map<String, IconData> _categoryIcons = {
    'อาหาร': Icons.restaurant,
    'เดินทาง': Icons.directions_car,
    'ช้อปปิ้ง': Icons.shopping_bag,
    'บิล/ค่าใช้จ่าย': Icons.receipt,
    'เงินเดือน/รายรับ': Icons.account_balance_wallet,
    'ความบันเทิง': Icons.movie,
    'สุขภาพ/พยาบาล': Icons.medical_services,
    'ที่อยู่อาศัย': Icons.home,
    'การศึกษา': Icons.school,
    'การลงทุน': Icons.trending_up,
    'อื่นๆ': Icons.category,
  };

  final Map<String, Color> _categoryColors = {
    'อาหาร': Colors.orange,
    'เดินทาง': Colors.blue,
    'ช้อปปิ้ง': Colors.purple,
    'บิล/ค่าใช้จ่าย': Colors.redAccent,
    'เงินเดือน/รายรับ': Colors.green,
    'ความบันเทิง': Colors.pink,
    'สุขภาพ/พยาบาล': Colors.cyan,
    'ที่อยู่อาศัย': Colors.brown,
    'การศึกษา': Colors.indigo,
    'การลงทุน': Colors.teal,
    'อื่นๆ': Colors.blueGrey,
  };

  final Map<String, IconData> _paymentIcons = {
    '\u0e44\u0e21\u0e48\u0e23\u0e30\u0e1a\u0e38': Icons.help_outline,
  };

  final Map<String, Color> _paymentColors = {
    '\u0e44\u0e21\u0e48\u0e23\u0e30\u0e1a\u0e38': Colors.blueGrey,
  };

  final List<Color> _availableColors = [
    Colors.orange,
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.redAccent,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
    Colors.brown,
    Colors.blueGrey,
  ];

  final List<IconData> _selectableCategoryIcons = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.receipt,
    Icons.account_balance_wallet,
    Icons.movie,
    Icons.medical_services,
    Icons.home,
    Icons.school,
    Icons.trending_up,
    Icons.pets,
    Icons.fitness_center,
    Icons.flight,
    Icons.sports_esports,
    Icons.phone_android,
    Icons.build,
    Icons.card_giftcard,
    Icons.category,
  ];

  final List<IconData> _selectablePaymentIcons = [
    Icons.payments_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    Icons.wallet,
    Icons.credit_card,
    Icons.account_balance,
    Icons.qr_code_scanner,
    Icons.contactless,
    Icons.currency_exchange,
    Icons.monetization_on,
    Icons.card_membership,
    Icons.store,
  ];

  final Set<String> _pendingDeleteIds = {};
  final Set<String> _selectedTransactionIds = {};
  List<SlipInboxDraft> _slipDrafts = [];
  bool _isScanningNewSlips = false;
  bool _isSlipInboxOpen = false;
  bool _slipScanDeferred = false;

  CollectionReference get _transactionsCollection => FirebaseFirestore.instance
      .collection('guests')
      .doc(GuestService.guestId)
      .collection('transactions');

  String _groupType = 'monthly';
  String _sortOrder = 'newest';
  String _searchQuery = '';
  bool _sortOrderWasChanged = false;

  Set<String> _selectedTypes = {'income', 'expense', 'transfer'};
  Set<String> _selectedCategories = {};
  Set<String> _selectedPayments = {};
  bool _categoryFilterActive = false;
  bool _paymentFilterActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transactionsStream =
        _transactionsCollection.orderBy('date', descending: true).snapshots();
    _loadCustomSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeSlipInbox());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_saveSlipScanTime());
    } else if (state == AppLifecycleState.resumed && !_isSlipInboxOpen) {
      unawaited(_scanForNewSlips());
    } else if (state == AppLifecycleState.resumed) {
      _slipScanDeferred = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dashboardScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeSlipInbox() async {
    try {
      _slipDrafts = await SlipInboxService.loadDrafts();
      if (!mounted) return;
      if (_slipDrafts.isNotEmpty) {
        await _showSlipInboxSheet();
        if (!mounted) return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastScan = prefs.getString(SlipInboxService.lastScanAtKey);
      if (lastScan == null) {
        await prefs.setString(
          SlipInboxService.lastScanAtKey,
          DateTime.now().toIso8601String(),
        );
        return;
      }
      await _scanForNewSlips();
    } catch (error) {
      debugPrint('Could not initialize slip inbox: $error');
      _showSlipInboxError();
    }
  }

  Future<void> _saveSlipScanTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SlipInboxService.lastScanAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (error) {
      debugPrint('Could not save slip scan time: $error');
    }
  }

  Future<void> _scanForNewSlips() async {
    if (_isScanningNewSlips ||
        !mounted ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    _isScanningNewSlips = true;
    var addedCount = 0;
    final scanStartedAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScanValue = prefs.getString(SlipInboxService.lastScanAtKey);
      if (lastScanValue == null) {
        await _saveSlipScanTime();
        return;
      }
      final lastScan = DateTime.parse(lastScanValue);
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        _showPhotoPermissionError();
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          createTimeCond: DateTimeCond(
            min: lastScan,
            max: DateTime.now(),
          ),
          orders: const [
            OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      final processedAssetIds = await SlipInboxService.loadProcessedAssetIds();
      final pendingAssetIds =
          _slipDrafts.map((draft) => draft.assetId).whereType<String>().toSet();
      if (paths.isNotEmpty) {
        final allImages = paths.first;
        final imageCount = await allImages.assetCountAsync;
        final recognizer = TextRecognizer();
        try {
          for (var start = 0; start < imageCount; start += 40) {
            final assets = await allImages.getAssetListRange(
              start: start,
              end: (start + 40).clamp(0, imageCount),
            );
            for (final asset in assets) {
              if (processedAssetIds.contains(asset.id) ||
                  pendingAssetIds.contains(asset.id)) {
                continue;
              }
              final file = await asset.file;
              if (file == null) continue;
              final imageBytes = await file.readAsBytes();
              final duplicateIndex = await _findQueuedImage(imageBytes);
              if (duplicateIndex != null) {
                final duplicate = _slipDrafts[duplicateIndex];
                _slipDrafts[duplicateIndex] =
                    duplicate.copyWith(assetId: asset.id);
                pendingAssetIds.add(asset.id);
                await SlipInboxService.saveDrafts(_slipDrafts);
                continue;
              }
              final recognizedText = await _recognizeText(
                recognizer,
                file.path,
              );
              final result = SlipOcrParser.parse(recognizedText);
              if (result.amount == null && result.transactionNumber == null) {
                continue;
              }

              final draft = await SlipInboxService.storeDraft(
                imageBytes: imageBytes,
                extension: _imageExtension(file.path),
                title: '',
                amount: result.amount,
                date: result.date ?? asset.createDateTime,
                category: _categoryIcons.keys.first,
                paymentMethod: _paymentIcons.keys.first,
                isExpense: true,
                transactionNo: result.transactionNumber,
                assetId: asset.id,
              );
              _slipDrafts = [..._slipDrafts, draft];
              pendingAssetIds.add(asset.id);
              await SlipInboxService.saveDrafts(_slipDrafts);
              addedCount++;
            }
          }
        } finally {
          await recognizer.close();
        }
      }

      await prefs.setString(
        SlipInboxService.lastScanAtKey,
        scanStartedAt.toIso8601String(),
      );
      if (addedCount > 0 && mounted && !_isSlipInboxOpen) {
        await _showSlipInboxSheet();
      }
    } catch (error) {
      debugPrint('Could not scan new slips: $error');
      _showSlipInboxError();
    } finally {
      _isScanningNewSlips = false;
      if (_slipScanDeferred && mounted && !_isSlipInboxOpen) {
        _slipScanDeferred = false;
        unawaited(_scanForNewSlips());
      }
    }
  }

  Future<String> _recognizeText(
    TextRecognizer recognizer,
    String imagePath,
  ) async {
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return recognized.text;
  }

  String _imageExtension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex < 0 ? 'jpg' : name.substring(dotIndex + 1);
  }

  Future<int?> _findQueuedImage(List<int> imageBytes) async {
    for (var index = 0; index < _slipDrafts.length; index++) {
      final file = File(_slipDrafts[index].imagePath);
      if (!await file.exists()) continue;
      final queuedBytes = await file.readAsBytes();
      if (listEquals(queuedBytes, imageBytes)) return index;
    }
    return null;
  }

  void _showPhotoPermissionError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.get('slipPhotoPermissionDenied'))),
    );
  }

  void _showSlipInboxError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(T.get('slipInboxFailed'))),
    );
  }

  Future<void> _showSlipImagePreview(
    BuildContext context,
    String imagePath,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(dialogContext).height * 0.82,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(dialogContext),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.file(
                File(imagePath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSlipInboxSheet() async {
    if (!mounted || _isSlipInboxOpen) return;
    _isSlipInboxOpen = true;
    var isProcessing = false;
    var processingMessage = '';

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            final canScanSlips = !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS);

            Future<void> importImage(
              XFile image, {
              bool keepProcessing = false,
            }) async {
              setSheetState(() {
                isProcessing = true;
                processingMessage = T.get('slipOcrProcessing');
              });
              try {
                final recognized = TextRecognizer();
                late final String text;
                try {
                  text = await _recognizeText(recognized, image.path);
                } finally {
                  await recognized.close();
                }
                final result = SlipOcrParser.parse(text);
                final bytes = await image.readAsBytes();
                final draft = await SlipInboxService.storeDraft(
                  imageBytes: bytes,
                  extension: _imageExtension(image.path),
                  title: '',
                  amount: result.amount,
                  date: result.date ?? DateTime.now(),
                  category: _categoryIcons.keys.first,
                  paymentMethod: _paymentIcons.keys.first,
                  isExpense: true,
                  transactionNo: result.transactionNumber,
                );
                final updatedDrafts = [..._slipDrafts, draft];
                await SlipInboxService.saveDrafts(updatedDrafts);
                if (!sheetContext.mounted) return;
                setState(() => _slipDrafts = updatedDrafts);
                setSheetState(() {
                  isProcessing = keepProcessing;
                  processingMessage = result.amount == null
                      ? T.get('slipOcrNoAmount')
                      : T.get('slipOcrReview');
                });
              } catch (error) {
                debugPrint('Could not import slip image: $error');
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  isProcessing = keepProcessing;
                  processingMessage = T.get('slipOcrFailed');
                });
              }
            }

            Future<void> chooseGalleryImages() async {
              try {
                setSheetState(() {
                  isProcessing = true;
                  processingMessage = T.get('slipOcrProcessing');
                });
                final images = await ImagePicker().pickMultiImage(
                  imageQuality: 100,
                );
                if (!sheetContext.mounted) return;
                for (final image in images) {
                  if (!sheetContext.mounted) break;
                  await importImage(image, keepProcessing: true);
                }
                if (sheetContext.mounted) {
                  setSheetState(() => isProcessing = false);
                }
              } catch (error) {
                debugPrint('Could not select slip images: $error');
                if (sheetContext.mounted) {
                  setSheetState(() => isProcessing = false);
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(T.get('slipInboxFailed'))),
                  );
                }
              }
            }

            Future<void> takeSlipPhoto() async {
              try {
                final image = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  imageQuality: 100,
                );
                if (image != null && sheetContext.mounted) {
                  await importImage(image);
                }
              } catch (error) {
                debugPrint('Could not take slip photo: $error');
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(T.get('slipInboxFailed'))),
                  );
                }
              }
            }

            Future<void> editDraft(SlipInboxDraft draft) async {
              final titleController = TextEditingController(text: draft.title);
              final amountController = TextEditingController(
                text: draft.amount?.toStringAsFixed(2) ?? '',
              );
              var date = draft.date;
              var category = _categoryIcons.containsKey(draft.category)
                  ? draft.category
                  : _categoryIcons.keys.first;
              var paymentMethod = _paymentIcons.containsKey(draft.paymentMethod)
                  ? draft.paymentMethod
                  : _paymentIcons.keys.first;
              var isExpense = draft.isExpense;
              try {
                final edited = await showDialog<SlipInboxDraft>(
                  context: sheetContext,
                  builder: (dialogContext) => StatefulBuilder(
                    builder: (context, setDialogState) => AlertDialog(
                      title: Text(T.get('edit')),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: T.get('titleLabel'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: T.get('amountLabel'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(T.get('transactionDateTime')),
                            ),
                            _buildDateTimeControls(
                              pickerContext: context,
                              value: date,
                              onChanged: (value) =>
                                  setDialogState(() => date = value),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: InputDecoration(
                                labelText: T.get('categoryLabel'),
                              ),
                              items: _categoryIcons.keys
                                  .map((item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => category = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: paymentMethod,
                              decoration: InputDecoration(
                                labelText: T.get('paymentMethodLabel'),
                              ),
                              items: _paymentIcons.keys
                                  .map((item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => paymentMethod = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: Text(T.get('expense')),
                                  selected: isExpense,
                                  onSelected: (_) =>
                                      setDialogState(() => isExpense = true),
                                ),
                                ChoiceChip(
                                  label: Text(T.get('income')),
                                  selected: !isExpense,
                                  onSelected: (_) =>
                                      setDialogState(() => isExpense = false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(T.get('cancel')),
                        ),
                        FilledButton(
                          onPressed: () {
                            final amount = double.tryParse(
                              amountController.text.replaceAll(',', '').trim(),
                            );
                            if (amount == null ||
                                amount <= 0 ||
                                amount > 1000000000) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(T.get('slipInboxIncomplete')),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(
                              dialogContext,
                              draft.copyWith(
                                title: titleController.text.trim(),
                                amount: amount,
                                date: date,
                                category: category,
                                paymentMethod: paymentMethod,
                                isExpense: isExpense,
                              ),
                            );
                          },
                          child: Text(T.get('save')),
                        ),
                      ],
                    ),
                  ),
                );
                if (edited == null || !sheetContext.mounted) return;
                final updatedDrafts = _slipDrafts
                    .map((item) => item.id == draft.id ? edited : item)
                    .toList();
                await SlipInboxService.saveDrafts(updatedDrafts);
                if (sheetContext.mounted) {
                  setState(() => _slipDrafts = updatedDrafts);
                  setSheetState(() {});
                }
              } catch (error) {
                debugPrint('Could not edit slip draft: $error');
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(T.get('saveError'))),
                  );
                }
              } finally {
                titleController.dispose();
                amountController.dispose();
              }
            }

            Future<void> deleteDraft(SlipInboxDraft draft) async {
              try {
                await SlipInboxService.removeDrafts(
                  _slipDrafts,
                  {draft.id},
                );
                if (!sheetContext.mounted) return;
                setState(() {
                  _slipDrafts =
                      _slipDrafts.where((item) => item.id != draft.id).toList();
                });
                setSheetState(() {});
              } catch (error) {
                debugPrint('Could not delete slip draft: $error');
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(T.get('saveError'))),
                  );
                }
              }
            }

            Future<void> addSelectedDrafts() async {
              final selected = _slipDrafts
                  .where((draft) => draft.selected)
                  .toList(growable: false);
              if (selected.isEmpty) return;
              if (selected.any((draft) =>
                  draft.amount == null ||
                  draft.amount! <= 0 ||
                  draft.amount! > 1000000000)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(T.get('slipInboxIncomplete'))),
                );
                return;
              }

              setSheetState(() {
                isProcessing = true;
                processingMessage = T.get('slipInboxSaving');
              });
              try {
                for (var start = 0; start < selected.length; start += 450) {
                  final chunk = selected.skip(start).take(450).toList();
                  final batch = FirebaseFirestore.instance.batch();
                  final draftIds = <String>{};
                  for (final draft in chunk) {
                    final reference = _transactionsCollection.doc();
                    batch.set(reference, {
                      'title': draft.title.trim().isEmpty
                          ? T.get('slipTransactionTitle')
                          : draft.title.trim(),
                      'amount': draft.amount,
                      'date': draft.date.toIso8601String(),
                      'isExpense': draft.isExpense ? 1 : 0,
                      'category': draft.category,
                      'paymentMethod': draft.paymentMethod,
                      if (draft.transactionNo != null)
                        'transactionNo': draft.transactionNo,
                    });
                    draftIds.add(draft.id);
                  }
                  await batch.commit();
                  await SlipInboxService.removeDrafts(_slipDrafts, draftIds);
                  _slipDrafts = _slipDrafts
                      .where((draft) => !draftIds.contains(draft.id))
                      .toList();
                  if (sheetContext.mounted) {
                    setState(() {});
                    setSheetState(() {});
                  }
                }
                if (sheetContext.mounted && _slipDrafts.isEmpty) {
                  Navigator.pop(sheetContext);
                }
              } catch (error) {
                debugPrint('Could not save selected slips: $error');
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(T.get('saveError'))),
                  );
                }
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => isProcessing = false);
                }
              }
            }

            final selectedCount =
                _slipDrafts.where((draft) => draft.selected).length;
            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: constraints.maxHeight * 0.9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Text(
                          T.get('slipInboxTitle'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isProcessing || !canScanSlips
                                    ? null
                                    : chooseGalleryImages,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(T.get('chooseMultipleSlips')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: T.get('takeSlipPhoto'),
                              onPressed: isProcessing || !canScanSlips
                                  ? null
                                  : takeSlipPhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                            ),
                          ],
                        ),
                        if (isProcessing) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 6),
                          Text(processingMessage),
                        ],
                        if (!canScanSlips)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(T.get('slipOcrUnsupported')),
                          ),
                        if (_slipDrafts.isEmpty && !isProcessing)
                          Expanded(
                            child: Center(child: Text(T.get('slipInboxEmpty'))),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: _slipDrafts.length,
                              itemBuilder: (context, index) {
                                final draft = _slipDrafts[index];
                                return Card(
                                  child: ListTile(
                                    leading: SizedBox(
                                      width: 92,
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: draft.selected,
                                            onChanged: isProcessing
                                                ? null
                                                : (value) async {
                                                    final updatedDrafts = [
                                                      ..._slipDrafts
                                                    ];
                                                    updatedDrafts[index] =
                                                        draft.copyWith(
                                                      selected: value ?? false,
                                                    );
                                                    try {
                                                      await SlipInboxService
                                                          .saveDrafts(
                                                              updatedDrafts);
                                                      if (sheetContext
                                                          .mounted) {
                                                        setState(() =>
                                                            _slipDrafts =
                                                                updatedDrafts);
                                                        setSheetState(() {});
                                                      }
                                                    } catch (error) {
                                                      debugPrint(
                                                        'Could not update slip selection: $error',
                                                      );
                                                      if (sheetContext
                                                          .mounted) {
                                                        ScaffoldMessenger.of(
                                                                sheetContext)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              T.get(
                                                                  'saveError'),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                          ),
                                          GestureDetector(
                                            onTap: () => _showSlipImagePreview(
                                              sheetContext,
                                              draft.imagePath,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.file(
                                                File(draft.imagePath),
                                                width: 34,
                                                height: 42,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                  Icons.receipt_long_outlined,
                                                  size: 32,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    title: Text(
                                      draft.title.trim().isEmpty
                                          ? T.get('slipTransactionTitle')
                                          : draft.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${draft.amount == null ? T.get('slipInboxMissingAmount') : NumberFormat('#,##0.00').format(draft.amount)}  •  ${DateFormat('dd/MM/yyyy').format(draft.date)}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 0,
                                      children: [
                                        IconButton(
                                          tooltip: T.get('edit'),
                                          onPressed: isProcessing
                                              ? null
                                              : () => editDraft(draft),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: T.get('delete'),
                                          onPressed: isProcessing
                                              ? null
                                              : () => deleteDraft(draft),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isProcessing || selectedCount == 0
                                ? null
                                : addSelectedDrafts,
                            icon: const Icon(Icons.playlist_add_check_rounded),
                            label: Text(
                              '${T.get('addSelectedSlips')} ($selectedCount)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _isSlipInboxOpen = false;
      if (_slipScanDeferred && mounted && !_isScanningNewSlips) {
        _slipScanDeferred = false;
        unawaited(_scanForNewSlips());
      }
    }
  }

  void _selectPaymentAccount(int index, {int slideDirection = 1}) {
    final payments = _paymentIcons.keys.toList();
    final targetIndex = index.clamp(0, payments.length).toInt();
    if (targetIndex == _selectedPaymentPage) return;

    setState(() {
      _selectedPaymentPage = targetIndex;
      _overviewSlideDirection = slideDirection;
      _selectedChartCategory = null;
      _selectedTransactionIds.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dashboardScrollController.hasClients) {
        _dashboardScrollController.jumpTo(0);
      }
    });
  }

  void _handleAccountSwipeEnd(List<String> payments) {
    if (_accountSwipeDistance.abs() < 40) return;
    final direction = _accountSwipeDistance < 0 ? 1 : -1;
    _selectPaymentAccount(
      _selectedPaymentPage + direction,
      slideDirection: direction,
    );
    _accountSwipeDistance = 0;
  }

  Widget _buildAccountOverview({
    required String? paymentScope,
    required List<TransactionModel> accountTransactions,
    required List<TransactionModel> chartTransactions,
    required double income,
    required double expense,
    required double balance,
    required double selectedNet,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _accountSwipeDistance = 0,
      onHorizontalDragUpdate: (details) {
        _accountSwipeDistance += details.delta.dx;
      },
      onHorizontalDragEnd: (_) =>
          _handleAccountSwipeEnd(_paymentIcons.keys.toList()),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isOutgoing = animation.status == AnimationStatus.reverse;
          final slideDirection = isOutgoing
              ? -_overviewSlideDirection.toDouble()
              : _overviewSlideDirection.toDouble();
          final slide = Tween<Offset>(
            begin: Offset(slideDirection * 1.15, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: Column(
          key: ValueKey<String>('overview-${paymentScope ?? 'all'}'),
          children: [
            const SizedBox(height: 24),
            _buildPieChart(chartTransactions, selectedNet: selectedNet),
            if (accountTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(T.get('noData'),
                    style: const TextStyle(color: Colors.grey)),
              ),
            _buildSummaryRow(income, expense, balance),
            const Divider(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _getDefaultCategoryIcon(String cat) {
    if (cat == 'transfer') return Icons.swap_horiz;
    switch (cat) {
      case 'อาหาร':
        return Icons.restaurant;
      case 'เดินทาง':
        return Icons.directions_car;
      case 'ช้อปปิ้ง':
        return Icons.shopping_bag;
      case 'บิล/ค่าใช้จ่าย':
        return Icons.receipt;
      case 'เงินเดือน/รายรับ':
        return Icons.account_balance_wallet;
      case 'ความบันเทิง':
        return Icons.movie;
      case 'สุขภาพ/พยาบาล':
        return Icons.medical_services;
      case 'ที่อยู่อาศัย':
        return Icons.home;
      case 'การศึกษา':
        return Icons.school;
      case 'การลงทุน':
        return Icons.trending_up;
      case 'อื่นๆ':
        return Icons.category;
      case 'ไม่ระบุ':
        return Icons.help_outline;
      default:
        return Icons.label;
    }
  }

  Color _getDefaultCategoryColor(String cat) {
    if (cat == 'transfer') return Colors.blueGrey;
    switch (cat) {
      case 'อาหาร':
        return Colors.orange;
      case 'เดินทาง':
        return Colors.blue;
      case 'ช้อปปิ้ง':
        return Colors.purple;
      case 'บิล/ค่าใช้จ่าย':
        return Colors.redAccent;
      case 'เงินเดือน/รายรับ':
        return Colors.green;
      case 'ความบันเทิง':
        return Colors.pink;
      case 'สุขภาพ/พยาบาล':
        return Colors.cyan;
      case 'ที่อยู่อาศัย':
        return Colors.brown;
      case 'การศึกษา':
        return Colors.indigo;
      case 'การลงทุน':
        return Colors.teal;
      case 'อื่นๆ':
        return Colors.blueGrey;
      case 'ไม่ระบุ':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getDefaultPaymentIcon(String pay) {
    switch (pay) {
      case 'cash':
        return Icons.payments_outlined;
      case 'promptpay':
        return Icons.account_balance_wallet_outlined;
      case 'truemoney':
        return Icons.account_balance_wallet;
      case 'paotang':
        return Icons.wallet;
      case 'ไม่ระบุ':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment;
    }
  }

  Color _getDefaultPaymentColor(String pay) {
    switch (pay) {
      case 'cash':
        return Colors.green;
      case 'promptpay':
        return Colors.blue;
      case 'truemoney':
        return Colors.orange;
      case 'paotang':
        return Colors.lightBlue;
      case 'ไม่ระบุ':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _loadCustomSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedSortOrder = prefs.getString(_sortOrderPreferenceKey);
    if (!_sortOrderWasChanged && _sortOrderOptions.contains(savedSortOrder)) {
      setState(() {
        _sortOrder = savedSortOrder!;
      });
    }

    final customCats = prefs.getString('app_categories_list');
    if (customCats != null) {
      final List<dynamic> decoded = jsonDecode(customCats);
      setState(() {
        _categoryIcons.clear();
        _categoryColors.clear();
        for (var item in decoded) {
          final cat = item.toString();
          _categoryIcons[cat] = _getDefaultCategoryIcon(cat);
          _categoryColors[cat] = _getDefaultCategoryColor(cat);
        }
      });
    }

    final catIconsStr = prefs.getString('app_category_icon_codes');
    if (catIconsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(catIconsStr);
      decoded.forEach((k, v) {
        if (_categoryIcons.containsKey(k)) {
          _categoryIcons[k] = _selectableCategoryIcons.firstWhere(
            (icon) => icon.codePoint == (v as int),
            orElse: () => _getDefaultCategoryIcon(k),
          );
        }
      });
    }

    final catColorsStr = prefs.getString('app_category_color_values');
    if (catColorsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(catColorsStr);
      decoded.forEach((k, v) {
        if (_categoryColors.containsKey(k)) {
          _categoryColors[k] = Color(v as int);
        }
      });
    }

    final customPayments = prefs.getString('app_payments_list');
    if (customPayments != null) {
      final List<dynamic> decoded = jsonDecode(customPayments);
      setState(() {
        _paymentIcons.clear();
        _paymentColors.clear();
        for (var item in decoded) {
          final pay = item.toString();
          _paymentIcons[pay] = _getDefaultPaymentIcon(pay);
          _paymentColors[pay] = _getDefaultPaymentColor(pay);
        }
      });
    }

    final payIconsStr = prefs.getString('app_payment_icon_codes');
    if (payIconsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(payIconsStr);
      decoded.forEach((k, v) {
        if (_paymentIcons.containsKey(k)) {
          _paymentIcons[k] = _selectablePaymentIcons.firstWhere(
            (icon) => icon.codePoint == (v as int),
            orElse: () => _getDefaultPaymentIcon(k),
          );
        }
      });
    }

    final payColorsStr = prefs.getString('app_payment_color_values');
    if (payColorsStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(payColorsStr);
      decoded.forEach((k, v) {
        if (_paymentColors.containsKey(k)) {
          _paymentColors[k] = Color(v as int);
        }
      });
    }
    const unspecified = '\u0e44\u0e21\u0e48\u0e23\u0e30\u0e1a\u0e38';
    _categoryIcons.putIfAbsent(unspecified, () => Icons.help_outline);
    _categoryColors.putIfAbsent(unspecified, () => Colors.blueGrey);
    _paymentIcons.putIfAbsent(unspecified, () => Icons.help_outline);
    _paymentColors.putIfAbsent(unspecified, () => Colors.blueGrey);
  }

  Future<void> _updateSortOrder(String? value) async {
    if (value == null || !_sortOrderOptions.contains(value)) return;

    setState(() {
      _sortOrder = value;
      _sortOrderWasChanged = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOrderPreferenceKey, value);
  }

  Color _colorOf(String category) {
    if (category == 'transfer') return Colors.blueGrey;
    if (!_categoryColors.containsKey(category)) return Colors.red;
    return _categoryColors[category] ?? Colors.blueGrey;
  }

  IconData _iconOf(String category) {
    if (category == 'transfer') return Icons.swap_horiz;
    if (!_categoryIcons.containsKey(category)) return Icons.help_outline;
    return _categoryIcons[category] ?? _getDefaultCategoryIcon(category);
  }

  IconData _paymentIconOf(String payment) {
    if (!_paymentIcons.containsKey(payment)) return Icons.help_outline;
    return _paymentIcons[payment] ?? _getDefaultPaymentIcon(payment);
  }

  Color _paymentColorOf(String payment) {
    if (!_paymentColors.containsKey(payment)) return Colors.red;
    return _paymentColors[payment] ?? _getDefaultPaymentColor(payment);
  }

  Future<void> _showQuickAddCategoryDialog(
      StateSetter setModalState, ValueChanged<String> onAdded) async {
    final controller = TextEditingController();
    IconData selectedIcon = _selectableCategoryIcons.first;
    Color selectedColor = _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(T.get('addCategory')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: T.get('categoryName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('selectIcon'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectableCategoryIcons.map((icon) {
                      final isSelected =
                          selectedIcon.codePoint == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('pickColor'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected =
                          selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1)
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty && !_categoryIcons.containsKey(text)) {
                    setState(() {
                      _categoryIcons[text] = selectedIcon;
                      _categoryColors[text] = selectedColor;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_categories_list',
                        jsonEncode(_categoryIcons.keys.toList()));
                    await prefs.setString(
                        'app_category_icon_codes',
                        jsonEncode(_categoryIcons
                            .map((k, v) => MapEntry(k, v.codePoint))));
                    await prefs.setString(
                        'app_category_color_values',
                        jsonEncode(_categoryColors
                            .map((k, v) => MapEntry(k, v.toARGB32()))));

                    onAdded(text);
                    setModalState(() {});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showQuickAddPaymentDialog(
      StateSetter setModalState, ValueChanged<String> onAdded) async {
    final controller = TextEditingController();
    IconData selectedIcon = _selectablePaymentIcons.first;
    Color selectedColor = _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(T.get('addPayment')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: T.get('paymentName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('selectIcon'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectablePaymentIcons.map((icon) {
                      final isSelected =
                          selectedIcon.codePoint == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.grey),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(T.get('pickColor'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((color) {
                      final isSelected =
                          selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1)
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty && !_paymentIcons.containsKey(text)) {
                    setState(() {
                      _paymentIcons[text] = selectedIcon;
                      _paymentColors[text] = selectedColor;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_payments_list',
                        jsonEncode(_paymentIcons.keys.toList()));
                    await prefs.setString(
                        'app_payment_icon_codes',
                        jsonEncode(_paymentIcons
                            .map((k, v) => MapEntry(k, v.codePoint))));
                    await prefs.setString(
                        'app_payment_color_values',
                        jsonEncode(_paymentColors
                            .map((k, v) => MapEntry(k, v.toARGB32()))));

                    onAdded(text);
                    setModalState(() {});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferSheet(BuildContext context) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    String fromPayment = _paymentIcons.keys.first;
    String toPayment = _paymentIcons.keys.length > 1
        ? _paymentIcons.keys.elementAt(1)
        : _paymentIcons.keys.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    16,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(T.get('transferBetweenAccounts'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                            labelText: T.get('amountLabel'),
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: fromPayment,
                      decoration: InputDecoration(
                          labelText: T.get('fromAccount'),
                          border: const OutlineInputBorder()),
                      items: _paymentIcons.keys.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Row(
                            children: [
                              Icon(_paymentIconOf(method),
                                  color: _paymentColorOf(method), size: 20),
                              const SizedBox(width: 8),
                              Text(method),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => fromPayment = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: toPayment,
                      decoration: InputDecoration(
                          labelText: T.get('toAccount'),
                          border: const OutlineInputBorder()),
                      items: _paymentIcons.keys.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Row(
                            children: [
                              Icon(_paymentIconOf(method),
                                  color: _paymentColorOf(method), size: 20),
                              const SizedBox(width: 8),
                              Text(method),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => toPayment = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                            labelText: T.get('optionalNote'),
                            border: const OutlineInputBorder())),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white),
                        onPressed: () {
                          if (amountController.text.isEmpty ||
                              fromPayment == toPayment) {
                            return;
                          }

                          _transactionsCollection.add({
                            'title': noteController.text.isNotEmpty
                                ? noteController.text
                                : '${T.get('transferredOut')} $toPayment',
                            'amount':
                                double.tryParse(amountController.text) ?? 0.0,
                            'date': DateTime.now().toIso8601String(),
                            'isExpense': 1,
                            'category': 'transfer',
                            'paymentMethod': fromPayment,
                          });

                          _transactionsCollection.add({
                            'title': noteController.text.isNotEmpty
                                ? noteController.text
                                : '${T.get('transferredIn')} $fromPayment',
                            'amount':
                                double.tryParse(amountController.text) ?? 0.0,
                            'date': DateTime.now().toIso8601String(),
                            'isExpense': 0,
                            'category': 'transfer',
                            'paymentMethod': toPayment,
                          });

                          Navigator.pop(ctx);
                        },
                        child: Text(T.get('confirmTransfer'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${NumberFormat('#,##0.00').format(amount)} ฿',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(double income, double expense, double balance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryItem(T.get('totalIncome'), income, Colors.green),
        _buildSummaryItem(
            T.get('balance'), balance, balance >= 0 ? Colors.blue : Colors.red),
        _buildSummaryItem(T.get('totalExpense'), expense, Colors.redAccent),
      ],
    );
  }

  Widget _buildDropdown(String value, List<String> items, IconData icon,
      ValueChanged<String?> onChanged,
      {bool isActive = false}) {
    final currentValue = items.contains(value) ? value : items.first;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? colors.primaryContainer
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? colors.primary : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isActive ? colors.primary : colors.onSurfaceVariant),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isDense: true,
              borderRadius: BorderRadius.circular(16),
              menuMaxHeight: 360,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: colors.onSurfaceVariant),
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map((val) =>
                      DropdownMenuItem(value: val, child: Text(T.get(val))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    int selectedCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 1,
              )),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isActive ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        isActive ? Theme.of(context).colorScheme.primary : null,
                  )),
              const SizedBox(width: 4),
              if (isActive) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$selectedCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down,
                  size: 18,
                  color:
                      isActive ? Theme.of(context).colorScheme.primary : null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            hintText: T.get('search'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: T.get('clearFilters'),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
            filled: true,
            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterPanel() {
    final categoryItems = <String, String>{
      for (final category in _categoryIcons.keys) category: category,
      'transfer': T.get('transfer'),
    };
    final paymentItems = <String, String>{
      for (final payment in _paymentIcons.keys) payment: payment,
    };
    var draftTypes = Set<String>.from(_selectedTypes);
    var draftCategories = Set<String>.from(_selectedCategories);
    var draftPayments = Set<String>.from(_selectedPayments);
    var draftCategoryFilterActive = _categoryFilterActive;
    var draftPaymentFilterActive = _paymentFilterActive;
    var showAllCategories = false;
    var showAllPayments = false;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setPanelState) {
          final colors = Theme.of(sheetContext).colorScheme;

          Widget selectionSection({
            required String title,
            required Map<String, String> items,
            required Set<String> selectedItems,
            required bool filterActive,
            required bool showAll,
            required ValueChanged<bool> onShowAllChanged,
            required ValueChanged<bool> onFilterActiveChanged,
            required IconData Function(String key) iconForItem,
            required Color Function(String key) colorForItem,
            required ValueChanged<Set<String>> onSelectionChanged,
          }) {
            final visibleItems = showAll
                ? items.entries.toList()
                : items.entries.take(5).toList();
            final allSelected =
                items.isNotEmpty && selectedItems.length == items.length;
            final selectedCount = !filterActive || allSelected
                ? items.length
                : selectedItems.length;
            final optionWidth =
                (MediaQuery.sizeOf(sheetContext).width - 50) / 2;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Text(
                            !filterActive || allSelected
                                ? T.get('all')
                                : '$selectedCount ${T.get('selected')}',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          onSelectionChanged(allSelected
                              ? <String>{}
                              : Set<String>.from(items.keys));
                          onFilterActiveChanged(true);
                        },
                        child:
                            Text(T.get(allSelected ? 'clearAll' : 'selectAll')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in visibleItems)
                        SizedBox(
                          width: optionWidth,
                          child: Builder(builder: (context) {
                            final isSelected =
                                selectedItems.contains(entry.key);
                            final itemColor = colorForItem(entry.key);
                            return Material(
                              color: isSelected
                                  ? colors.primaryContainer
                                      .withValues(alpha: 0.5)
                                  : colors.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.45)
                                      : colors.outlineVariant
                                          .withValues(alpha: 0.55),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  final next = Set<String>.from(selectedItems);
                                  if (next.contains(entry.key)) {
                                    next.remove(entry.key);
                                  } else {
                                    next.add(entry.key);
                                  }
                                  onSelectionChanged(next);
                                  onFilterActiveChanged(true);
                                },
                                child: SizedBox(
                                  height: 62,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: itemColor.withValues(
                                                alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(iconForItem(entry.key),
                                              size: 18, color: itemColor),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(sheetContext)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                    color: colors.onSurface,
                                                    height: 1.15),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 18,
                                          color: isSelected
                                              ? colors.primary
                                              : colors.outlineVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                  if (items.length > 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => onShowAllChanged(!showAll),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(T.get(showAll ? 'showLess' : 'showAll')),
                            const SizedBox(width: 4),
                            Icon(
                              showAll
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(T.get('filters'),
                              style:
                                  Theme.of(sheetContext).textTheme.titleLarge),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                          tooltip: T.get('close'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      children: [
                        selectionSection(
                          title: T.get('filterType'),
                          items: {
                            'income': T.get('income'),
                            'expense': T.get('expense'),
                            'transfer': T.get('transfer'),
                          },
                          selectedItems: draftTypes,
                          filterActive: true,
                          showAll: true,
                          onShowAllChanged: (_) {},
                          onFilterActiveChanged: (_) {},
                          iconForItem: (type) => switch (type) {
                            'income' => Icons.arrow_upward,
                            'expense' => Icons.arrow_downward,
                            _ => Icons.swap_horiz,
                          },
                          colorForItem: (type) => switch (type) {
                            'income' => Colors.green,
                            'expense' => Colors.red,
                            _ => Colors.blueGrey,
                          },
                          onSelectionChanged: (value) =>
                              setPanelState(() => draftTypes = value),
                        ),
                        selectionSection(
                          title: T.get('filterCategory'),
                          items: categoryItems,
                          selectedItems: draftCategories,
                          filterActive: draftCategoryFilterActive,
                          showAll: showAllCategories,
                          onShowAllChanged: (value) =>
                              setPanelState(() => showAllCategories = value),
                          onFilterActiveChanged: (value) => setPanelState(
                              () => draftCategoryFilterActive = value),
                          iconForItem: _iconOf,
                          colorForItem: _colorOf,
                          onSelectionChanged: (value) =>
                              setPanelState(() => draftCategories = value),
                        ),
                        if (_selectedPaymentPage == 0)
                          selectionSection(
                            title: T.get('filterPayment'),
                            items: paymentItems,
                            selectedItems: draftPayments,
                            filterActive: draftPaymentFilterActive,
                            showAll: showAllPayments,
                            onShowAllChanged: (value) =>
                                setPanelState(() => showAllPayments = value),
                            onFilterActiveChanged: (value) => setPanelState(
                                () => draftPaymentFilterActive = value),
                            iconForItem: _paymentIconOf,
                            colorForItem: _paymentColorOf,
                            onSelectionChanged: (value) =>
                                setPanelState(() => draftPayments = value),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedTypes = {
                                    'income',
                                    'expense',
                                    'transfer',
                                  };
                                  _selectedCategories.clear();
                                  _selectedPayments.clear();
                                  _categoryFilterActive = false;
                                  _paymentFilterActive = false;
                                });
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.restart_alt),
                              label: Text(T.get('clearFilters')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTypes = draftTypes;
                                  _selectedCategories = draftCategories;
                                  _selectedPayments = draftPayments;
                                  _categoryFilterActive =
                                      draftCategoryFilterActive;
                                  _paymentFilterActive =
                                      draftPaymentFilterActive;
                                });
                                Navigator.pop(sheetContext);
                              },
                              child: Text(T.get('apply')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    final activeSelections =
        (_selectedTypes.length == 3 ? 0 : _selectedTypes.length) +
            (_categoryFilterActive ? 1 : 0) +
            (_selectedPaymentPage == 0 && _paymentFilterActive ? 1 : 0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildDropdown(
            _groupType,
            ['daily', 'weekly', 'monthly', 'yearly', 'none'],
            Icons.date_range,
            (value) => setState(() => _groupType = value!),
            isActive: _groupType != 'monthly',
          ),
          _buildDropdown(
            _sortOrder,
            _sortOrderOptions,
            Icons.sort,
            _updateSortOrder,
            isActive: _sortOrder != 'newest',
          ),
          _buildMultiSelectButton(
            label: T.get('filters'),
            icon: Icons.tune,
            isActive: activeSelections > 0,
            selectedCount: activeSelections,
            onTap: _showFilterPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField({
    required String selected,
    required ValueChanged<String?> onChanged,
    required StateSetter setModalState,
    bool outlined = false,
  }) {
    List<DropdownMenuItem<String>> items = _categoryIcons.keys.map((cat) {
      return DropdownMenuItem(
        value: cat,
        child: Row(
          children: [
            Icon(_iconOf(cat), color: _colorOf(cat), size: 20),
            const SizedBox(width: 8),
            Text(cat),
          ],
        ),
      );
    }).toList();

    if (selected == 'transfer') {
      items.add(
        DropdownMenuItem(
          value: 'transfer',
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.blueGrey, size: 20),
              const SizedBox(width: 8),
              Text(T.get('transfer')),
            ],
          ),
        ),
      );
    }

    final selectedValue =
        (_categoryIcons.containsKey(selected) || selected == 'transfer')
            ? selected
            : _categoryIcons.keys.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: InputDecoration(
              labelText: T.get('categoryLabel'),
              border: outlined ? const OutlineInputBorder() : null,
            ),
            items: items,
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 28),
          color: Theme.of(context).colorScheme.primary,
          tooltip: T.get('addCategory'),
          onPressed: () {
            _showQuickAddCategoryDialog(setModalState, (newCat) {
              onChanged(newCat);
            });
          },
        ),
      ],
    );
  }

  Widget _buildPaymentField({
    required String selected,
    required ValueChanged<String?> onChanged,
    required StateSetter setModalState,
    bool outlined = false,
  }) {
    List<DropdownMenuItem<String>> paymentItems =
        _paymentIcons.keys.map((method) {
      return DropdownMenuItem(
        value: method,
        child: Row(
          children: [
            Icon(_paymentIconOf(method),
                color: _paymentColorOf(method), size: 20),
            const SizedBox(width: 8),
            Text(method),
          ],
        ),
      );
    }).toList();

    final selectedValue = _paymentIcons.containsKey(selected)
        ? selected
        : _paymentIcons.keys.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: InputDecoration(
              labelText: T.get('paymentMethodLabel'),
              border: outlined ? const OutlineInputBorder() : null,
            ),
            items: paymentItems,
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 28),
          color: Theme.of(context).colorScheme.primary,
          tooltip: T.get('addPayment'),
          onPressed: () {
            _showQuickAddPaymentDialog(setModalState, (newPay) {
              onChanged(newPay);
            });
          },
        ),
      ],
    );
  }

  void _showEditDialog(TransactionModel tx) {
    final titleController = TextEditingController(text: tx.title);
    final amountController = TextEditingController(text: tx.amount.toString());
    DateTime transactionDate = tx.date;
    String selectedCategory =
        (_categoryIcons.containsKey(tx.category) || tx.category == 'transfer')
            ? tx.category
            : _categoryIcons.keys.first;
    String selectedPaymentMethod = _paymentIcons.containsKey(tx.paymentMethod)
        ? tx.paymentMethod
        : _paymentIcons.keys.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(T.get('edit')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleController,
                      decoration:
                          InputDecoration(labelText: T.get('titleLabel'))),
                  const SizedBox(height: 16),
                  TextField(
                      controller: amountController,
                      decoration:
                          InputDecoration(labelText: T.get('amountLabel')),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(T.get('transactionDateTime')),
                  ),
                  const SizedBox(height: 4),
                  _buildDateTimeControls(
                    pickerContext: context,
                    value: transactionDate,
                    onChanged: (value) =>
                        setStateDialog(() => transactionDate = value),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryField(
                    selected: selectedCategory,
                    setModalState: setStateDialog,
                    onChanged: (val) =>
                        setStateDialog(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentField(
                    selected: selectedPaymentMethod,
                    setModalState: setStateDialog,
                    onChanged: (val) =>
                        setStateDialog(() => selectedPaymentMethod = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(T.get('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _transactionsCollection.doc(tx.id).update({
                      'title': titleController.text,
                      'amount':
                          double.tryParse(amountController.text) ?? tx.amount,
                      'date': transactionDate.toIso8601String(),
                      'category': selectedCategory,
                      'paymentMethod': selectedPaymentMethod,
                      'updatedAt': DateTime.now().toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(T.get('saveError'))),
                    );
                  }
                },
                child: Text(T.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateTimeControls({
    required BuildContext pickerContext,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(DateFormat('dd/MM/yyyy', locale).format(value)),
          onPressed: () async {
            final firstDate = DateTime(1900);
            final lastDate = DateTime.now().add(const Duration(days: 365));
            final initialDate = value.isBefore(firstDate)
                ? firstDate
                : value.isAfter(lastDate)
                    ? lastDate
                    : value;
            final date = await showDatePicker(
              context: pickerContext,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (date != null) {
              onChanged(DateTime(
                date.year,
                date.month,
                date.day,
                value.hour,
                value.minute,
                value.second,
                value.millisecond,
                value.microsecond,
              ));
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.access_time),
          label: Text(DateFormat('HH:mm', locale).format(value)),
          onPressed: () async {
            final time = await showTimePicker(
              context: pickerContext,
              initialTime: TimeOfDay.fromDateTime(value),
            );
            if (time != null) {
              onChanged(DateTime(
                value.year,
                value.month,
                value.day,
                time.hour,
                time.minute,
                value.second,
                value.millisecond,
                value.microsecond,
              ));
            }
          },
        ),
      ],
    );
  }

  void _toggleTransactionSelection(TransactionModel tx) {
    setState(() {
      if (!_selectedTransactionIds.add(tx.id)) {
        _selectedTransactionIds.remove(tx.id);
      }
      _selectedChartCategory = null;
    });
  }

  void _clearTransactionSelection() {
    if (_selectedTransactionIds.isEmpty) return;
    setState(() {
      _selectedTransactionIds.clear();
      _selectedChartCategory = null;
    });
  }

  Widget _buildSelectionBar(String selectedNetLabel) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 4,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: colors.primary.withValues(alpha: .12),
            child:
                Icon(Icons.checklist_rounded, color: colors.primary, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${_selectedTransactionIds.length} ${T.get('selectedTransactions')}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${T.get('selectedNet')}: $selectedNetLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          IconButton(
              tooltip: T.get('editSelected'),
              onPressed: _showBulkEditSheet,
              icon: const Icon(Icons.edit_note_rounded)),
          IconButton(
              tooltip: T.get('delete'),
              onPressed: _deleteSelectedTransactions,
              color: colors.error,
              icon: const Icon(Icons.delete_sweep_outlined)),
          IconButton(
              tooltip: T.get('cancel'),
              onPressed: _clearTransactionSelection,
              icon: const Icon(Icons.close_rounded)),
        ]),
      ),
    );
  }

  Future<void> _deleteSelectedTransactions() async {
    final ids = _selectedTransactionIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: Text(T.get('deleteConfirmTitle')),
        content: Text(T
            .get('deleteSelectedConfirmContent')
            .replaceAll('{count}', ids.length.toString())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(T.get('cancel'))),
          FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: Text(T.get('moveToTrash'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      for (var i = 0; i < ids.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in ids.skip(i).take(400)) {
          batch.update(_transactionsCollection.doc(id),
              {'deletedAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }
      if (!mounted) return;
      setState(() => _selectedTransactionIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            T
                .get('deleteSelectedSuccess')
                .replaceAll('{count}', ids.length.toString()),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(T.get('saveError'))));
    }
  }

  void _showBulkEditSheet() {
    if (_selectedTransactionIds.isEmpty) return;
    var selectedCategory = _categoryIcons.keys.first;
    var selectedPayment = _paymentIcons.keys.first;
    final selectedTransactions = _selectedTransactionIds
        .map((id) => _cachedTransactionsById[id])
        .whereType<TransactionModel>()
        .toList();
    var selectedDateTime = selectedTransactions.isEmpty
        ? DateTime.now()
        : selectedTransactions.first.date;
    var changeCategory = false;
    var changePayment = false;
    var changeDateTime = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom +
                MediaQuery.viewPaddingOf(sheetContext).bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .outlineVariant,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 18),
                Row(children: [
                  CircleAvatar(
                      backgroundColor:
                          Theme.of(sheetContext).colorScheme.primaryContainer,
                      child: Icon(Icons.edit_note_rounded,
                          color: Theme.of(sheetContext).colorScheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(T.get('editSelected'),
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                            '${_selectedTransactionIds.length} ${T.get('selectedTransactions')}',
                            style: Theme.of(sheetContext).textTheme.bodySmall),
                      ])),
                ]),
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.event_available_outlined,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                          title: Text(
                            T.get('changeDateTime'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          value: changeDateTime,
                          onChanged: (value) => setSheetState(
                            () => changeDateTime = value ?? false,
                          ),
                        ),
                        if (changeDateTime)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              right: 4,
                              bottom: 8,
                            ),
                            child: _buildDateTimeControls(
                              pickerContext: sheetContext,
                              value: selectedDateTime,
                              onChanged: (value) => setSheetState(
                                () => selectedDateTime = value,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(Icons.category_outlined,
                                color:
                                    Theme.of(sheetContext).colorScheme.primary),
                            title: Text(T.get('changeCategory'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            value: changeCategory,
                            onChanged: (value) => setSheetState(
                                () => changeCategory = value ?? false),
                          ),
                          if (changeCategory)
                            Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, right: 4, bottom: 8),
                                child: _buildCategoryField(
                                  selected: selectedCategory,
                                  setModalState: setSheetState,
                                  onChanged: (value) => setSheetState(() =>
                                      selectedCategory =
                                          value ?? selectedCategory),
                                  outlined: true,
                                )),
                        ]))),
                const SizedBox(height: 12),
                Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Theme.of(sheetContext)
                                    .colorScheme
                                    .tertiary),
                            title: Text(T.get('changePayment'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            value: changePayment,
                            onChanged: (value) => setSheetState(
                                () => changePayment = value ?? false),
                          ),
                          if (changePayment)
                            Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, right: 4, bottom: 8),
                                child: _buildPaymentField(
                                  selected: selectedPayment,
                                  setModalState: setSheetState,
                                  onChanged: (value) => setSheetState(() =>
                                      selectedPayment =
                                          value ?? selectedPayment),
                                  outlined: true,
                                )),
                        ]))),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                          label: Text(T.get('cancel')))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton.icon(
                    onPressed: !changeCategory &&
                            !changePayment &&
                            !changeDateTime
                        ? null
                        : () async {
                            final updatedAt = DateTime.now().toIso8601String();
                            final ids = _selectedTransactionIds.toList();
                            try {
                              for (var start = 0;
                                  start < ids.length;
                                  start += 450) {
                                final chunk = ids.skip(start).take(450);
                                final chunkBatch =
                                    FirebaseFirestore.instance.batch();
                                for (final id in chunk) {
                                  final updates = <String, dynamic>{
                                    'updatedAt': updatedAt,
                                  };
                                  if (changeDateTime) {
                                    updates['date'] =
                                        selectedDateTime.toIso8601String();
                                  }
                                  if (changeCategory) {
                                    updates['category'] = selectedCategory;
                                  }
                                  if (changePayment) {
                                    updates['paymentMethod'] = selectedPayment;
                                  }
                                  chunkBatch.update(
                                    _transactionsCollection.doc(id),
                                    updates,
                                  );
                                }
                                await chunkBatch.commit();
                              }
                              if (mounted) {
                                setState(() => _selectedTransactionIds.clear());
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (_) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text(T.get('saveError'))),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(T.get('save')),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTransactionSheet(
    BuildContext context, {
    bool scanSlipOnOpen = false,
  }) {
    if (scanSlipOnOpen) {
      unawaited(_showSlipInboxSheet());
      return;
    }

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    bool isExpense = true;
    bool isReadingSlip = false;
    DateTime transactionDate = DateTime.now();
    Uint8List? slipImageBytes;
    String? transactionNumber;
    String? slipMessage;
    String selectedCategory = _categoryIcons.keys.first;
    String selectedPaymentMethod = _paymentIcons.keys.first;
    var startedSlipScan = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> readSlip() async {
              if (kIsWeb ||
                  (defaultTargetPlatform != TargetPlatform.android &&
                      defaultTargetPlatform != TargetPlatform.iOS)) {
                setModalState(() => slipMessage = T.get('slipOcrUnsupported'));
                return;
              }

              final source = await showModalBottomSheet<ImageSource>(
                context: context,
                showDragHandle: true,
                builder: (sourceContext) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: Text(T.get('takeSlipPhoto')),
                        onTap: () =>
                            Navigator.pop(sourceContext, ImageSource.camera),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: Text(T.get('chooseSlipImage')),
                        onTap: () =>
                            Navigator.pop(sourceContext, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              );
              if (source == null || !ctx.mounted) return;

              setModalState(() {
                isReadingSlip = true;
                slipMessage = T.get('slipOcrProcessing');
              });
              try {
                final image = await ImagePicker().pickImage(
                  source: source,
                  imageQuality: 100,
                );
                if (image == null || !ctx.mounted) {
                  if (ctx.mounted) {
                    setModalState(() {
                      isReadingSlip = false;
                      slipMessage = null;
                    });
                  }
                  return;
                }

                final imageBytes = await image.readAsBytes();
                final textRecognizer = TextRecognizer();
                late final String recognizedText;
                try {
                  final result = await textRecognizer.processImage(
                    InputImage.fromFilePath(image.path),
                  );
                  recognizedText = result.text;
                } finally {
                  await textRecognizer.close();
                }
                final result = SlipOcrParser.parse(recognizedText);
                if (!ctx.mounted) return;
                setModalState(() {
                  slipImageBytes = imageBytes;
                  if (result.amount != null) {
                    amountController.text = result.amount!.toStringAsFixed(2);
                  }
                  if (result.date != null) transactionDate = result.date!;
                  transactionNumber = result.transactionNumber;
                  slipMessage = result.amount == null
                      ? T.get('slipOcrNoAmount')
                      : T.get('slipOcrReview');
                  isReadingSlip = false;
                });
              } catch (error) {
                if (!ctx.mounted) return;
                setModalState(() {
                  isReadingSlip = false;
                  slipMessage = '${T.get('slipOcrFailed')}: $error';
                });
              }
            }

            if (scanSlipOnOpen && !startedSlipScan) {
              startedSlipScan = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) readSlip();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    16,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(T.get('addTransaction'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (scanSlipOnOpen) ...[
                      IconButton(
                        tooltip: T.get('scanSlip'),
                        onPressed: isReadingSlip ? null : readSlip,
                        icon: isReadingSlip
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.document_scanner_outlined),
                      ),
                      if (slipMessage != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            slipMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: slipMessage ==
                                              T.get('slipOcrNoAmount') ||
                                          slipMessage!.startsWith(
                                              T.get('slipOcrFailed'))
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ],
                      if (slipImageBytes != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            slipImageBytes!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: T.get('titleLabel'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: T.get('amountLabel'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(T.get('transactionDateTime')),
                    ),
                    _buildDateTimeControls(
                      pickerContext: context,
                      value: transactionDate,
                      onChanged: (value) =>
                          setModalState(() => transactionDate = value),
                    ),
                    const SizedBox(height: 8),
                    _buildCategoryField(
                      selected: selectedCategory,
                      outlined: true,
                      setModalState: setModalState,
                      onChanged: (val) =>
                          setModalState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentField(
                      selected: selectedPaymentMethod,
                      outlined: true,
                      setModalState: setModalState,
                      onChanged: (val) =>
                          setModalState(() => selectedPaymentMethod = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(T.get('typeLabel'),
                            style: const TextStyle(fontSize: 16)),
                        ChoiceChip(
                            label: Text(T.get('expense')),
                            selected: isExpense,
                            onSelected: (_) =>
                                setModalState(() => isExpense = true)),
                        ChoiceChip(
                            label: Text(T.get('income')),
                            selected: !isExpense,
                            onSelected: (_) =>
                                setModalState(() => isExpense = false)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white),
                        onPressed: () async {
                          final title = titleController.text.trim().isEmpty
                              ? ''
                              : titleController.text.trim();
                          if (title.isEmpty || amountController.text.isEmpty) {
                            return;
                          }
                          final amount = double.tryParse(
                            amountController.text.replaceAll(',', ''),
                          );
                          if (amount == null || amount <= 0) return;
                          try {
                            await _transactionsCollection.add({
                              'title': title,
                              'amount': amount,
                              'date': transactionDate.toIso8601String(),
                              'isExpense': isExpense ? 1 : 0,
                              'category': selectedCategory,
                              'paymentMethod': selectedPaymentMethod,
                              if (transactionNumber != null)
                                'transactionNo': transactionNumber,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (_) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(T.get('saveError'))),
                            );
                          }
                        },
                        child: Text(T.get('save'),
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isMatchFilters(TransactionModel tx, {String? paymentScope}) {
    if (tx.category == 'transfer') {
      if (!_selectedTypes.contains('transfer')) return false;
    } else {
      if (tx.isExpense && !_selectedTypes.contains('expense')) {
        return false;
      }
      if (!tx.isExpense && !_selectedTypes.contains('income')) {
        return false;
      }
    }

    if (_categoryFilterActive && !_selectedCategories.contains(tx.category)) {
      return false;
    }

    if (paymentScope == null &&
        _paymentFilterActive &&
        !_selectedPayments.contains(tx.paymentMethod)) {
      return false;
    }

    if (paymentScope != null && tx.paymentMethod != paymentScope) {
      return false;
    }

    return _matchesSearch(tx);
  }

  bool _matchesSearch(TransactionModel tx) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return true;

    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final searchableValues = [
      tx.title,
      tx.category,
      tx.paymentMethod,
      tx.amount.toString(),
      NumberFormat.decimalPattern(locale).format(tx.amount),
      DateFormat('dd/MM/yyyy', locale).format(tx.date),
      DateFormat('yyyy-MM-dd').format(tx.date),
      tx.id,
      tx.invoiceNo,
      tx.transactionNo,
      tx.customerName,
      tx.taxId,
      tx.branchCode,
    ];

    if (searchableValues.any(
      (value) => value.toLowerCase().contains(query),
    )) {
      return true;
    }

    final normalizedQuery = query.replaceAll(RegExp(r'[,฿$ ]'), '');
    if (normalizedQuery.isEmpty) return false;
    final searchableAmounts = [
      tx.amount.toString(),
      tx.amount.toStringAsFixed(2),
      NumberFormat.decimalPattern(locale).format(tx.amount),
    ];
    return searchableAmounts.any(
      (amount) => amount.replaceAll(',', '').contains(normalizedQuery),
    );
  }

  List<TransactionModel> _filterAndSort(
    List<TransactionModel> transactions, {
    String? paymentScope,
  }) {
    final result = transactions
        .where((tx) => _isMatchFilters(tx, paymentScope: paymentScope))
        .toList();

    result.sort((a, b) {
      switch (_sortOrder) {
        case 'newest':
          return b.date.compareTo(a.date);
        case 'oldest':
          return a.date.compareTo(b.date);
        case 'highest':
          return b.amount.compareTo(a.amount);
        case 'lowest':
          return a.amount.compareTo(b.amount);
        default:
          return 0;
      }
    });
    return result;
  }

  String _groupKey(TransactionModel tx) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    switch (_groupType) {
      case 'daily':
        return DateFormat('dd/MM/yyyy', locale).format(tx.date);
      case 'weekly':
        final startOfWeek =
            tx.date.subtract(Duration(days: tx.date.weekday - 1));
        return DateFormat('dd/MM/yyyy', locale).format(startOfWeek);
      case 'monthly':
        return DateFormat('MM/yyyy', locale).format(tx.date);
      case 'yearly':
        return DateFormat('yyyy', locale).format(tx.date);
      default:
        return DateFormat('yyyy', locale).format(tx.date);
    }
  }

  int _compareGroupKeys(String a, String b) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    switch (_groupType) {
      case 'daily':
      case 'weekly':
        final format = DateFormat('dd/MM/yyyy', locale);
        return format.parse(b).compareTo(format.parse(a));
      case 'monthly':
        final format = DateFormat('MM/yyyy', locale);
        return format.parse(b).compareTo(format.parse(a));
      case 'yearly':
        return int.parse(b).compareTo(int.parse(a));
      default:
        return 0;
    }
  }

  String _groupHeader(String key) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    switch (_groupType) {
      case 'daily':
        return '${T.get('date_prefix')} $key';
      case 'weekly':
        final start = DateFormat('dd/MM/yyyy', locale).parse(key);
        final end = start.add(const Duration(days: 6));
        return '${T.get('week_prefix')} $key - ${DateFormat('dd/MM/yyyy', locale).format(end)}';
      case 'monthly':
        return '${T.get('month_prefix')} $key';
      case 'yearly':
        return '${T.get('year_prefix')} $key';
      default:
        return key;
    }
  }

  List<dynamic> _buildListItems(List<TransactionModel> transactions) {
    if (_groupType == 'none' || transactions.isEmpty) return transactions;
    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in transactions) {
      grouped.putIfAbsent(_groupKey(tx), () => []).add(tx);
    }
    var sortedKeys = grouped.keys.toList()..sort(_compareGroupKeys);
    if (_sortOrder == 'oldest') sortedKeys = sortedKeys.reversed.toList();

    final List<dynamic> items = [];
    for (final key in sortedKeys) {
      items.add(_groupHeader(key));
      items.addAll(grouped[key]!);
    }
    return items;
  }

  Widget _buildPieChart(
    List<TransactionModel> transactions, {
    required double selectedNet,
  }) {
    final Map<String, double> categoryTotals = {};
    for (final tx in transactions) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0.0) + tx.amount;
    }
    final totalSum = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final selectedCategory = categoryTotals.containsKey(_selectedChartCategory)
        ? _selectedChartCategory
        : null;
    final selectedTotal =
        selectedCategory == null ? null : categoryTotals[selectedCategory];
    final selectedPercentage = selectedTotal == null || totalSum == 0
        ? 0.0
        : selectedTotal / totalSum * 100;

    final sections = categoryTotals.entries.map((entry) {
      final percentage = totalSum > 0 ? (entry.value / totalSum * 100) : 0.0;
      final isSelected = entry.key == selectedCategory;
      final isDimmed = selectedCategory != null && !isSelected;
      return PieChartSectionData(
        color: _colorOf(entry.key).withValues(alpha: isDimmed ? 0.2 : 1),
        value: entry.value,
        title: '',
        radius: isSelected ? 72 : 65,
        badgeWidget: (selectedCategory == null && percentage >= 6.0) ||
                (isSelected && percentage >= 6.0)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_iconOf(entry.key), color: Colors.white, size: 18),
                  const SizedBox(height: 2),
                  Text('${percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              )
            : const SizedBox.shrink(),
        badgePositionPercentageOffset: 0.5,
      );
    }).toList();
    if (totalSum <= 0) {
      sections.clear();
      sections.add(
        PieChartSectionData(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          value: 1,
          title: '',
          radius: 65,
        ),
      );
    }

    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final centerContent = _selectedTransactionIds.isNotEmpty
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                T.get('selectedNet'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberFormat.currency(
                    locale: locale,
                    symbol: '฿',
                    decimalDigits: 2,
                  ).format(selectedNet),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        : selectedCategory == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconOf(selectedCategory),
                      size: 16, color: _colorOf(selectedCategory)),
                  const SizedBox(height: 2),
                  Text(
                    selectedCategory,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${NumberFormat.currency(
                        locale: locale,
                        symbol: '฿',
                        decimalDigits: 2,
                      ).format(selectedTotal)} · ${selectedPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ],
              );

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 54,
                  sections: sections,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      if (index == null ||
                          index < 0 ||
                          index >= categoryTotals.length) {
                        return;
                      }
                      final category = categoryTotals.keys.elementAt(index);
                      final focusedCategoryAtPointerDown =
                          _focusedCategoryAtPointerDown;
                      _focusedCategoryAtPointerDown = null;
                      setState(() {
                        _selectedChartCategory =
                            focusedCategoryAtPointerDown == category
                                ? null
                                : category;
                      });
                    },
                  ),
                ),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeInOutCubic,
              ),
              IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    key: ValueKey<String>(
                      _selectedTransactionIds.isNotEmpty
                          ? 'selected-net'
                          : 'category-${selectedCategory ?? 'all'}',
                    ),
                    width: 104,
                    child: centerContent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGroupHeaderWidget(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 16, top: 16, bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }

  void _handleDelete(BuildContext context, TransactionModel tx) {
    setState(() => _pendingDeleteIds.add(tx.id));
    bool isUndone = false;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    late final Timer autoDismissTimer;
    final snackBar = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        content: Text(
          '${T.get('deleted')} ${tx.title}',
          style: const TextStyle(color: Colors.white),
        ),
        action: SnackBarAction(
          label: T.get('undo'),
          textColor: Colors.amberAccent,
          onPressed: () {
            isUndone = true;
            autoDismissTimer.cancel();
            setState(() => _pendingDeleteIds.remove(tx.id));
          },
        ),
      ),
    );
    autoDismissTimer = Timer(const Duration(seconds: 5), () {
      if (!isUndone) snackBar.close();
    });
    snackBar.closed.then((reason) {
      autoDismissTimer.cancel();
      if (!isUndone && reason != SnackBarClosedReason.action) {
        _transactionsCollection
            .doc(tx.id)
            .update({'deletedAt': FieldValue.serverTimestamp()});
        _pendingDeleteIds.remove(tx.id);
      }
    });
  }

  Future<void> _hideTransactionFromDashboard(
      BuildContext context, TransactionModel tx,
      {required bool hidden}) async {
    try {
      await _transactionsCollection
          .doc(tx.id)
          .update({'hiddenFromDashboard': hidden});
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(T.get('saveError'))),
      );
    }
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel tx) {
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final formattedAmount = NumberFormat('#,##0.00', locale).format(tx.amount);
    final formattedDate =
        DateFormat('dd/MM/yyyy HH:mm', locale).format(tx.date);
    final amountColor = tx.isExpense ? Colors.red : Colors.green;

    final isCategoryValid =
        _categoryIcons.containsKey(tx.category) || tx.category == 'transfer';
    final isPaymentValid = _paymentIcons.containsKey(tx.paymentMethod);

    final categoryColor = isCategoryValid ? _colorOf(tx.category) : Colors.red;
    final categoryIcon =
        isCategoryValid ? _iconOf(tx.category) : Icons.help_outline;
    final paymentIcon =
        isPaymentValid ? _paymentIconOf(tx.paymentMethod) : Icons.help_outline;
    final paymentColor =
        isPaymentValid ? _paymentColorOf(tx.paymentMethod) : Colors.red;
    final isSelected = _selectedTransactionIds.contains(tx.id);
    final isHidden = tx.hiddenFromDashboard;
    final isSelecting = _selectedTransactionIds.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    final mutedColor = colors.onSurfaceVariant.withValues(alpha: 0.68);

    return Dismissible(
      key: ValueKey(tx.id),
      direction:
          isSelecting ? DismissDirection.none : DismissDirection.horizontal,
      background: Container(
        color: colors.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            Icon(
              isHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(T.get(isHidden ? 'showOnDashboard' : 'hideFromDashboard'),
                style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            const SizedBox(width: 8),
            Text(T.get('delete'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _hideTransactionFromDashboard(
            context,
            tx,
            hidden: !isHidden,
          );
          return false;
        }
        return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(T.get('deleteConfirmTitle')),
                content: Text(T.get('deleteConfirmContent')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(T.get('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(T.get('delete')),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _handleDelete(context, tx),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _toggleTransactionSelection(tx),
        onTap: () {
          if (isSelecting) {
            _toggleTransactionSelection(tx);
          } else {
            _showEditDialog(tx);
          }
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isHidden
              ? colors.surfaceContainerHighest.withValues(alpha: 0.72)
              : (isSelected ? colors.primaryContainer : null),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: colors.primary.withValues(alpha: 0.6))
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected && !isHidden
                  ? colors.primary
                  : mutedColor.withValues(alpha: 0.16),
              child: Icon(
                isSelected && !isHidden ? Icons.check_rounded : categoryIcon,
                color: isHidden
                    ? mutedColor
                    : (isSelected ? colors.onPrimary : categoryColor),
              ),
            ),
            title: Text(
              tx.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHidden ? mutedColor : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedDate,
                    style: isHidden ? TextStyle(color: mutedColor) : null),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(categoryIcon,
                        size: 14, color: isHidden ? mutedColor : categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      tx.category == 'transfer'
                          ? T.get('transfer')
                          : (isCategoryValid ? tx.category : tx.category),
                      style: TextStyle(
                          fontSize: 12,
                          color: isHidden ? mutedColor : categoryColor,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(' • '),
                    Icon(paymentIcon,
                        size: 14, color: isHidden ? mutedColor : paymentColor),
                    const SizedBox(width: 4),
                    Text(
                      tx.paymentMethod,
                      style: TextStyle(
                          fontSize: 12,
                          color: isHidden ? mutedColor : paymentColor),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tx.isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isHidden ? mutedColor : amountColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tx.isExpense ? '-' : '+'}$formattedAmount ฿',
                  style: TextStyle(
                      color: isHidden ? mutedColor : amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<TransactionModel> allTransactions, {
    String? paymentScope,
  }) {
    final isSelecting = _selectedTransactionIds.isNotEmpty;
    if (!identical(_cachedAccountSource, allTransactions) ||
        _cachedAccountScope != paymentScope) {
      _cachedAccountSource = allTransactions;
      _cachedAccountScope = paymentScope;
      _cachedAccountTransactions = paymentScope == null
          ? allTransactions.where((tx) => !tx.hiddenFromDashboard).toList()
          : allTransactions
              .where((tx) =>
                  tx.paymentMethod == paymentScope && !tx.hiddenFromDashboard)
              .toList();
      _cachedGroupSource = null;
    }
    final accountTransactions = _cachedAccountTransactions;

    if (!identical(_cachedGroupSource, accountTransactions) ||
        _cachedGroupType != _groupType) {
      _cachedGroupSource = accountTransactions;
      _cachedGroupType = _groupType;
      if (_groupType != 'none' && accountTransactions.isNotEmpty) {
        final latestKey = _groupKey(accountTransactions.first);
        _cachedGroupTransactions = accountTransactions
            .where((tx) => _groupKey(tx) == latestKey)
            .toList();
      } else {
        _cachedGroupTransactions = accountTransactions;
      }
      _cachedVisibleSource = null;
    }

    final typeKey = _selectedTypes.toList()..sort();
    final categoryKey = _selectedCategories.toList()..sort();
    final paymentKey = _selectedPayments.toList()..sort();
    final visibleKey = jsonEncode([
      paymentScope,
      _sortOrder,
      _groupType,
      typeKey,
      _categoryFilterActive,
      categoryKey,
      _paymentFilterActive,
      paymentKey,
      _searchQuery.toLowerCase(),
      languageNotifier.value,
    ]);
    if (!identical(_cachedVisibleSource, allTransactions) ||
        _cachedVisibleKey != visibleKey) {
      _cachedVisibleSource = allTransactions;
      _cachedVisibleKey = visibleKey;
      _cachedVisibleTransactions =
          _filterAndSort(allTransactions, paymentScope: paymentScope);
      _cachedVisibleListItems = _buildListItems(_cachedVisibleTransactions);
      _cachedFilteredScopeTransactions = _cachedGroupTransactions
          .where((tx) => _isMatchFilters(tx, paymentScope: paymentScope))
          .toList();
    }
    final filteredScopeTransactions = _cachedFilteredScopeTransactions;
    final selectedTransactions = _selectedTransactionIds
        .map((id) => _cachedTransactionsById[id])
        .whereType<TransactionModel>()
        .where((tx) => !tx.hiddenFromDashboard)
        .where((tx) => paymentScope == null || tx.paymentMethod == paymentScope)
        .toList();
    final allFilteredTx =
        isSelecting ? selectedTransactions : filteredScopeTransactions;
    final filteredForStats =
        allFilteredTx.where((tx) => tx.category != 'transfer').toList();

    final totalIncome = filteredForStats
        .where((tx) => !tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);
    final totalExpense = filteredForStats
        .where((tx) => tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);

    final realIncome = allFilteredTx
        .where((tx) => !tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);
    final realExpense = allFilteredTx
        .where((tx) => tx.isExpense)
        .fold(0.0, (total, tx) => total + tx.amount);
    final realBalance = realIncome - realExpense;
    final selectedNet = selectedTransactions.fold<double>(
      0,
      (total, tx) => total + (tx.isExpense ? -tx.amount : tx.amount),
    );

    // Keep the full filtered list visible during selection so more rows can be
    // tapped and added; only the dashboard totals are based on selected rows.
    final listItems = _cachedVisibleListItems;
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';
    final selectedNetLabel = NumberFormat.currency(
      locale: locale,
      symbol: '฿',
      decimalDigits: 2,
    ).format(selectedNet);

    return CustomScrollView(
      controller: _dashboardScrollController,
      slivers: [
        if (isSelecting)
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedSelectionHeader(
              height: 76,
              child: _buildSelectionBar(selectedNetLabel),
            ),
          ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildAccountOverview(
                paymentScope: paymentScope,
                accountTransactions:
                    isSelecting ? selectedTransactions : accountTransactions,
                chartTransactions: filteredForStats,
                income: totalIncome,
                expense: totalExpense,
                balance: realBalance,
                selectedNet: isSelecting ? selectedNet : 0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(T.get('history'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildFilterBar(),
              const SizedBox(height: 8),
              _buildSearchField(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        listItems.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text(
                        accountTransactions.isEmpty
                            ? T.get('noData')
                            : T.get('noMatch'),
                        style: const TextStyle(color: Colors.grey))),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = listItems[index];
                    if (item is String) return _buildGroupHeaderWidget(item);
                    return _buildTransactionItem(
                        context, item as TransactionModel);
                  },
                  childCount: listItems.length,
                ),
              ),
      ],
    );
  }

  Widget _buildPaymentPageSelector(List<String> payments) {
    final selectedIndex =
        _selectedPaymentPage.clamp(0, payments.length).toInt();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface,
          border:
              Border.all(color: colors.outlineVariant.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedIndex,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  menuMaxHeight: 400,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: colors.onSurfaceVariant),
                  items: [
                    DropdownMenuItem<int>(
                      value: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 20, color: colors.primary),
                          const SizedBox(width: 10),
                          Text(T.get('primaryPayment')),
                          const SizedBox(width: 8),
                          Text(
                            '· ${T.get('allAccounts')}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var index = 0; index < payments.length; index++)
                      DropdownMenuItem<int>(
                        value: index + 1,
                        child: Row(
                          children: [
                            Icon(_paymentIconOf(payments[index]),
                                size: 20,
                                color: _paymentColorOf(payments[index])),
                            const SizedBox(width: 10),
                            Text(
                              payments[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (index) {
                    if (index == null) return;
                    _selectPaymentAccount(
                      index,
                      slideDirection: index >= selectedIndex ? 1 : -1,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileHeader({required double? currentBalance}) {
    final username = GuestService.username?.trim() ?? '';
    final displayName = username.isEmpty ? T.get('guestMode') : username;
    final colors = Theme.of(context).colorScheme;
    final locale = languageNotifier.value == 'th' ? 'th' : 'en';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: username.isEmpty
                ? const Icon(Icons.person_outline)
                : Text(
                    String.fromCharCode(username.runes.first).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  T.get('currentBalance'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                Text(
                  currentBalance == null
                      ? '--'
                      : NumberFormat.currency(
                          locale: locale,
                          symbol: '฿',
                          decimalDigits: 2,
                        ).format(currentBalance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardSkeleton() {
    final skeletonColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block({double? width, required double height, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: skeletonColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(child: block(width: 176, height: 176, radius: 88)),
        const SizedBox(height: 24),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(height: 12, width: 62),
                    const SizedBox(height: 10),
                    block(height: 22),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        block(height: 18, width: 150),
        const SizedBox(height: 12),
        for (var index = 0; index < 5; index++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: skeletonColor.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                block(width: 42, height: 42, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(height: 14, width: 132),
                      const SizedBox(height: 8),
                      block(height: 11, width: 92),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                block(height: 16, width: 68),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, child) {
        return Listener(
          onPointerDown: (_) {
            _focusedCategoryAtPointerDown = _selectedChartCategory;
            if (_selectedChartCategory != null) {
              setState(() => _selectedChartCategory = null);
            }
          },
          onPointerCancel: (_) => _focusedCategoryAtPointerDown = null,
          child: Scaffold(
            appBar: AppBar(
              title: Text(T.get('appTitle')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: T.get('transferBetweenAccounts'),
                  onPressed: () => _showTransferSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: T.get('settings'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                    if (mounted) {
                      setState(() => _selectedPaymentPage = 0);
                    }
                    _loadCustomSettings();
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _transactionsStream,
                      builder: (context, snapshot) {
                        final paymentSelector = _buildPaymentPageSelector(
                          _paymentIcons.keys.toList(),
                        );
                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              _buildUserProfileHeader(currentBalance: null),
                              paymentSelector,
                              Expanded(
                                child: Center(child: Text(T.get('loadError'))),
                              ),
                            ],
                          );
                        }
                        if (!snapshot.hasData) {
                          return Column(
                            children: [
                              _buildUserProfileHeader(currentBalance: null),
                              paymentSelector,
                              Expanded(child: _buildDashboardSkeleton()),
                            ],
                          );
                        }

                        final querySnapshot = snapshot.data!;
                        if (!identical(_cachedSnapshot, querySnapshot)) {
                          _cachedSnapshot = querySnapshot;
                          _cachedParsedTransactions = querySnapshot.docs
                              .where((doc) =>
                                  (doc.data()
                                      as Map<String, dynamic>)['deletedAt'] ==
                                  null)
                              .map((doc) {
                            final data = Map<String, dynamic>.from(
                                doc.data() as Map<String, dynamic>);
                            data['id'] = doc.id;
                            return TransactionModel.fromMap(data);
                          }).toList();
                          _cachedPendingDeleteKey = null;
                        }
                        final pendingDeleteKey =
                            (_pendingDeleteIds.toList()..sort()).join('\u0000');
                        if (_cachedPendingDeleteKey != pendingDeleteKey) {
                          _cachedPendingDeleteKey = pendingDeleteKey;
                          _cachedAvailableTransactions =
                              _cachedParsedTransactions
                                  .where((tx) =>
                                      !_pendingDeleteIds.contains(tx.id))
                                  .toList();
                          _cachedTransactionsById
                            ..clear()
                            ..addEntries(_cachedAvailableTransactions
                                .map((tx) => MapEntry(tx.id, tx)));
                        }
                        final allTransactions = _cachedAvailableTransactions;

                        final payments = _paymentIcons.keys.toList();
                        final selectedIndex = _selectedPaymentPage
                            .clamp(0, payments.length)
                            .toInt();
                        final paymentScope = selectedIndex == 0
                            ? null
                            : payments[selectedIndex - 1];
                        final accountTransactions = allTransactions.where(
                          (tx) =>
                              !tx.hiddenFromDashboard &&
                              (paymentScope == null ||
                                  tx.paymentMethod == paymentScope),
                        );
                        final currentBalance = accountTransactions.fold<double>(
                          0,
                          (total, tx) =>
                              total + (tx.isExpense ? -tx.amount : tx.amount),
                        );
                        return Column(
                          children: [
                            _buildUserProfileHeader(
                              currentBalance: currentBalance,
                            ),
                            paymentSelector,
                            Expanded(
                              child: _buildContent(
                                allTransactions,
                                paymentScope: paymentScope,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'addFromSlipFab',
                  tooltip: T.get('scanSlip'),
                  onPressed: () => _showAddTransactionSheet(
                    context,
                    scanSlipOnOpen: true,
                  ),
                  child: const Icon(Icons.document_scanner_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'addTransactionFab',
                  onPressed: () => _showAddTransactionSheet(context),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PinnedSelectionHeader extends SliverPersistentHeaderDelegate {
  const _PinnedSelectionHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(covariant _PinnedSelectionHeader oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}
