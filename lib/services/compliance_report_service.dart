import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../models/pdf_colour_scheme.dart';
import 'auth_service.dart';
import 'asset_service.dart';
import 'asset_type_service.dart';
import 'service_history_service.dart';
import 'floor_plan_service.dart';
import 'jobsheet_settings_service.dart';
import 'company_pdf_config_service.dart';
import 'pdf_generation_data.dart';
import 'pdf_footer_builder.dart';

// ── Colour constants for the isolate ──
const _white = PdfColors.white;
const _lightGray = PdfColor.fromInt(0xFFE0E0E0);
const _passGreen = PdfColor.fromInt(0xFF4CAF50);
const _failRed = PdfColor.fromInt(0xFFD32F2F);
const _untestedAmber = PdfColor.fromInt(0xFFF97316);

/// Top-level function for compute() — builds the compliance report PDF.
Future<Uint8List> _buildComplianceReport(ComplianceReportPdfData data) async {
  final footerConfig = PdfFooterConfig.fromJson(data.footerConfigJson);
  final colourScheme =
      PdfColourScheme(primaryColorValue: data.colourSchemeValue);
  final primaryColor = colourScheme.primaryColor;
  final primaryLight = colourScheme.primaryLight;

  final regularFont = data.regularFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.regularFontBytes!))
      : pw.Font.helvetica();
  final boldFont = data.boldFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.boldFontBytes!))
      : pw.Font.helveticaBold();

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  final assets = data.assetsJson.map((j) => Asset.fromJson(j)).toList();
  final assetTypes =
      data.assetTypesJson.map((j) => AssetType.fromJson(j)).toList();
  final records =
      data.serviceRecordsJson.map((j) => ServiceRecord.fromJson(j)).toList();
  final floorPlans =
      data.floorPlansJson.map((j) => FloorPlan.fromJson(j)).toList();

  final active =
      assets.where((a) => a.complianceStatus != Asset.statusDecommissioned).toList();
  final decom =
      assets.where((a) => a.complianceStatus == Asset.statusDecommissioned).toList();
  final pass =
      active.where((a) => a.complianceStatus == Asset.statusPass).toList();
  final fail =
      active.where((a) => a.complianceStatus == Asset.statusFail).toList();
  final untested =
      active.where((a) => a.complianceStatus == Asset.statusUntested).toList();

  AssetType? getType(String typeId) {
    try {
      return assetTypes.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return null;
    }
  }

  // ── Section 1: Cover Page ──
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (data.logoBytes != null)
            pw.Image(pw.MemoryImage(data.logoBytes!),
                width: 120, height: 60, fit: pw.BoxFit.contain),
          if (data.logoBytes != null) pw.SizedBox(height: 40),
          pw.Text(
            'SITE COMPLIANCE REPORT',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            width: 60,
            height: 3,
            color: primaryColor,
          ),
          pw.SizedBox(height: 24),
          pw.Text(data.siteName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(data.siteAddress,
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 32),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _coverField('Date', data.reportDate),
              pw.SizedBox(width: 40),
              _coverField('Engineer', data.engineerName),
            ],
          ),
          if (data.companyName.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _coverField('Company', data.companyName),
          ],
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _statBox('Total', '${assets.length}', primaryColor),
              _statBox('Pass', '${pass.length}', _passGreen),
              _statBox('Fail', '${fail.length}', _failRed),
              _statBox('Untested', '${untested.length}', _untestedAmber),
            ],
          ),
        ],
      ),
    ),
  );

  // ── Sections 2-7: Multi-page content ──
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => PdfFooterBuilder.buildFooter(
        config: footerConfig,
        pageNumber: context.pageNumber,
        pagesCount: context.pagesCount,
        primaryColor: primaryColor,
      ),
      build: (context) {
        final widgets = <pw.Widget>[];

        // ── Section 2: Compliance Summary ──
        widgets.add(_sectionHeader('Compliance Summary', primaryColor));
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Text(
          '${assets.length} total assets (${active.length} active, ${decom.length} decommissioned)',
          style: const pw.TextStyle(fontSize: 10),
        ));
        widgets.add(pw.SizedBox(height: 8));

        // Bar chart
        final total = active.length.clamp(1, double.maxFinite.toInt());
        widgets.add(pw.Container(
          height: 20,
          decoration: pw.BoxDecoration(
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Row(
              children: [
                if (pass.isNotEmpty)
                  pw.Expanded(
                    flex: pass.length,
                    child: pw.Container(color: _passGreen),
                  ),
                if (fail.isNotEmpty)
                  pw.Expanded(
                    flex: fail.length,
                    child: pw.Container(color: _failRed),
                  ),
                if (untested.isNotEmpty)
                  pw.Expanded(
                    flex: untested.length,
                    child: pw.Container(color: _untestedAmber),
                  ),
              ],
            ),
          ),
        ));
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(pw.Row(
          children: [
            _legendDot(_passGreen, 'Pass ${pass.length} (${(pass.length / total * 100).toStringAsFixed(0)}%)'),
            pw.SizedBox(width: 16),
            _legendDot(_failRed, 'Fail ${fail.length} (${(fail.length / total * 100).toStringAsFixed(0)}%)'),
            pw.SizedBox(width: 16),
            _legendDot(_untestedAmber, 'Untested ${untested.length} (${(untested.length / total * 100).toStringAsFixed(0)}%)'),
          ],
        ));
        widgets.add(pw.SizedBox(height: 16));

        // ── Section 3: Floor Plans ──
        for (final plan in floorPlans) {
          final imageBytes = data.floorPlanImages[plan.id];
          if (imageBytes == null) continue;

          widgets.add(_sectionHeader('Floor Plan: ${plan.name}', primaryColor));
          widgets.add(pw.SizedBox(height: 6));

          // Build pin overlays
          final planAssets =
              active.where((a) => a.floorPlanId == plan.id).toList();

          // Calculate rendered image area within the container
          // Container: full content width (~547pt) x 300pt, image uses BoxFit.contain
          const containerHeight = 300.0;
          const containerWidth = 547.0; // A4 (595.28) - 2*24 margins
          final pinSize = 8.0 * plan.pinScale;

          final imageAspect = plan.imageWidth / plan.imageHeight;
          final containerAspect = containerWidth / containerHeight;

          double renderW, renderH, offsetX, offsetY;
          if (imageAspect > containerAspect) {
            // Image wider than container — pillarboxed vertically
            renderW = containerWidth;
            renderH = containerWidth / imageAspect;
            offsetX = 0;
            offsetY = (containerHeight - renderH) / 2;
          } else {
            // Image taller — letterboxed horizontally
            renderH = containerHeight;
            renderW = containerHeight * imageAspect;
            offsetX = (containerWidth - renderW) / 2;
            offsetY = 0;
          }

          widgets.add(pw.Container(
            height: containerHeight,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _lightGray),
            ),
            child: pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Image(pw.MemoryImage(imageBytes),
                      fit: pw.BoxFit.contain),
                ),
                ...planAssets.map((a) {
                  if (a.xPercent == null || a.yPercent == null) {
                    return pw.SizedBox();
                  }
                  final statusColor = a.complianceStatus == Asset.statusPass
                      ? _passGreen
                      : a.complianceStatus == Asset.statusFail
                          ? _failRed
                          : _untestedAmber;

                  final pinDot = pw.Container(
                    width: pinSize,
                    height: pinSize,
                    decoration: pw.BoxDecoration(
                      color: statusColor,
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(
                          color: PdfColors.white, width: 1.0),
                    ),
                  );

                  final hasLabel = plan.showLabels &&
                      a.reference != null &&
                      a.reference!.isNotEmpty;
                  final labelFontSize = 5.0 * plan.pinScale;

                  return pw.Positioned(
                    left: offsetX + a.xPercent! * renderW - pinSize / 2,
                    top: offsetY + a.yPercent! * renderH - pinSize / 2 -
                        (hasLabel ? labelFontSize + 4 : 0),
                    child: hasLabel
                        ? pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius:
                                      pw.BorderRadius.circular(2),
                                  border: pw.Border.all(
                                      color: _lightGray, width: 0.5),
                                ),
                                child: pw.Text(
                                  a.reference!,
                                  style: pw.TextStyle(
                                    fontSize: labelFontSize,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pinDot,
                            ],
                          )
                        : pinDot,
                  );
                }),
              ],
            ),
          ));

          // Legend for this floor plan
          final typeIds = planAssets.map((a) => a.assetTypeId).toSet();
          if (typeIds.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(pw.Wrap(
              spacing: 12,
              runSpacing: 4,
              children: typeIds.map((tid) {
                final type = getType(tid);
                final color = type != null
                    ? PdfColor.fromHex(type.defaultColor)
                    : primaryColor;
                return pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: color,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.SizedBox(width: 3),
                    pw.Text(type?.name ?? tid,
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                );
              }).toList(),
            ));
          }

          widgets.add(pw.SizedBox(height: 12));
        }

        // ── Section 4: Asset Register Table ──
        widgets.add(_sectionHeader('Asset Register', primaryColor));
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(_tableHeader(
            ['Ref', 'Type', 'Location', 'Zone', 'Status', 'Last Service', 'Lifespan'],
            [2, 3, 3, 2, 2, 2, 2],
            primaryLight));

        for (int i = 0; i < active.length; i++) {
          final a = active[i];
          final type = getType(a.assetTypeId);
          final dateFormat = DateFormat('dd/MM/yy');
          final lastService =
              a.lastServiceDate != null ? dateFormat.format(a.lastServiceDate!) : '-';
          final lifespan = a.expectedLifespanYears != null
              ? '${a.expectedLifespanYears}y'
              : '-';
          final statusLabel = a.complianceStatus == Asset.statusPass
              ? 'PASS'
              : a.complianceStatus == Asset.statusFail
                  ? 'FAIL'
                  : 'UNTESTED';
          final statusColor = a.complianceStatus == Asset.statusPass
              ? _passGreen
              : a.complianceStatus == Asset.statusFail
                  ? _failRed
                  : _untestedAmber;

          widgets.add(_tableRow(
            [
              a.reference ?? '-',
              type?.name ?? '-',
              a.locationDescription ?? '-',
              a.zone ?? '-',
              statusLabel,
              lastService,
              lifespan,
            ],
            [2, 3, 3, 2, 2, 2, 2],
            isAlt: i.isOdd,
            primaryLight: primaryLight,
            statusIndex: 4,
            statusColor: statusColor,
          ));
        }
        widgets.add(pw.SizedBox(height: 16));

        // ── Section 5: Defect Summary ──
        final failedRecords = records
            .where((r) =>
                r.overallResult == 'fail' &&
                r.defectNote != null &&
                r.defectNote!.isNotEmpty)
            .toList();

        if (failedRecords.isNotEmpty) {
          widgets.add(_sectionHeader('Defect Summary', primaryColor));
          widgets.add(pw.SizedBox(height: 4));

          for (final record in failedRecords) {
            final asset =
                assets.where((a) => a.id == record.assetId).firstOrNull;
            final type = asset != null ? getType(asset.assetTypeId) : null;

            final severityLabel = record.defectSeverity?.toUpperCase() ?? 'N/A';
            final severityColor = record.defectSeverity == 'critical'
                ? _failRed
                : record.defectSeverity == 'major'
                    ? _untestedAmber
                    : PdfColors.grey600;

            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _lightGray),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${asset?.reference ?? '-'} — ${type?.name ?? 'Unknown'}',
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: severityColor,
                          borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(4)),
                        ),
                        child: pw.Text(severityLabel,
                            style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: _white)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(record.defectNote ?? '',
                      style: const pw.TextStyle(fontSize: 8)),
                  if (record.defectAction != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Action: ${record.defectAction!.replaceAll('_', ' ')}',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700),
                    ),
                  ],
                  // Defect photos
                  if (record.defectPhotoUrls.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: record.defectPhotoUrls
                          .take(3)
                          .map((url) {
                        final photoBytes =
                            data.defectPhotos[url.hashCode.toString()];
                        if (photoBytes == null) return pw.SizedBox.shrink();
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 4),
                          child: pw.Image(pw.MemoryImage(photoBytes),
                              width: 60, height: 45, fit: pw.BoxFit.cover),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ));
          }
          widgets.add(pw.SizedBox(height: 16));
        }

        // ── Section 6: Lifecycle Alerts ──
        final now = DateTime.now();
        final lifecycleAlerts = active.where((a) {
          if (a.installDate == null || a.expectedLifespanYears == null) {
            return false;
          }
          final age = now.difference(a.installDate!).inDays / 365.25;
          return (a.expectedLifespanYears! - age) < 1;
        }).toList();

        if (lifecycleAlerts.isNotEmpty) {
          widgets.add(_sectionHeader('Lifecycle Alerts', primaryColor));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(_tableHeader(
              ['Ref', 'Type', 'Install Date', 'Lifespan', 'Remaining', 'Status'],
              [2, 3, 2, 2, 2, 2],
              primaryLight));

          final dateFormat = DateFormat('dd/MM/yy');
          for (int i = 0; i < lifecycleAlerts.length; i++) {
            final a = lifecycleAlerts[i];
            final type = getType(a.assetTypeId);
            final age = now.difference(a.installDate!).inDays / 365.25;
            final remaining = a.expectedLifespanYears! - age;
            final isPastEol = remaining <= 0;

            widgets.add(_tableRow(
              [
                a.reference ?? '-',
                type?.name ?? '-',
                dateFormat.format(a.installDate!),
                '${a.expectedLifespanYears}y',
                isPastEol
                    ? '${remaining.abs().toStringAsFixed(1)}y overdue'
                    : '${remaining.toStringAsFixed(1)}y left',
                isPastEol ? 'PAST EOL' : 'APPROACHING',
              ],
              [2, 3, 2, 2, 2, 2],
              isAlt: i.isOdd,
              primaryLight: primaryLight,
              statusIndex: 5,
              statusColor: isPastEol ? _failRed : _untestedAmber,
            ));
          }
          widgets.add(pw.SizedBox(height: 16));
        }

        // ── Section 7: Service History Summary ──
        if (records.isNotEmpty) {
          widgets.add(_sectionHeader('Service History Summary', primaryColor));
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(_tableHeader(
              ['Date', 'Asset Ref', 'Engineer', 'Result'],
              [2, 3, 3, 2],
              primaryLight));

          records.sort(
              (a, b) => b.serviceDate.compareTo(a.serviceDate));
          final recentRecords = records.take(20).toList();
          final dateFormat = DateFormat('dd/MM/yy');
          for (int i = 0; i < recentRecords.length; i++) {
            final r = recentRecords[i];
            final asset =
                assets.where((a) => a.id == r.assetId).firstOrNull;
            final resultColor =
                r.overallResult == 'pass' ? _passGreen : _failRed;

            widgets.add(_tableRow(
              [
                dateFormat.format(r.serviceDate),
                asset?.reference ?? '-',
                r.engineerName,
                r.overallResult.toUpperCase(),
              ],
              [2, 3, 3, 2],
              isAlt: i.isOdd,
              primaryLight: primaryLight,
              statusIndex: 3,
              statusColor: resultColor,
            ));
          }
        }

        return widgets;
      },
    ),
  );

  return await pdf.save();
}

// ── Helper widgets for the isolate ──

pw.Widget _coverField(String label, String value) {
  return pw.Column(
    children: [
      pw.Text(label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
      pw.SizedBox(height: 2),
      pw.Text(value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    ],
  );
}

pw.Widget _statBox(String label, String value, PdfColor color) {
  return pw.Container(
    width: 80,
    padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: _white)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: _white)),
      ],
    ),
  );
}

pw.Widget _sectionHeader(String title, PdfColor primaryColor) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: primaryColor,
      borderRadius: const pw.BorderRadius.only(
        topLeft: pw.Radius.circular(4),
        topRight: pw.Radius.circular(4),
      ),
    ),
    child: pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: _white,
        letterSpacing: 0.5,
      ),
    ),
  );
}

pw.Widget _legendDot(PdfColor color, String label) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
    ],
  );
}

pw.Widget _tableHeader(
    List<String> headers, List<int> flexes, PdfColor bgColor) {
  return pw.Container(
    color: bgColor,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: pw.Row(
      children: List.generate(
        headers.length,
        (i) => pw.Expanded(
          flex: flexes[i],
          child: pw.Text(headers[i],
              style:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ),
      ),
    ),
  );
}

pw.Widget _tableRow(
  List<String> values,
  List<int> flexes, {
  bool isAlt = false,
  required PdfColor primaryLight,
  int? statusIndex,
  PdfColor? statusColor,
}) {
  return pw.Container(
    color: isAlt ? primaryLight : null,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: pw.Row(
      children: List.generate(
        values.length,
        (i) => pw.Expanded(
          flex: flexes[i],
          child: pw.Text(
            values[i],
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight:
                  i == statusIndex ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: i == statusIndex ? statusColor : null,
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Service class ──

class ComplianceReportService {
  ComplianceReportService._();
  static final ComplianceReportService instance = ComplianceReportService._();

  final _storage = FirebaseStorage.instance;

  Future<Uint8List> generateReport({
    required String basePath,
    required String siteId,
    required String siteName,
    required String siteAddress,
  }) async {
    // ── Gather phase (main thread) ──

    // Fonts
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {}

    // Branding
    final settings = await JobsheetSettingsService.getSettings();
    final useCompanyBranding = basePath.startsWith('companies/');
    final logoBytes =
        await CompanyPdfConfigService.instance.getEffectiveLogoBytes(
      useCompanyBranding: useCompanyBranding,
      type: PdfDocumentType.jobsheet,
    );
    final companyPdf = CompanyPdfConfigService.instance;
    final headerConfig = await companyPdf.getEffectiveHeaderConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );
    final footerConfig = await companyPdf.getEffectiveFooterConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );
    final colourScheme = await companyPdf.getEffectiveColourScheme(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );

    // User info
    final user = AuthService().currentUser;
    final engineerName = user?.displayName ?? 'Unknown';
    final companyName = settings.companyName;

    // Assets & types
    final assets =
        await AssetService.instance.getAssetsStream(basePath, siteId).first;
    final assetTypes = await AssetTypeService.instance.getAssetTypes(basePath);

    // Service records
    final records = await ServiceHistoryService.instance
        .getRecordsForSite(basePath, siteId)
        .first;

    // Floor plans
    final floorPlans = await FloorPlanService.instance
        .getFloorPlansStream(basePath, siteId)
        .first;

    // Download floor plan images
    final floorPlanImages = <String, Uint8List>{};
    for (final plan in floorPlans) {
      try {
        final ref =
            _storage.ref('$basePath/sites/$siteId/floor_plans/${plan.id}.jpg');
        final bytes = await ref.getData(5 * 1024 * 1024); // 5MB max
        if (bytes != null) {
          floorPlanImages[plan.id] = bytes;
        }
      } catch (e) {
        debugPrint('Failed to download floor plan image ${plan.id}: $e');
      }
    }

    // Download defect photos (limit to 1 per failed record, max 10 total)
    final defectPhotos = <String, Uint8List>{};
    final failedRecords = records
        .where((r) =>
            r.overallResult == 'fail' && r.defectPhotoUrls.isNotEmpty)
        .take(10);
    for (final record in failedRecords) {
      for (final url in record.defectPhotoUrls.take(1)) {
        try {
          final ref = _storage.refFromURL(url);
          final bytes = await ref.getData(2 * 1024 * 1024);
          if (bytes != null) {
            defectPhotos[url.hashCode.toString()] = bytes;
          }
        } catch (e) {
          debugPrint('Failed to download defect photo: $e');
        }
      }
    }

    final data = ComplianceReportPdfData(
      siteName: siteName,
      siteAddress: siteAddress,
      engineerName: engineerName,
      companyName: companyName,
      reportDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      logoBytes: logoBytes,
      headerConfigJson: headerConfig.toJson(),
      footerConfigJson: footerConfig.toJson(),
      colourSchemeValue: colourScheme.primaryColorValue,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      assetsJson: assets.map((a) => a.toJson()).toList(),
      assetTypesJson: assetTypes.map((t) => t.toJson()).toList(),
      serviceRecordsJson: records.map((r) => r.toJson()).toList(),
      floorPlansJson: floorPlans.map((p) => p.toJson()).toList(),
      floorPlanImages: floorPlanImages,
      defectPhotos: defectPhotos,
    );

    // ── Build phase ──
    if (kIsWeb) {
      return _buildComplianceReport(data);
    }
    return compute(_buildComplianceReport, data);
  }

  static Future<void> shareReport(
      Uint8List pdfBytes, String siteName) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${siteName.replaceAll(' ', '_')}_compliance_report.pdf',
    );
  }

  static Future<void> printReport(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }
}

Uint8List _extractFontBytes(pw.Font font) {
  final ttf = font as pw.TtfFont;
  return Uint8List.fromList(
    ttf.data.buffer
        .asUint8List(ttf.data.offsetInBytes, ttf.data.lengthInBytes),
  );
}
