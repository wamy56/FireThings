import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'storage_upload_helper.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/declaration_templates.dart';
import '../models/models.dart';
import '../utils/image_utils.dart';
import '../utils/image_compress_stub.dart'
    if (dart.library.html) '../utils/image_compress_web.dart' as web_compress;
import 'asset_service.dart';
import 'asset_type_service.dart';
import 'bs5839_config_service.dart';
import 'cause_effect_service.dart';
import 'company_pdf_config_service.dart';
import 'competency_service.dart';
import 'defect_service.dart';
import 'floor_plan_service.dart';
import 'inspection_visit_service.dart';
import 'jobsheet_settings_service.dart';
import 'pdf_branding_service.dart';
import 'pdf_footer_builder.dart';
import 'pdf_generation_data.dart';
import 'pdf_widgets/pdf_cover_builder.dart';
import 'pdf_widgets/pdf_field_row.dart';
import 'pdf_widgets/pdf_font_registry.dart';
import 'pdf_widgets/pdf_modern_header.dart';
import 'pdf_widgets/pdf_modern_table.dart';
import 'pdf_widgets/pdf_section_card.dart';
import 'pdf_widgets/pdf_signature_box.dart';
import 'pdf_widgets/pdf_style_helpers.dart';
import 'service_history_service.dart';
import 'user_profile_service.dart';
import 'variation_service.dart';

Uint8List _resizeImageBytes(Uint8List bytes, {int maxWidth = 1200}) {
  return compressImageBytes(bytes, maxWidth: maxWidth, quality: 80);
}

int _hexToColorValue(String hex) {
  final clean = hex.replaceFirst('#', '');
  return 0xFF000000 | int.parse(clean, radix: 16);
}

class Bs5839ReportService {
  Bs5839ReportService._();
  static final Bs5839ReportService instance = Bs5839ReportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Uint8List> generateReport({
    required String basePath,
    required String siteId,
    required String siteName,
    required String siteAddress,
    required String visitId,
    void Function(String phase)? onProgress,
  }) async {
    onProgress?.call('Loading fonts and branding...');

    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {}

    final settings = await JobsheetSettingsService.getSettings();
    final useCompanyBranding = basePath.startsWith('companies/');
    final companyPdf = CompanyPdfConfigService.instance;
    final logoBytes = await companyPdf.getEffectiveLogoBytes(
      useCompanyBranding: useCompanyBranding,
      type: PdfDocumentType.jobsheet,
    );
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

    final engineerName = UserProfileService.instance.resolveEngineerName();
    final companyName = settings.companyName;

    PdfBranding? branding;
    Uint8List? brandingLogoBytes;
    Map<String, Uint8List>? brandedFontBytes;

    try {
      final b = await PdfBrandingService.instance.resolveBrandingForCurrentUser();
      if (b.appliesToDocType(BrandingDocType.report)) {
        branding = b;
        if (b.logoUrl != null) {
          try {
            final response = await http.get(Uri.parse(b.logoUrl!));
            if (response.statusCode == 200) brandingLogoBytes = response.bodyBytes;
          } catch (e) {
            debugPrint('Failed to download branding logo: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load PdfBranding: $e');
    }

    if (branding != null) {
      try {
        await PdfFontRegistry.instance.ensureLoaded();
        brandedFontBytes = PdfFontRegistry.instance.extractFontBytes();
      } catch (e) {
        debugPrint('Failed to load branded fonts: $e');
      }
    }

    final effectiveLogoBytes = brandingLogoBytes ?? logoBytes;

    onProgress?.call('Loading inspection data...');

    final config =
        await Bs5839ConfigService.instance.getConfig(basePath, siteId);
    final visit = await InspectionVisitService.instance
        .getVisit(basePath, siteId, visitId);
    final assets =
        await AssetService.instance.getAssetsStream(basePath, siteId).first;
    final assetTypes =
        await AssetTypeService.instance.getAssetTypes(basePath);
    final records = await ServiceHistoryService.instance
        .getRecordsForSite(basePath, siteId)
        .first;
    final ceTests = await CauseEffectService.instance
        .getTestsForVisitStream(basePath, siteId, visitId)
        .first;
    final variations = await VariationService.instance
        .getVariationsStream(basePath, siteId)
        .first;

    List<LogbookEntry> logbookEntries = [];
    try {
      final snap = await _firestore
          .collection('$basePath/sites/$siteId/logbook_entries')
          .orderBy('occurredAt', descending: true)
          .limit(50)
          .get();
      logbookEntries = snap.docs
          .map((d) {
            try {
              return LogbookEntry.fromJson(d.data());
            } catch (_) {
              return null;
            }
          })
          .whereType<LogbookEntry>()
          .toList();
    } catch (_) {}

    final user = visit != null
        ? await CompetencyService.instance
            .getCompetency(basePath, visit.engineerId)
        : null;

    final defects =
        await DefectService.instance.getDefectsForSite(basePath, siteId);

    final floorPlans = await FloorPlanService.instance
        .getFloorPlansStream(basePath, siteId)
        .first;

    onProgress?.call('Downloading images...');
    final floorPlanImages = <String, Uint8List>{};
    for (final plan in floorPlans) {
      try {
        Uint8List? bytes;
        if (kIsWeb && plan.imageUrl.isNotEmpty) {
          final response = await http.get(Uri.parse(plan.imageUrl));
          if (response.statusCode == 200) bytes = response.bodyBytes;
        } else {
          final ref = _storage.ref(
              '$basePath/sites/$siteId/floor_plans/${plan.id}.${plan.fileExtension}');
          bytes = await ref.getData(5 * 1024 * 1024);
        }
        if (bytes != null) floorPlanImages[plan.id] = bytes;
      } catch (_) {}
    }

    final defectPhotos = <String, Uint8List>{};
    final openWithPhotos = defects
        .where((d) => d.status == Defect.statusOpen && d.photoUrls.isNotEmpty)
        .take(10);
    for (final defect in openWithPhotos) {
      for (final url in defect.photoUrls.take(1)) {
        try {
          Uint8List? bytes;
          if (kIsWeb && url.isNotEmpty) {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) bytes = response.bodyBytes;
          } else {
            final ref = _storage.refFromURL(url);
            bytes = await ref.getData(2 * 1024 * 1024);
          }
          if (bytes != null) defectPhotos[url.hashCode.toString()] = bytes;
        } catch (_) {}
      }
    }

    onProgress?.call('Compressing images...');
    if (kIsWeb) {
      for (final key in floorPlanImages.keys.toList()) {
        await Future.delayed(Duration.zero);
        floorPlanImages[key] = await web_compress.compressImageBytesWeb(
            floorPlanImages[key]!,
            maxWidth: 1200,
            quality: 0.80);
      }
      for (final key in defectPhotos.keys.toList()) {
        await Future.delayed(Duration.zero);
        defectPhotos[key] = await web_compress.compressImageBytesWeb(
            defectPhotos[key]!,
            maxWidth: 800,
            quality: 0.80);
      }
    } else {
      for (final key in floorPlanImages.keys.toList()) {
        floorPlanImages[key] =
            _resizeImageBytes(floorPlanImages[key]!, maxWidth: 1200);
      }
      for (final key in defectPhotos.keys.toList()) {
        defectPhotos[key] =
            _resizeImageBytes(defectPhotos[key]!, maxWidth: 800);
      }
    }

    final effectiveColourValue = branding != null
        ? _hexToColorValue(branding.primaryColour)
        : colourScheme.primaryColorValue;
    final effectiveSecondaryValue = branding != null
        ? _hexToColorValue(branding.accentColour)
        : colourScheme.secondaryColorValue;

    final data = Bs5839ReportPdfData(
      siteName: siteName,
      siteAddress: siteAddress,
      engineerName: engineerName,
      companyName: companyName,
      logoBytes: effectiveLogoBytes,
      headerConfigJson: headerConfig.toJson(),
      footerConfigJson: footerConfig.toJson(),
      colourSchemeValue: effectiveColourValue,
      secondaryColourValue: effectiveSecondaryValue,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      brandingJson: branding?.toJson(),
      brandedFontBytes: brandedFontBytes,
      configJson: config?.toJson() ?? {},
      visitJson: visit?.toJson() ?? {},
      serviceRecordsJson: records
          .where((r) => r.visitId == visitId)
          .map((r) => r.toJson())
          .toList(),
      assetsJson: assets.map((a) => a.toJson()).toList(),
      assetTypesJson: assetTypes.map((t) => t.toJson()).toList(),
      causeEffectTestsJson: ceTests.map((t) => t.toJson()).toList(),
      variationsJson: variations
          .where((v) => v.status == VariationStatus.active)
          .map((v) => v.toJson())
          .toList(),
      logbookEntriesJson: logbookEntries.map((e) => e.toJson()).toList(),
      competencyJson: user?.toJson(),
      defectsJson: defects.map((d) => d.toJson()).toList(),
      floorPlansJson: floorPlans.map((p) => p.toJson()).toList(),
      floorPlanImages: floorPlanImages,
      defectPhotos: defectPhotos,
    );

    onProgress?.call('Building PDF...');
    if (kIsWeb) {
      return _buildReportWeb(data);
    }
    return compute(_buildReport, data);
  }

  Future<String> uploadReport({
    required String basePath,
    required String siteId,
    required String visitId,
    required Uint8List pdfBytes,
  }) async {
    final path = '$basePath/sites/$siteId/bs5839_reports/$visitId.pdf';
    final url =
        await StorageUploadHelper.upload(path, pdfBytes, 'application/pdf');

    await InspectionVisitService.instance.updateVisit(
      basePath,
      siteId,
      visitId,
      {
        'reportPdfUrl': url,
        'reportGeneratedAt': DateTime.now().toIso8601String(),
      },
    );

    return url;
  }

  static Uint8List? _extractFontBytes(pw.Font font) {
    try {
      final ttfFont = font as pw.TtfFont;
      return ttfFont.data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

Future<Uint8List> _buildReport(Bs5839ReportPdfData data) async {
  return _generatePdf(data);
}

Future<Uint8List> _buildReportWeb(Bs5839ReportPdfData data) async {
  return _generatePdf(data);
}

Future<Uint8List> _generatePdf(Bs5839ReportPdfData data) async {
  final colors = PdfColourScheme(primaryColorValue: data.colourSchemeValue);
  final typography = data.typographyJson != null
      ? PdfTypographyConfig.fromJson(data.typographyJson!)
      : const PdfTypographyConfig();
  final sectionStyle = data.sectionStyleJson != null
      ? PdfSectionStyleConfig.fromJson(data.sectionStyleJson!)
      : const PdfSectionStyleConfig();
  final headerConfig = PdfHeaderConfig.fromJson(data.headerConfigJson);
  final footerConfig = PdfFooterConfig.fromJson(data.footerConfigJson);

  PdfBranding? branding;
  if (data.brandingJson != null) {
    branding = PdfBranding.fromJson(data.brandingJson!);
  }

  if (data.brandedFontBytes != null) {
    PdfFontRegistry.instance.loadFromBytes(data.brandedFontBytes!);
  }

  pw.Font? regularFont;
  pw.Font? boldFont;
  try {
    if (data.brandedFontBytes != null) {
      regularFont = PdfFontRegistry.instance.interRegular;
      boldFont = PdfFontRegistry.instance.interBold;
    } else if (data.regularFontBytes != null) {
      regularFont = pw.Font.ttf(data.regularFontBytes!.buffer.asByteData());
      if (data.boldFontBytes != null) {
        boldFont = pw.Font.ttf(data.boldFontBytes!.buffer.asByteData());
      }
    }
  } catch (_) {}

  final theme = pw.ThemeData.withFont(
    base: regularFont,
    bold: boldFont,
  );

  final config = data.configJson.isNotEmpty
      ? Bs5839SystemConfig.fromJson(data.configJson)
      : null;
  final visit = data.visitJson.isNotEmpty
      ? InspectionVisit.fromJson(data.visitJson)
      : null;
  final assets =
      data.assetsJson.map((j) => Asset.fromJson(j)).toList();
  final assetTypes =
      data.assetTypesJson.map((j) => AssetType.fromJson(j)).toList();
  final serviceRecords =
      data.serviceRecordsJson.map((j) => ServiceRecord.fromJson(j)).toList();
  final ceTests =
      data.causeEffectTestsJson.map((j) => CauseEffectTest.fromJson(j)).toList();
  final variations =
      data.variationsJson.map((j) => Bs5839Variation.fromJson(j)).toList();
  final logbook =
      data.logbookEntriesJson.map((j) => LogbookEntry.fromJson(j)).toList();
  final competency = data.competencyJson != null
      ? EngineerCompetency.fromJson(data.competencyJson!)
      : null;
  final defects =
      data.defectsJson.map((j) => Defect.fromJson(j)).toList();
  final df = DateFormat('dd MMM yyyy');
  final dtf = DateFormat('dd MMM yyyy HH:mm');

  final declaration = visit?.declaration ?? InspectionDeclaration.notDeclared;
  final declColor = _declarationPdfColor(declaration);

  final widgets = <pw.Widget>[];

  // ── Cover & Declaration ──
  widgets.add(
    buildModernHeader(
      config: headerConfig,
      colors: colors,
      logoBytes: data.logoBytes,
      documentType: 'BS 5839-1:2025 Inspection Report',
      documentRef: visit?.id ?? '',
    ),
  );
  widgets.add(pw.SizedBox(height: 16));

  widgets.add(
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(declColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            declaration.displayLabel.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: pdfWhite,
              letterSpacing: 1.5,
            ),
          ),
          if (visit?.declarationNotes != null &&
              visit!.declarationNotes!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                visit.declarationNotes!,
                style: pw.TextStyle(fontSize: 9, color: pdfWhite),
                textAlign: pw.TextAlign.center,
              ),
            ),
        ],
      ),
    ),
  );
  widgets.add(pw.SizedBox(height: 16));

  widgets.add(
    buildFieldGrid(
      fields: [
        ('Site Name', data.siteName),
        ('Site Address', data.siteAddress),
        ('System Category', config?.category.displayLabel ?? '—'),
        ('Visit Type', visit?.visitType.displayLabel ?? '—'),
        ('Visit Date', visit != null ? df.format(visit.visitDate) : '—'),
        ('Engineer', data.engineerName),
        ('Declaration', declaration.displayLabel),
        ('Next Service',
            visit?.nextServiceDueDate != null
                ? df.format(visit!.nextServiceDueDate!)
                : '—'),
      ],
      colors: colors,
      typography: typography,
    ),
  );
  widgets.add(pw.SizedBox(height: 8));
  widgets.add(
    pw.Text(
      'This report has been issued in accordance with BS 5839-1:2025',
      style: pw.TextStyle(
        fontSize: 7,
        color: colors.textMuted,
        fontStyle: pw.FontStyle.italic,
      ),
    ),
  );

  // ── System Identification ──
  if (config != null) {
    widgets.add(
      buildSectionCard(
        title: 'System Configuration',
        colors: colors,
        style: sectionStyle,
        children: [
          buildFieldGrid(
            fields: [
              ('Category', config.category.displayLabel),
              ('Justification', config.categoryJustification ?? '—'),
              ('Number of Zones', '${config.numberOfZones}'),
              ('Sleeping Accommodation',
                  config.hasSleepingAccommodation ? 'Yes' : 'No'),
              ('Panel Make', config.panelMake ?? '—'),
              ('Panel Model', config.panelModel ?? '—'),
              ('Panel Serial', config.panelSerialNumber ?? '—'),
              ('ARC Connected', config.arcConnected ? 'Yes' : 'No'),
              if (config.arcConnected) ...[
                ('ARC Provider', config.arcProvider ?? '—'),
                ('ARC Method', config.arcTransmissionMethod.displayLabel),
                ('Max Transmission Time',
                    config.arcMaxTransmissionTimeSeconds != null
                        ? '${config.arcMaxTransmissionTimeSeconds}s'
                        : '—'),
              ],
              ('Commission Date', config.originalCommissionDate != null
                  ? df.format(config.originalCommissionDate!)
                  : '—'),
              ('Last Modification', config.lastModificationDate != null
                  ? df.format(config.lastModificationDate!)
                  : '—'),
            ],
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );

    widgets.add(
      buildSectionCard(
        title: 'Responsible Person',
        colors: colors,
        style: sectionStyle,
        children: [
          buildFieldGrid(
            fields: [
              ('Name', config.responsiblePersonName),
              ('Role', config.responsiblePersonRole ?? '—'),
              ('Email', config.responsiblePersonEmail ?? '—'),
              ('Phone', config.responsiblePersonPhone ?? '—'),
            ],
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  if (competency != null) {
    final qualRows = competency.qualifications.map((q) => [
          q.type == QualificationType.other
              ? (q.customTypeName ?? 'Other')
              : q.type.displayLabel,
          q.issuingBody,
          df.format(q.issuedDate),
          q.expiryDate != null ? df.format(q.expiryDate!) : '—',
        ]).toList();

    widgets.add(
      buildSectionCard(
        title: 'Engineer Competency',
        colors: colors,
        style: sectionStyle,
        children: [
          buildFieldGrid(
            fields: [
              ('Engineer', competency.engineerName),
              ('CPD Hours (12 months)',
                  competency.totalCpdHoursLast12Months.toStringAsFixed(1)),
            ],
            colors: colors,
            typography: typography,
          ),
          if (qualRows.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            buildModernTable(
              headers: ['Qualification', 'Issuing Body', 'Issued', 'Expires'],
              rows: qualRows,
              colors: colors,
              typography: typography,
              columnFlex: [3, 2, 2, 2],
            ),
          ],
        ],
      ),
    );
  }

  // ── Inspection Scope ──
  if (visit != null) {
    final totalAssets =
        assets.where((a) => a.complianceStatus != AssetComplianceStatus.decommissioned).length;
    final testedCount = serviceRecords.length;
    final coverage =
        totalAssets > 0 ? ((testedCount / totalAssets) * 100).round() : 0;

    widgets.add(
      buildSectionCard(
        title: 'This Visit',
        colors: colors,
        style: sectionStyle,
        children: [
          buildFieldGrid(
            fields: [
              ('Visit Type', visit.visitType.displayLabel),
              ('Date', dtf.format(visit.visitDate)),
              ('Assets Tested', '$testedCount of $totalAssets ($coverage%)'),
              ('MCPs Tested', '${visit.mcpIdsTestedThisVisit.length}'),
              ('Logbook Reviewed',
                  visit.logbookReviewed ? 'Yes' : 'No'),
              ('Zone Plan Verified',
                  visit.zonePlanVerified ? 'Yes' : 'No'),
              ('Cyber Security Checks',
                  visit.cyberSecurityChecksCompleted
                      ? 'Completed'
                      : 'N/A'),
              ('ARC Signalling Tested',
                  visit.arcSignallingTested
                      ? 'Yes${visit.arcTransmissionTimeMeasuredSeconds != null ? ' (${visit.arcTransmissionTimeMeasuredSeconds}s)' : ''}'
                      : 'No'),
              ('Earth Fault Test',
                  visit.earthFaultTestPassed
                      ? 'Passed${visit.earthFaultReadingKOhms != null ? ' (${visit.earthFaultReadingKOhms} kΩ)' : ''}'
                      : 'Not tested'),
              ('Battery Tests', '${visit.batteryTestReadings.length} PSUs'),
            ],
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  // ── Asset Inspection Results ──
  if (serviceRecords.isNotEmpty) {
    final assetMap = {for (final a in assets) a.id: a};
    final typeMap = {for (final t in assetTypes) t.id: t};

    final rows = serviceRecords.map((r) {
      final asset = assetMap[r.assetId];
      final typeName = asset != null
          ? (typeMap[asset.assetTypeId]?.name ?? asset.assetTypeId)
          : '—';
      return [
        asset?.reference ?? r.assetId,
        typeName,
        asset?.locationDescription ?? '—',
        asset?.zone ?? '—',
        r.clauseReference ?? '—',
        r.overallResult.toUpperCase(),
      ];
    }).toList();

    widgets.add(
      buildSectionCard(
        title: 'Asset Inspection Results',
        colors: colors,
        style: sectionStyle,
        children: [
          buildModernTable(
            headers: ['Ref', 'Type', 'Location', 'Zone', 'Clause', 'Result'],
            rows: rows,
            colors: colors,
            typography: typography,
            columnFlex: [2, 2, 3, 1, 1, 1],
          ),
        ],
      ),
    );
  }

  // ── Cause & Effect Test Results ──
  if (ceTests.isNotEmpty) {
    for (final test in ceTests) {
      final effectRows = test.expectedEffects.map((e) => [
            e.effectType.displayLabel,
            e.targetDescription ?? '—',
            e.expectedBehaviour,
            e.actualBehaviour ?? '—',
            e.measuredTimeSeconds?.toString() ?? '—',
            e.passed ? 'Pass' : 'Fail',
          ]).toList();

      widgets.add(
        buildSectionCard(
          title:
              'C&E: ${test.triggerAssetReference.isNotEmpty ? test.triggerAssetReference : test.triggerDescription}',
          colors: colors,
          style: sectionStyle,
          children: [
            pw.Text(
              test.triggerDescription,
              style: pw.TextStyle(
                fontSize: typography.fieldValueSize,
                color: colors.textSecondary,
              ),
            ),
            pw.SizedBox(height: 6),
            buildModernTable(
              headers: [
                'Effect',
                'Target',
                'Expected',
                'Actual',
                'Time',
                'Result'
              ],
              rows: effectRows,
              colors: colors,
              typography: typography,
              columnFlex: [2, 2, 3, 3, 1, 1],
            ),
          ],
        ),
      );
    }
  }

  // ── Battery & Sounder Readings ──
  if (visit != null && visit.batteryTestReadings.isNotEmpty) {
    final batteryRows = visit.batteryTestReadings.map((b) => [
          b.powerSupplyAssetId,
          b.restingVoltage.toStringAsFixed(1),
          b.loadedVoltage.toStringAsFixed(1),
          b.loadCurrentAmps?.toStringAsFixed(1) ?? '—',
          b.passed ? 'Pass' : 'Fail',
        ]).toList();

    widgets.add(
      buildSectionCard(
        title: 'Battery Load Test Readings',
        colors: colors,
        style: sectionStyle,
        children: [
          buildModernTable(
            headers: ['PSU Ref', 'Resting V', 'Loaded V', 'Load A', 'Result'],
            rows: batteryRows,
            colors: colors,
            typography: typography,
            columnFlex: [3, 2, 2, 2, 1],
          ),
        ],
      ),
    );
  }

  // ── Variations Register ──
  final prohibited = variations.where((v) => v.isProhibited).toList();
  final permissible = variations.where((v) => !v.isProhibited).toList();

  if (variations.isNotEmpty) {
    final varChildren = <pw.Widget>[];

    if (permissible.isNotEmpty) {
      varChildren.add(
        pw.Text(
          'Permissible Variations',
          style: pw.TextStyle(
            fontSize: typography.fieldLabelSize + 2,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFFF97316),
          ),
        ),
      );
      varChildren.add(pw.SizedBox(height: 4));
      varChildren.add(
        buildModernTable(
          headers: ['Clause', 'Description', 'Justification', 'Agreed By', 'Date'],
          rows: permissible.map((v) => [
                v.clauseReference,
                v.description,
                v.justification,
                v.agreedByName ?? '—',
                v.dateAgreed != null ? df.format(v.dateAgreed!) : '—',
              ]).toList(),
          colors: colors,
          typography: typography,
          columnFlex: [1, 3, 3, 2, 1],
        ),
      );
    }

    if (prohibited.isNotEmpty) {
      if (permissible.isNotEmpty) {
        varChildren.add(pw.SizedBox(height: 12));
      }
      varChildren.add(
        pw.Text(
          'PROHIBITED VARIATIONS — NON-COMPLIANCE',
          style: pw.TextStyle(
            fontSize: typography.fieldLabelSize + 2,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFFD32F2F),
          ),
        ),
      );
      varChildren.add(pw.SizedBox(height: 4));
      varChildren.add(
        buildModernTable(
          headers: ['Clause', 'Description', 'Rule', 'Logged'],
          rows: prohibited.map((v) => [
                v.clauseReference,
                v.description,
                v.prohibitedRuleId ?? '—',
                df.format(v.loggedAt),
              ]).toList(),
          colors: colors,
          typography: typography,
          columnFlex: [1, 3, 2, 1],
        ),
      );
    }

    widgets.add(
      buildSectionCard(
        title: 'Variations Register',
        colors: colors,
        style: sectionStyle,
        children: varChildren,
      ),
    );
  } else {
    widgets.add(
      buildSectionCard(
        title: 'Variations Register',
        colors: colors,
        style: sectionStyle,
        children: [
          pw.Text(
            'No variations recorded for this site.',
            style: pw.TextStyle(
              fontSize: typography.fieldValueSize,
              color: colors.textMuted,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Defects & Remedial Actions ──
  final openDefects = defects.where((d) => d.status == Defect.statusOpen).toList();
  if (openDefects.isNotEmpty) {
    final assetMap = {for (final a in assets) a.id: a};
    final defectRows = openDefects.map((d) {
      final asset = assetMap[d.assetId];
      return [
        asset?.reference ?? d.assetId,
        d.severity,
        d.description,
        d.action ?? '—',
        d.severity == Defect.severityCritical ? 'Immediate' : '28 days',
      ];
    }).toList();

    widgets.add(
      buildSectionCard(
        title: 'Defects & Remedial Actions',
        colors: colors,
        style: sectionStyle,
        children: [
          buildModernTable(
            headers: ['Asset Ref', 'Severity', 'Description', 'Action', 'Timescale'],
            rows: defectRows,
            colors: colors,
            typography: typography,
            columnFlex: [2, 1, 4, 2, 1],
          ),
        ],
      ),
    );
  }

  // ── Logbook Summary (last 90 days) ──
  final cutoff90 = DateTime.now().subtract(const Duration(days: 90));
  final recentLogbook =
      logbook.where((e) => e.occurredAt.isAfter(cutoff90)).toList();
  if (recentLogbook.isNotEmpty) {
    widgets.add(
      buildSectionCard(
        title: 'Logbook Summary (Last 90 Days)',
        colors: colors,
        style: sectionStyle,
        children: [
          buildModernTable(
            headers: ['Date', 'Type', 'Description', 'Logged By'],
            rows: recentLogbook.map((e) => [
                  df.format(e.occurredAt),
                  e.type.displayLabel,
                  e.description,
                  e.loggedByName ?? '—',
                ]).toList(),
            colors: colors,
            typography: typography,
            columnFlex: [2, 2, 4, 2],
          ),
        ],
      ),
    );
  }

  // ── Declaration & Signatures ──
  final categoryLabel = config?.category.displayLabel ?? '—';
  String declarationText;
  switch (declaration) {
    case InspectionDeclaration.satisfactory:
      declarationText = DeclarationTemplates.satisfactory;
    case InspectionDeclaration.satisfactoryWithVariations:
      declarationText = DeclarationTemplates.satisfactoryWithVariations;
    case InspectionDeclaration.unsatisfactory:
      declarationText = DeclarationTemplates.unsatisfactory;
    case InspectionDeclaration.notDeclared:
      declarationText = DeclarationTemplates.notDeclared;
  }
  declarationText = declarationText.replaceAll('{category}', categoryLabel);

  widgets.add(
    buildSectionCard(
      title: 'Declaration',
      colors: colors,
      style: sectionStyle,
      children: [
        pw.Text(
          declarationText,
          style: pw.TextStyle(
            fontSize: typography.fieldValueSize,
            color: colors.textPrimary,
          ),
        ),
      ],
    ),
  );
  widgets.add(pw.SizedBox(height: 8));

  widgets.add(
    buildSignatureSection(
      engineerSignatureBase64: visit?.engineerSignatureBase64,
      customerSignatureBase64: visit?.responsiblePersonSignatureBase64,
      engineerName: data.engineerName,
      customerName: visit?.responsiblePersonSignedName,
      date: visit != null ? df.format(visit.completedAt ?? visit.visitDate) : '—',
      colors: colors,
      typography: typography,
    ),
  );
  widgets.add(pw.SizedBox(height: 8));
  widgets.add(
    pw.Text(
      'Reported against BS 5839-1:2025 — Standard version: ${config?.standardVersion ?? "BS 5839-1:2025"}',
      style: pw.TextStyle(
        fontSize: 7,
        color: colors.textMuted,
        fontStyle: pw.FontStyle.italic,
      ),
    ),
  );

  final doc = pw.Document(theme: theme);

  final visitDate = visit?.visitDate != null
      ? df.format(visit!.visitDate)
      : df.format(DateTime.now());

  if (branding != null && data.brandedFontBytes != null) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => PdfCoverBuilder.build(
        branding: branding!,
        docType: BrandingDocType.report,
        defaultEyebrow: 'BS 5839-1:2025',
        defaultTitle: 'Inspection\nReport',
        defaultSubtitle: '${data.siteName} · $visitDate',
        metaFields: [
          (label: 'Site', value: data.siteName),
          (label: 'Address', value: data.siteAddress),
          (label: 'Engineer', value: data.engineerName),
          (label: 'Date', value: visitDate),
          (label: 'Declaration', value: declaration.displayLabel),
        ],
        logoBytes: data.logoBytes,
        companyName: data.companyName,
      ),
    ));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: branding != null && data.brandedFontBytes != null
          ? (context) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: PdfHeaderBuilder.build(
                  branding: branding!,
                  companyName: data.companyName,
                  metaText: 'BS 5839-1 INSPECTION · $visitDate',
                  logoBytes: data.logoBytes,
                ),
              )
          : null,
      footer: branding != null && data.brandedFontBytes != null
          ? (context) => PdfFooterBuilder.buildBrandedFooter(
                branding: branding!,
                pageNumber: context.pageNumber,
                pagesCount: context.pagesCount,
                companyName: data.companyName,
                defaultFooterText: 'BS 5839-1 Inspection Report · ${data.siteName}',
              )
          : (context) => PdfFooterBuilder.buildFooter(
                config: footerConfig,
                pageNumber: context.pageNumber,
                pagesCount: context.pagesCount,
              ),
      build: (_) => widgets,
    ),
  );

  return doc.save();
}

int _declarationPdfColor(InspectionDeclaration declaration) {
  switch (declaration) {
    case InspectionDeclaration.satisfactory:
      return 0xFF4CAF50;
    case InspectionDeclaration.satisfactoryWithVariations:
      return 0xFFF97316;
    case InspectionDeclaration.unsatisfactory:
      return 0xFFD32F2F;
    case InspectionDeclaration.notDeclared:
      return 0xFF9E9E9E;
  }
}
