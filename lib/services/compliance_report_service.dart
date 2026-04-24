import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/image_utils.dart';
import '../utils/image_compress_stub.dart'
    if (dart.library.html) '../utils/image_compress_web.dart' as web_compress;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'user_profile_service.dart';
import 'asset_service.dart';
import 'asset_type_service.dart';
import 'defect_service.dart';
import 'service_history_service.dart';
import 'floor_plan_service.dart';
import 'jobsheet_settings_service.dart';
import 'company_pdf_config_service.dart';
import 'pdf_generation_data.dart';
import 'bs5839_config_service.dart';
import 'inspection_visit_service.dart';
import 'remote_config_service.dart';
import 'pdf_footer_builder.dart';
import 'pdf_branding_service.dart';
import 'pdf_widgets/pdf_cover_builder.dart';
import 'pdf_widgets/pdf_font_registry.dart';
import 'pdf_widgets/pdf_modern_header.dart' show PdfHeaderBuilder;

// ── Colour constants for the isolate ──
const _white = PdfColors.white;
const _lightGray = PdfColor.fromInt(0xFFE0E0E0);
const _passGreen = PdfColor.fromInt(0xFF4CAF50);
const _failRed = PdfColor.fromInt(0xFFD32F2F);
const _untestedAmber = PdfColor.fromInt(0xFFF97316);

/// Resizes image bytes to a maximum width, re-encoding as JPEG.
/// Returns original bytes if already smaller or decoding fails.
Uint8List _resizeImageBytes(Uint8List bytes, {int maxWidth = 1200}) {
  return compressImageBytes(bytes, maxWidth: maxWidth, quality: 80);
}

// ── Parsed data holder used by section helpers ──
class _ReportContext {
  final ComplianceReportPdfData data;
  final List<Asset> assets;
  final List<AssetType> assetTypes;
  final List<ServiceRecord> records;
  final List<FloorPlan> floorPlans;
  final List<Asset> active;
  final List<Asset> decom;
  final List<Asset> pass;
  final List<Asset> fail;
  final List<Asset> untested;
  final PdfColor primaryColor;
  final PdfColor primaryLight;
  final PdfColor accentColor;

  _ReportContext({
    required this.data,
    required this.assets,
    required this.assetTypes,
    required this.records,
    required this.floorPlans,
    required this.active,
    required this.decom,
    required this.pass,
    required this.fail,
    required this.untested,
    required this.primaryColor,
    required this.primaryLight,
    required this.accentColor,
  });

  AssetType? getType(String typeId) {
    try {
      return assetTypes.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return null;
    }
  }

  int get checklistDriftCount {
    return active.where((a) {
      if (a.complianceStatus != AssetComplianceStatus.pass &&
          a.complianceStatus != AssetComplianceStatus.fail) {
        return false;
      }
      final type = getType(a.assetTypeId);
      if (type == null) return false;
      final tested = a.lastChecklistVersionTested;
      if (tested == null) return false;
      return tested < type.checklistVersion;
    }).length;
  }
}

_ReportContext _buildReportContext(ComplianceReportPdfData data) {
  final colourScheme =
      PdfColourScheme(primaryColorValue: data.colourSchemeValue);
  final assets = data.assetsJson.map((j) => Asset.fromJson(j)).toList();
  final assetTypes =
      data.assetTypesJson.map((j) => AssetType.fromJson(j)).toList();
  final records =
      data.serviceRecordsJson.map((j) => ServiceRecord.fromJson(j)).toList();
  final floorPlans =
      data.floorPlansJson.map((j) => FloorPlan.fromJson(j)).toList();
  final active =
      assets.where((a) => a.complianceStatus != AssetComplianceStatus.decommissioned).toList();

  return _ReportContext(
    data: data,
    assets: assets,
    assetTypes: assetTypes,
    records: records,
    floorPlans: floorPlans,
    active: active,
    decom: assets.where((a) => a.complianceStatus == AssetComplianceStatus.decommissioned).toList(),
    pass: active.where((a) => a.complianceStatus == AssetComplianceStatus.pass).toList(),
    fail: active.where((a) => a.complianceStatus == AssetComplianceStatus.fail).toList(),
    untested: active.where((a) => a.complianceStatus == AssetComplianceStatus.untested).toList(),
    primaryColor: colourScheme.primaryColor,
    primaryLight: colourScheme.primaryLight,
    accentColor: data.secondaryColourValue != null
        ? PdfColor.fromInt(data.secondaryColourValue!)
        : colourScheme.secondaryColor,
  );
}

int _hexToColorValue(String hex) {
  final clean = hex.replaceFirst('#', '');
  return 0xFF000000 | int.parse(clean, radix: 16);
}

// ── Section 2: Compliance Summary ──
void _addComplianceSummary(List<pw.Widget> widgets, _ReportContext ctx) {
  widgets.add(_sectionHeader('Compliance Summary', ctx.primaryColor));
  widgets.add(pw.SizedBox(height: 8));
  widgets.add(pw.Text(
    '${ctx.assets.length} total assets (${ctx.active.length} active, ${ctx.decom.length} decommissioned)',
    style: const pw.TextStyle(fontSize: 10),
  ));
  widgets.add(pw.SizedBox(height: 8));

  final total = ctx.active.length.clamp(1, double.maxFinite.toInt());
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
          if (ctx.pass.isNotEmpty)
            pw.Expanded(
              flex: ctx.pass.length,
              child: pw.Container(color: _passGreen),
            ),
          if (ctx.fail.isNotEmpty)
            pw.Expanded(
              flex: ctx.fail.length,
              child: pw.Container(color: _failRed),
            ),
          if (ctx.untested.isNotEmpty)
            pw.Expanded(
              flex: ctx.untested.length,
              child: pw.Container(color: _untestedAmber),
            ),
        ],
      ),
    ),
  ));
  widgets.add(pw.SizedBox(height: 6));
  widgets.add(pw.Row(
    children: [
      _legendDot(_passGreen, 'Pass ${ctx.pass.length} (${(ctx.pass.length / total * 100).toStringAsFixed(0)}%)'),
      pw.SizedBox(width: 16),
      _legendDot(_failRed, 'Fail ${ctx.fail.length} (${(ctx.fail.length / total * 100).toStringAsFixed(0)}%)'),
      pw.SizedBox(width: 16),
      _legendDot(_untestedAmber, 'Untested ${ctx.untested.length} (${(ctx.untested.length / total * 100).toStringAsFixed(0)}%)'),
    ],
  ));
  widgets.add(pw.SizedBox(height: 16));
}

// ── Section 3: Floor Plans ──
// Pin positions use plan.imageWidth/imageHeight from the model (not the
// downloaded image bytes), so resizing the source image is safe.
void _addFloorPlans(List<pw.Widget> widgets, _ReportContext ctx) {
  for (final plan in ctx.floorPlans) {
    final imageBytes = ctx.data.floorPlanImages[plan.id];
    if (imageBytes == null) continue;

    widgets.add(_sectionHeader('Floor Plan: ${plan.name}', ctx.primaryColor));
    widgets.add(pw.SizedBox(height: 6));

    final planAssets =
        ctx.active.where((a) => a.floorPlanId == plan.id).toList();

    const containerHeight = 300.0;
    const containerWidth = 547.0; // A4 (595.28) - 2*24 margins
    final pinSize = 8.0 * plan.pinScale;

    final imageAspect = plan.imageWidth / plan.imageHeight;
    final containerAspect = containerWidth / containerHeight;

    double renderW, renderH, offsetX, offsetY;
    if (imageAspect > containerAspect) {
      renderW = containerWidth;
      renderH = containerWidth / imageAspect;
      offsetX = 0;
      offsetY = (containerHeight - renderH) / 2;
    } else {
      renderH = containerHeight;
      renderW = containerHeight * imageAspect;
      offsetX = (containerWidth - renderW) / 2;
      offsetY = 0;
    }

    widgets.add(pw.Container(
      width: containerWidth,
      height: containerHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGray),
      ),
      child: pw.Stack(
        children: [
          // Position image explicitly at calculated render area.
          // Use explicit width/height on pw.Image rather than relying
          // on SizedBox + BoxFit, which doesn't constrain correctly in
          // the pdf package — the image renders at intrinsic pixel size
          // instead of the SizedBox dimensions, causing pins to cluster
          // in the top-left corner.
          pw.Positioned(
            left: offsetX,
            top: offsetY,
            child: pw.Image(pw.MemoryImage(imageBytes),
                width: renderW, height: renderH),
          ),
          ...planAssets.map((a) {
            if (a.xPercent == null || a.yPercent == null) {
              return pw.SizedBox();
            }
            final statusColor = a.complianceStatus == AssetComplianceStatus.pass
                ? _passGreen
                : a.complianceStatus == AssetComplianceStatus.fail
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

    // Status legend for this floor plan
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        _legendDot(_passGreen, 'Pass'),
        pw.SizedBox(width: 12),
        _legendDot(_failRed, 'Fail'),
        pw.SizedBox(width: 12),
        _legendDot(_untestedAmber, 'Untested'),
      ],
    ));

    widgets.add(pw.SizedBox(height: 12));
  }
}

// ── Section 4: Asset Register Table ──
void _addAssetRegister(List<pw.Widget> widgets, _ReportContext ctx) {
  widgets.add(_sectionHeader('Asset Register', ctx.primaryColor));
  widgets.add(pw.SizedBox(height: 4));
  widgets.add(_tableHeader(
      ['Ref', 'Type', 'Location', 'Zone', 'Status', 'Last Service', 'Lifespan'],
      [2, 3, 3, 2, 2, 2, 2],
      ctx.primaryLight));

  for (int i = 0; i < ctx.active.length; i++) {
    final a = ctx.active[i];
    final type = ctx.getType(a.assetTypeId);
    final dateFormat = DateFormat('dd/MM/yy');
    final lastService =
        a.lastServiceDate != null ? dateFormat.format(a.lastServiceDate!) : '-';
    final lifespan = a.expectedLifespanYears != null
        ? '${a.expectedLifespanYears}y'
        : '-';
    final statusLabel = a.complianceStatus == AssetComplianceStatus.pass
        ? 'PASS'
        : a.complianceStatus == AssetComplianceStatus.fail
            ? 'FAIL'
            : 'UNTESTED';
    final statusColor = a.complianceStatus == AssetComplianceStatus.pass
        ? _passGreen
        : a.complianceStatus == AssetComplianceStatus.fail
            ? _failRed
            : _untestedAmber;

    String locationText = a.locationDescription ?? '';
    if (locationText.isEmpty && a.floorPlanId != null) {
      final fp = ctx.floorPlans
          .where((f) => f.id == a.floorPlanId)
          .firstOrNull;
      if (fp != null) locationText = fp.name;
    }
    if (locationText.isEmpty) locationText = '\u2014';

    widgets.add(_tableRow(
      [
        a.reference ?? '\u2014',
        type?.name ?? '\u2014',
        locationText,
        a.zone ?? '\u2014',
        statusLabel,
        lastService,
        lifespan,
      ],
      [2, 3, 3, 2, 2, 2, 2],
      isAlt: i.isOdd,
      primaryLight: ctx.primaryLight,
      statusIndex: 4,
      statusColor: statusColor,
    ));
  }
  widgets.add(pw.SizedBox(height: 16));
}

// ── Section 5: Defect Summary ──
void _addDefectSummary(List<pw.Widget> widgets, _ReportContext ctx) {
  final defects = ctx.data.defectsJson
      .map((j) => Defect.fromJson(j))
      .toList();
  final openDefects =
      defects.where((d) => d.status == Defect.statusOpen).toList();

  if (openDefects.isNotEmpty) {
    widgets.add(_sectionHeader('Defect Summary', ctx.primaryColor));
    widgets.add(pw.SizedBox(height: 4));

    for (final defect in openDefects) {
      final asset =
          ctx.assets.where((a) => a.id == defect.assetId).firstOrNull;
      final type = asset != null ? ctx.getType(asset.assetTypeId) : null;

      final severityLabel = defect.severity.toUpperCase();
      final severityColor = defect.severity == 'critical'
          ? _failRed
          : defect.severity == 'major'
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
            pw.Text(defect.description,
                style: const pw.TextStyle(fontSize: 8)),
            if (defect.action != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'Action: ${defect.action!.replaceAll('_', ' ')}',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700),
              ),
            ],
            if (defect.photoUrls.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Row(
                children: defect.photoUrls
                    .take(3)
                    .map((url) {
                  final photoBytes =
                      ctx.data.defectPhotos[url.hashCode.toString()];
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

    if (ctx.data.rectifiedCount > 0) {
      final sinceStr = ctx.data.lastReportDateStr != null
          ? DateFormat('dd/MM/yyyy')
              .format(DateTime.parse(ctx.data.lastReportDateStr!))
          : 'previous report';
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          '${ctx.data.rectifiedCount} defect${ctx.data.rectifiedCount == 1 ? '' : 's'} rectified since $sinceStr.',
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700),
        ),
      ));
    }

    widgets.add(pw.SizedBox(height: 16));
  } else if (defects.isEmpty) {
    // Legacy fallback: no defect entities exist, use service records
    final failedRecords = ctx.records
        .where((r) =>
            r.overallResult == 'fail' &&
            r.defectNote != null &&
            r.defectNote!.isNotEmpty)
        .toList();

    if (failedRecords.isNotEmpty) {
      widgets.add(_sectionHeader('Defect Summary', ctx.primaryColor));
      widgets.add(pw.SizedBox(height: 4));

      for (final record in failedRecords) {
        final asset =
            ctx.assets.where((a) => a.id == record.assetId).firstOrNull;
        final type =
            asset != null ? ctx.getType(asset.assetTypeId) : null;

        final severityLabel =
            record.defectSeverity?.toUpperCase() ?? 'N/A';
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
              if (record.defectPhotoUrls.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  children: record.defectPhotoUrls
                      .take(3)
                      .map((url) {
                    final photoBytes =
                        ctx.data.defectPhotos[url.hashCode.toString()];
                    if (photoBytes == null) {
                      return pw.SizedBox.shrink();
                    }
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 4),
                      child: pw.Image(pw.MemoryImage(photoBytes),
                          width: 60,
                          height: 45,
                          fit: pw.BoxFit.cover),
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
  }
}

// ── Section 6: Lifecycle Alerts ──
void _addLifecycleAlerts(List<pw.Widget> widgets, _ReportContext ctx) {
  final now = DateTime.now();
  final lifecycleAlerts = ctx.active.where((a) {
    if (a.installDate == null || a.expectedLifespanYears == null) {
      return false;
    }
    final age = now.difference(a.installDate!).inDays / 365.25;
    return (a.expectedLifespanYears! - age) < 1;
  }).toList();

  if (lifecycleAlerts.isNotEmpty) {
    widgets.add(_sectionHeader('Lifecycle Alerts', ctx.primaryColor));
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(_tableHeader(
        ['Ref', 'Type', 'Install Date', 'Lifespan', 'Remaining', 'Status'],
        [2, 3, 2, 2, 2, 2],
        ctx.primaryLight));

    final dateFormat = DateFormat('dd/MM/yy');
    for (int i = 0; i < lifecycleAlerts.length; i++) {
      final a = lifecycleAlerts[i];
      final type = ctx.getType(a.assetTypeId);
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
        primaryLight: ctx.primaryLight,
        statusIndex: 5,
        statusColor: isPastEol ? _failRed : _untestedAmber,
      ));
    }
    widgets.add(pw.SizedBox(height: 16));
  }
}

// ── Section 7: Service History Summary ──
void _addServiceHistory(List<pw.Widget> widgets, _ReportContext ctx) {
  if (ctx.records.isNotEmpty) {
    widgets.add(_sectionHeader('Service History Summary', ctx.primaryColor));
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(_tableHeader(
        ['Date', 'Asset Ref', 'Engineer', 'Result'],
        [2, 3, 3, 2],
        ctx.primaryLight));

    final sortedRecords = List<ServiceRecord>.from(ctx.records)
      ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    final dateFormat = DateFormat('dd/MM/yy');

    // Collapse same-asset same-day records into one row
    final grouped = <String, List<ServiceRecord>>{};
    for (final r in sortedRecords) {
      final key = '${r.assetId}_${dateFormat.format(r.serviceDate)}';
      (grouped[key] ??= []).add(r);
    }
    final collapsed = grouped.values
        .map((g) => g.first) // latest attempt (already sorted desc)
        .toList();
    final recentRecords = collapsed.take(20).toList();

    for (int i = 0; i < recentRecords.length; i++) {
      final r = recentRecords[i];
      final key = '${r.assetId}_${dateFormat.format(r.serviceDate)}';
      final groupCount = grouped[key]!.length;
      final asset =
          ctx.assets.where((a) => a.id == r.assetId).firstOrNull;
      final resultColor =
          r.overallResult == 'pass' ? _passGreen : _failRed;
      final dateLabel = groupCount > 1
          ? '${dateFormat.format(r.serviceDate)} ($groupCount attempts)'
          : dateFormat.format(r.serviceDate);

      widgets.add(_tableRow(
        [
          dateLabel,
          asset?.reference ?? '\u2014',
          r.engineerName,
          r.overallResult.toUpperCase(),
        ],
        [2, 3, 3, 2],
        isAlt: i.isOdd,
        primaryLight: ctx.primaryLight,
        statusIndex: 3,
        statusColor: resultColor,
      ));
    }
  }
}

/// Top-level function for compute() — builds the compliance report PDF.
/// Used on native platforms via compute() isolate.
Future<Uint8List> _buildComplianceReport(ComplianceReportPdfData data) async {
  final ctx = _buildReportContext(data);

  // Load branded fonts in isolate from pre-loaded bytes
  final branding = PdfBranding.fromJson(data.brandingJson!);
  if (data.brandedFontBytes != null) {
    PdfFontRegistry.instance.loadFromBytes(data.brandedFontBytes!);
  }

  final fonts = PdfFontRegistry.instance;
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.interRegular,
      bold: fonts.interBold,
    ),
  );

  // Section 1: Cover Page
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => PdfCoverBuilder.build(
      branding: branding,
      docType: BrandingDocType.report,
      defaultEyebrow: 'SITE COMPLIANCE',
      defaultTitle: 'Compliance\nReport',
      defaultSubtitle: '${data.siteName} · ${data.reportDate}',
      metaFields: [
        (label: 'SITE', value: data.siteName),
        (label: 'ADDRESS', value: data.siteAddress),
        (label: 'DATE', value: data.reportDate),
        (label: 'ENGINEER', value: data.engineerName),
        if (data.companyName.isNotEmpty)
          (label: 'COMPANY', value: data.companyName),
      ],
      logoBytes: data.logoBytes,
      companyName: data.companyName,
    ),
  ));

  // Sections 2-7: Multi-page content
  final widgets = <pw.Widget>[];
  _addComplianceSummary(widgets, ctx);
  _addFloorPlans(widgets, ctx);
  _addAssetRegister(widgets, ctx);
  _addDefectSummary(widgets, ctx);
  _addLifecycleAlerts(widgets, ctx);
  _addServiceHistory(widgets, ctx);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: PdfHeaderBuilder.build(
              branding: branding,
              companyName: data.companyName,
              metaText: 'COMPLIANCE REPORT · ${data.reportDate}',
              logoBytes: data.logoBytes,
            ),
          ),
      footer: (context) => PdfFooterBuilder.buildBrandedFooter(
            branding: branding,
            pageNumber: context.pageNumber,
            pagesCount: context.pagesCount,
            companyName: data.companyName,
            defaultFooterText: 'Site Compliance Report · ${data.siteName}',
          ),
      build: (context) => widgets,
    ),
  );

  return await pdf.save();
}

/// Web-specific async builder that yields to the event loop between sections.
Future<Uint8List> _buildComplianceReportWeb(
  ComplianceReportPdfData data, {
  void Function(String phase)? onProgress,
}) async {
  final ctx = _buildReportContext(data);

  // Load branded fonts from pre-loaded bytes (or directly on web)
  final branding = PdfBranding.fromJson(data.brandingJson!);
  if (data.brandedFontBytes != null) {
    PdfFontRegistry.instance.loadFromBytes(data.brandedFontBytes!);
  }

  final fonts = PdfFontRegistry.instance;
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.interRegular,
      bold: fonts.interBold,
    ),
  );

  // Section 1: Cover Page
  onProgress?.call('Building cover page...');
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => PdfCoverBuilder.build(
      branding: branding,
      docType: BrandingDocType.report,
      defaultEyebrow: 'SITE COMPLIANCE',
      defaultTitle: 'Compliance\nReport',
      defaultSubtitle: '${data.siteName} · ${data.reportDate}',
      metaFields: [
        (label: 'SITE', value: data.siteName),
        (label: 'ADDRESS', value: data.siteAddress),
        (label: 'DATE', value: data.reportDate),
        (label: 'ENGINEER', value: data.engineerName),
        if (data.companyName.isNotEmpty)
          (label: 'COMPANY', value: data.companyName),
      ],
      logoBytes: data.logoBytes,
      companyName: data.companyName,
    ),
  ));
  await Future.delayed(Duration.zero);

  // Build sections 2-7 with yields between each
  final widgets = <pw.Widget>[];

  onProgress?.call('Building compliance summary...');
  _addComplianceSummary(widgets, ctx);
  await Future.delayed(Duration.zero);

  onProgress?.call('Building floor plans...');
  _addFloorPlans(widgets, ctx);
  await Future.delayed(Duration.zero);

  onProgress?.call('Building asset register...');
  _addAssetRegister(widgets, ctx);
  await Future.delayed(Duration.zero);

  onProgress?.call('Building defect summary...');
  _addDefectSummary(widgets, ctx);
  await Future.delayed(Duration.zero);

  onProgress?.call('Building lifecycle alerts...');
  _addLifecycleAlerts(widgets, ctx);
  await Future.delayed(Duration.zero);

  onProgress?.call('Building service history...');
  _addServiceHistory(widgets, ctx);
  await Future.delayed(Duration.zero);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: PdfHeaderBuilder.build(
              branding: branding,
              companyName: data.companyName,
              metaText: 'COMPLIANCE REPORT · ${data.reportDate}',
              logoBytes: data.logoBytes,
            ),
          ),
      footer: (context) => PdfFooterBuilder.buildBrandedFooter(
            branding: branding,
            pageNumber: context.pageNumber,
            pagesCount: context.pagesCount,
            companyName: data.companyName,
            defaultFooterText: 'Site Compliance Report · ${data.siteName}',
          ),
      build: (context) => widgets,
    ),
  );

  onProgress?.call('Finalizing PDF...');
  await Future.delayed(Duration.zero);
  return await pdf.save();
}

// ── Helper widgets for the isolate ──

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

  /// Downloads bytes from a Firebase Storage reference.
  /// On web, uses getDownloadURL() + HTTP GET to avoid CORS issues with getData().
  static Future<Uint8List?> _downloadBytes(Reference ref, int maxSize) async {
    if (kIsWeb) {
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } else {
      return await ref.getData(maxSize);
    }
  }

  Future<Uint8List> generateReport({
    required String basePath,
    required String siteId,
    required String siteName,
    required String siteAddress,
    void Function(String phase)? onProgress,
  }) async {
    // ── Gather phase (main thread) ──

    onProgress?.call('Loading fonts and branding...');

    // Fonts
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {}

    // Branded fonts (for new cover/header/footer builders)
    Map<String, Uint8List>? brandedFontBytes;
    try {
      await PdfFontRegistry.instance.ensureLoaded();
      brandedFontBytes = PdfFontRegistry.instance.extractFontBytes();
    } catch (e) {
      debugPrint('Failed to load branded fonts: $e');
    }

    // Branding
    final settings = await JobsheetSettingsService.getSettings();
    final useCompanyBranding = basePath.startsWith('companies/');

    PdfBranding branding = PdfBranding.defaultBranding();
    Uint8List? brandingLogoBytes;
    try {
      final b = await PdfBrandingService.instance.resolveBrandingForCurrentUser();
      if (b.appliesToDocType(BrandingDocType.report)) {
        branding = b;
      }
      if (branding.logoUrl != null) {
        try {
          final response = await http.get(Uri.parse(branding.logoUrl!));
          if (response.statusCode == 200) {
            brandingLogoBytes = response.bodyBytes;
          }
        } catch (e) {
          debugPrint('Failed to download branding logo: $e');
        }
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'PdfBranding resolution failed — using default',
      );
    }

    final logoBytes = brandingLogoBytes ??
        await CompanyPdfConfigService.instance.getEffectiveLogoBytes(
          useCompanyBranding: useCompanyBranding,
          type: PdfDocumentType.jobsheet,
        );
    final companyPdf = CompanyPdfConfigService.instance;
    final headerConfig = await companyPdf.getEffectiveHeaderConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );

    // Colour + footer from branding
    final effectiveColourValue = _hexToColorValue(branding.primaryColour);
    final effectiveSecondaryValue = _hexToColorValue(branding.accentColour);
    final effectiveFooterConfig = PdfFooterConfig(
      leftLines: [
        if (branding.footerText.isNotEmpty)
          HeaderTextLine(
              key: 'brandingText',
              value: branding.footerText,
              fontSize: 8),
      ],
      centreLines: const [],
    );

    // User info
    final engineerName = UserProfileService.instance.resolveEngineerName();
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

    // Download floor plan images — parallel
    onProgress?.call('Downloading floor plan images...');
    final floorPlanEntries = await Future.wait(
      floorPlans.map((plan) async {
        try {
          Uint8List? bytes;
          if (kIsWeb && plan.imageUrl.isNotEmpty) {
            final response = await http.get(Uri.parse(plan.imageUrl));
            if (response.statusCode == 200) bytes = response.bodyBytes;
          } else {
            final ref =
                _storage.ref('$basePath/sites/$siteId/floor_plans/${plan.id}.${plan.fileExtension}');
            bytes = await _downloadBytes(ref, 5 * 1024 * 1024);
          }
          return bytes != null ? MapEntry(plan.id, bytes) : null;
        } catch (e) {
          debugPrint('Failed to download floor plan image ${plan.id}: $e');
          return null;
        }
      }),
    );
    final floorPlanImages = Map.fromEntries(
      floorPlanEntries.whereType<MapEntry<String, Uint8List>>(),
    );

    // Fetch defects from the new Defect collection
    final allDefects =
        await DefectService.instance.getDefectsForSite(basePath, siteId);
    final lastReportDate =
        await DefectService.instance.getLastReportDate(basePath, siteId);
    final rectifiedCount = lastReportDate != null
        ? await DefectService.instance
            .getRectifiedCountSince(basePath, siteId, lastReportDate)
        : allDefects
            .where((d) => d.status == Defect.statusRectified)
            .length;

    // Download defect photos — parallel
    onProgress?.call('Downloading defect photos...');
    final defectPhotos = <String, Uint8List>{};
    final openDefectsWithPhotos = allDefects
        .where(
            (d) => d.status == Defect.statusOpen && d.photoUrls.isNotEmpty)
        .take(10);

    final defectPhotoEntries = await Future.wait(
      openDefectsWithPhotos.expand((defect) => defect.photoUrls.take(1).map((url) async {
        try {
          Uint8List? bytes;
          if (kIsWeb && url.isNotEmpty) {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) bytes = response.bodyBytes;
          } else {
            final ref = _storage.refFromURL(url);
            bytes = await _downloadBytes(ref, 2 * 1024 * 1024);
          }
          return bytes != null ? MapEntry(url.hashCode.toString(), bytes) : null;
        } catch (e) {
          debugPrint('Failed to download defect photo: $e');
          return null;
        }
      })),
    );
    defectPhotos.addEntries(
      defectPhotoEntries.whereType<MapEntry<String, Uint8List>>(),
    );

    // If no defects in new collection, fall back to legacy service record photos
    if (allDefects.isEmpty) {
      final failedRecords = records
          .where((r) =>
              r.overallResult == 'fail' && r.defectPhotoUrls.isNotEmpty)
          .take(10);

      final legacyEntries = await Future.wait(
        failedRecords.expand((record) => record.defectPhotoUrls.take(1).map((url) async {
          try {
            Uint8List? bytes;
            if (kIsWeb && url.isNotEmpty) {
              final response = await http.get(Uri.parse(url));
              if (response.statusCode == 200) bytes = response.bodyBytes;
            } else {
              final ref = _storage.refFromURL(url);
              bytes = await _downloadBytes(ref, 2 * 1024 * 1024);
            }
            return bytes != null ? MapEntry(url.hashCode.toString(), bytes) : null;
          } catch (e) {
            debugPrint('Failed to download defect photo: $e');
            return null;
          }
        })),
      );
      defectPhotos.addEntries(
        legacyEntries.whereType<MapEntry<String, Uint8List>>(),
      );
    }

    // Compress images to reduce PDF size (handles pre-existing large uploads).
    // Web uses browser-native Canvas API (fast); mobile uses image pkg (sync).
    onProgress?.call('Compressing images for PDF...');
    if (kIsWeb) {
      for (final key in floorPlanImages.keys.toList()) {
        await Future.delayed(Duration.zero);
        floorPlanImages[key] = await web_compress.compressImageBytesWeb(
          floorPlanImages[key]!, maxWidth: 1200, quality: 0.80);
      }
      for (final key in defectPhotos.keys.toList()) {
        await Future.delayed(Duration.zero);
        defectPhotos[key] = await web_compress.compressImageBytesWeb(
          defectPhotos[key]!, maxWidth: 800, quality: 0.80);
      }
    } else {
      for (final key in floorPlanImages.keys.toList()) {
        floorPlanImages[key] = _resizeImageBytes(floorPlanImages[key]!, maxWidth: 1200);
      }
      for (final key in defectPhotos.keys.toList()) {
        defectPhotos[key] = _resizeImageBytes(defectPhotos[key]!, maxWidth: 800);
      }
    }

    // BS 5839 status for cover badge/disclaimer
    String? bs5839LastDeclaration;
    final bs5839Enabled = RemoteConfigService.instance.bs5839ModeEnabled;
    if (bs5839Enabled) {
      try {
        final config = await Bs5839ConfigService.instance.getConfig(basePath, siteId);
        if (config != null) {
          final lastVisit = await InspectionVisitService.instance
              .getLastVisit(basePath, siteId);
          if (lastVisit?.completedAt != null) {
            bs5839LastDeclaration = lastVisit!.declaration.displayLabel;
          }
        }
      } catch (e) {
        debugPrint('Error loading BS 5839 data for report: $e');
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
      footerConfigJson: effectiveFooterConfig.toJson(),
      colourSchemeValue: effectiveColourValue,
      secondaryColourValue: effectiveSecondaryValue,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      assetsJson: assets.map((a) => a.toJson()).toList(),
      assetTypesJson: assetTypes.map((t) => t.toJson()).toList(),
      serviceRecordsJson: records.map((r) => r.toJson()).toList(),
      floorPlansJson: floorPlans.map((p) => p.toJson()).toList(),
      floorPlanImages: floorPlanImages,
      defectPhotos: defectPhotos,
      defectsJson: allDefects.map((d) => d.toJson()).toList(),
      rectifiedCount: rectifiedCount,
      lastReportDateStr: lastReportDate?.toIso8601String(),
      bs5839LastDeclaration: bs5839LastDeclaration,
      bs5839ModeEnabled: bs5839Enabled,
      brandingJson: branding.toJson(),
      brandedFontBytes: brandedFontBytes,
    );

    // Store last report date for rectified-count tracking
    await DefectService.instance
        .setLastReportDate(basePath, siteId, DateTime.now());

    // ── Build phase ──
    onProgress?.call('Building PDF...');
    if (kIsWeb) {
      return _buildComplianceReportWeb(data, onProgress: onProgress);
    }
    return compute(_buildComplianceReport, data);
  }

  /// Generates a compliance report PDF using the given [branding] directly
  /// (bypassing Firestore) with synthetic sample data, for previewing branding.
  static Future<Uint8List> generateBrandingPreview(PdfBranding branding) async {
    // Fonts
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {}

    // Branded fonts
    Map<String, Uint8List>? brandedFontBytes;
    try {
      await PdfFontRegistry.instance.ensureLoaded();
      brandedFontBytes = PdfFontRegistry.instance.extractFontBytes();
    } catch (e) {
      debugPrint('Failed to load branded fonts for preview: $e');
    }

    // Logo
    Uint8List? logoBytes;
    if (branding.logoUrl != null) {
      try {
        final response = await http.get(Uri.parse(branding.logoUrl!));
        if (response.statusCode == 200) logoBytes = response.bodyBytes;
      } catch (e) {
        debugPrint('Failed to download branding logo: $e');
      }
    }

    // Colour overrides
    final effectiveColourValue = _hexToColorValue(branding.primaryColour);
    final effectiveSecondaryValue = _hexToColorValue(branding.accentColour);

    // Footer override
    final effectiveFooterConfig = branding.footerText.isNotEmpty
        ? PdfFooterConfig(
            leftLines: [HeaderTextLine(key: 'brandingText', value: branding.footerText, fontSize: 8)],
            centreLines: const [],
          )
        : PdfFooterConfig.defaults();

    // Company info
    final settings = await JobsheetSettingsService.getSettings();
    final engineerName = UserProfileService.instance.resolveEngineerName();
    final companyName = settings.companyName.isNotEmpty
        ? settings.companyName
        : 'Sample Company Ltd';
    final now = DateTime.now();
    final reportDate = DateFormat('dd/MM/yyyy').format(now);

    // ── Synthetic sample data ──
    const siteId = 'preview-site';
    final sampleAssetTypes = [
      {'id': 'smoke-optical', 'name': 'Optical Smoke Detector', 'category': 'Detection', 'iconName': 'cloud', 'defaultColor': '#4CAF50', 'variants': <String>[], 'defaultLifespanYears': 10, 'defaultServiceIntervalMonths': 6, 'commonFaults': <String>[], 'isBuiltIn': true, 'checklistVersion': 1},
      {'id': 'mcp', 'name': 'Manual Call Point', 'category': 'Manual', 'iconName': 'warning_2', 'defaultColor': '#F44336', 'variants': <String>[], 'defaultLifespanYears': 15, 'defaultServiceIntervalMonths': 6, 'commonFaults': <String>[], 'isBuiltIn': true, 'checklistVersion': 1},
      {'id': 'heat-fixed', 'name': 'Fixed Heat Detector', 'category': 'Detection', 'iconName': 'flash_1', 'defaultColor': '#FF9800', 'variants': <String>[], 'defaultLifespanYears': 10, 'defaultServiceIntervalMonths': 6, 'commonFaults': <String>[], 'isBuiltIn': true, 'checklistVersion': 1},
      {'id': 'sounder', 'name': 'Sounder', 'category': 'Notification', 'iconName': 'sound', 'defaultColor': '#2196F3', 'variants': <String>[], 'defaultLifespanYears': 15, 'defaultServiceIntervalMonths': 12, 'commonFaults': <String>[], 'isBuiltIn': true, 'checklistVersion': 1},
    ];

    final lastService = now.subtract(const Duration(days: 30));
    final sampleAssets = [
      {'id': 'a1', 'siteId': siteId, 'assetTypeId': 'smoke-optical', 'reference': 'SD-001', 'locationDescription': 'Ground Floor — Reception', 'zone': 'Zone 1', 'complianceStatus': 'pass', 'lastServiceDate': lastService.toIso8601String(), 'lastServiceByName': engineerName, 'installDate': now.subtract(const Duration(days: 730)).toIso8601String(), 'createdBy': 'preview', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String(), 'photoUrls': <String>[]},
      {'id': 'a2', 'siteId': siteId, 'assetTypeId': 'mcp', 'reference': 'MCP-001', 'locationDescription': 'Ground Floor — Main Entrance', 'zone': 'Zone 1', 'complianceStatus': 'pass', 'lastServiceDate': lastService.toIso8601String(), 'lastServiceByName': engineerName, 'installDate': now.subtract(const Duration(days: 365)).toIso8601String(), 'createdBy': 'preview', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String(), 'photoUrls': <String>[]},
      {'id': 'a3', 'siteId': siteId, 'assetTypeId': 'heat-fixed', 'reference': 'HD-001', 'locationDescription': 'First Floor — Kitchen', 'zone': 'Zone 2', 'complianceStatus': 'fail', 'lastServiceDate': lastService.toIso8601String(), 'lastServiceByName': engineerName, 'installDate': now.subtract(const Duration(days: 1095)).toIso8601String(), 'createdBy': 'preview', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String(), 'photoUrls': <String>[]},
      {'id': 'a4', 'siteId': siteId, 'assetTypeId': 'sounder', 'reference': 'SND-001', 'locationDescription': 'Ground Floor — Corridor', 'zone': 'Zone 1', 'complianceStatus': 'untested', 'installDate': now.subtract(const Duration(days: 180)).toIso8601String(), 'createdBy': 'preview', 'createdAt': now.toIso8601String(), 'updatedAt': now.toIso8601String(), 'photoUrls': <String>[]},
    ];

    final sampleRecords = [
      {'id': 'r1', 'assetId': 'a1', 'siteId': siteId, 'engineerId': 'preview', 'engineerName': engineerName, 'serviceDate': lastService.toIso8601String(), 'overallResult': 'pass', 'checklistResults': <Map<String, dynamic>>[], 'defectPhotoUrls': <String>[], 'createdAt': lastService.toIso8601String(), 'mcpTestedThisVisit': false},
      {'id': 'r2', 'assetId': 'a3', 'siteId': siteId, 'engineerId': 'preview', 'engineerName': engineerName, 'serviceDate': lastService.toIso8601String(), 'overallResult': 'fail', 'checklistResults': <Map<String, dynamic>>[], 'defectNote': 'Detector slow to respond — contamination suspected', 'defectSeverity': 'major', 'defectAction': 'replacement_needed', 'defectPhotoUrls': <String>[], 'createdAt': lastService.toIso8601String(), 'mcpTestedThisVisit': false},
    ];

    final sampleDefects = [
      {'id': 'd1', 'assetId': 'a3', 'siteId': siteId, 'severity': 'major', 'description': 'Heat detector HD-001 slow to respond — contamination suspected, replacement recommended', 'photoUrls': <String>[], 'status': 'open', 'action': 'replacement_needed', 'createdBy': 'preview', 'createdByName': engineerName, 'createdAt': lastService.toIso8601String(), 'triggeredProhibitedRule': false},
    ];

    final data = ComplianceReportPdfData(
      siteName: 'Oakwood Business Centre',
      siteAddress: '45 Victoria Road, Manchester, M1 2AB',
      engineerName: engineerName,
      companyName: companyName,
      reportDate: reportDate,
      logoBytes: logoBytes,
      headerConfigJson: PdfHeaderConfig.defaults().toJson(),
      footerConfigJson: effectiveFooterConfig.toJson(),
      colourSchemeValue: effectiveColourValue,
      secondaryColourValue: effectiveSecondaryValue,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      assetsJson: sampleAssets,
      assetTypesJson: sampleAssetTypes,
      serviceRecordsJson: sampleRecords,
      floorPlansJson: const [],
      floorPlanImages: const {},
      defectPhotos: const {},
      defectsJson: sampleDefects,
      rectifiedCount: 0,
      brandingJson: branding.toJson(),
      brandedFontBytes: brandedFontBytes,
    );

    return _buildComplianceReportWeb(data);
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
