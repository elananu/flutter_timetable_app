// lib/screens/timetable_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/period_slot.dart';
import '../models/timetable_config.dart';
import '../services/timetable_generator.dart';
import 'home_screen.dart';

class TimetableScreen extends StatefulWidget {
  final TimetableGenerator generator;
  const TimetableScreen({super.key, required this.generator});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late String _activeSection;
  Set<String> _absentTeachers = {};
  String? _absentDay;
  bool _loading = false;
  String _loadingMsg = '';

  TimetableConfig get _config => widget.generator.config;
  Map<String, Map<String, List<PeriodSlot>>> get _tt =>
      widget.generator.timetable;

  bool get _isCollege => _config.mode == 'college';

  Color get _accentColor =>
      _isCollege ? const Color(0xFF0E9F6E) : const Color(0xFF1A56DB);

  @override
  void initState() {
    super.initState();
    _activeSection = _config.sections.first;
    _absentDay = _config.days.first;
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _regenerate() async {
    setState(() {
      _loading = true;
      _loadingMsg = 'Regenerating timetable…';
    });
    await widget.generator.generate();
    if (mounted) setState(() => _loading = false);
    _snack('Timetable regenerated');
  }

  Future<void> _assignSubs() async {
    if (_absentTeachers.isEmpty) {
      _snack('No teachers marked absent');
      return;
    }
    if (_absentDay == null) {
      _snack('Select a day for absence');
      return;
    }
    setState(() {
      _loading = true;
      _loadingMsg = 'Assigning substitutes…';
    });
    await widget.generator.assignSubstitutes(_absentTeachers, _absentDay!);
    if (mounted) setState(() => _loading = false);
    _snack('Substitutes assigned for $_absentDay');
  }

  void _clearAbsent() {
    widget.generator.clearSubstitutes(targetDay: _absentDay);
    setState(() => _absentTeachers = {});
    _snack(
        'Cleared substitutes${_absentDay != null ? " for $_absentDay" : ""}');
  }

  // ── PDF Export ─────────────────────────────────────────────────────────

  Future<void> _downloadPDF() async {
    try {
      setState(() {
        _loading = true;
        _loadingMsg = 'Generating PDF…';
      });

      final pdf = pw.Document();

      for (final sec in _config.sections) {
        final days  = _config.days;
        final slots = _tt[sec] ?? {};

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: _isCollege
                          ? PdfColor.fromHex('#0E9F6E')
                          : PdfColor.fromHex('#1A56DB'),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _isCollege ? 'College Time' : 'TimeTable',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _config.mode == 'college'
                              ? '${_config.departmentName ?? "Department"} · '
                                  'Semester ${_config.standard} · '
                                  'Division ${_config.standard}$sec'
                              : 'Standard ${_config.standard} · Section $sec',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                          ),
                        ),
                        if (_config.startDate != null ||
                            _config.endDate != null)
                          pw.Text(
                            [
                              if (_config.startDate != null)
                                'From: ${_fmt(_config.startDate!)}',
                              if (_config.endDate != null)
                                'To: ${_fmt(_config.endDate!)}',
                            ].join('   '),
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  // ── Table ────────────────────────────────────────────
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColor.fromHex('#D1D5DB'),
                      width: 0.5,
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(55),
                      for (int i = 1;
                          i <= _config.periodsPerDay;
                          i++)
                        i: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F3F4F6'),
                        ),
                        children: [
                          _pdfCell('Day',
                              bold: true, bg: PdfColor.fromHex('#F3F4F6')),
                          ...List.generate(
                            _config.periodsPerDay,
                            (i) => _pdfCell('Period ${i + 1}',
                                bold: true,
                                bg: PdfColor.fromHex('#F3F4F6')),
                          ),
                        ],
                      ),
                      // Data rows
                      ...days.asMap().entries.map((entry) {
                        final daySlots = slots[entry.value] ?? [];
                        final isEven = entry.key % 2 == 0;
                        final rowBg = isEven
                            ? PdfColors.white
                            : PdfColor.fromHex('#F9FAFB');
                        return pw.TableRow(
                          decoration:
                              pw.BoxDecoration(color: rowBg),
                          children: [
                            _pdfCell(
                              entry.value.substring(0, 3).toUpperCase(),
                              bold: true,
                              textColor: _isCollege
                                  ? PdfColor.fromHex('#0E9F6E')
                                  : PdfColor.fromHex('#1A56DB'),
                              bg: rowBg,
                            ),
                            ...List.generate(_config.periodsPerDay, (p) {
                              if (p < daySlots.length) {
                                final slot = daySlots[p];
                                return _pdfPeriodCell(slot, rowBg);
                              }
                              return _pdfCell('—', bg: rowBg);
                            }),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated by TimeTable App · ${DateTime.now().day}/'
                    '${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey),
                  ),
                ],
              );
            },
          ),
        );
      }

      final dir  = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/timetable_${_config.mode}_std${_config.standard}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) setState(() => _loading = false);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject:
            'Timetable – ${_config.standardLabel} ${_config.standard}',
        text: 'TimeTable PDF',
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack('PDF export failed: $e');
    }
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    PdfColor? textColor,
    PdfColor? bg,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfPeriodCell(PeriodSlot slot, PdfColor bg) {
    final isSub = slot.hasSubstitute;
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            slot.subject,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold),
            maxLines: 1,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${isSub ? "↔ " : ""}${slot.teacher}',
            style: pw.TextStyle(
              fontSize: 8,
              color: isSub
                  ? PdfColor.fromHex('#0E9F6E')
                  : PdfColors.grey600,
              fontStyle: isSub
                  ? pw.FontStyle.italic
                  : pw.FontStyle.normal,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(
          content: Text(msg), behavior: SnackBarBehavior.floating));

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _accentColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _isCollege ? 'College Time' : 'TimeTable',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white),
          ),
          Text(
            _config.mode == 'college'
                ? '${_config.departmentName ?? "College"} · '
                    'Sem ${_config.standard} · '
                    '${_config.sections.length} divisions'
                : 'Std ${_config.standard} · '
                    '${_config.sections.length} sections · '
                    '${_config.periodsPerDay} periods/day',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            tooltip: 'Download PDF',
            onPressed: _loading ? null : _downloadPDF,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Regenerate',
            onPressed: _loading ? null : _regenerate,
          ),
        ],
      ),
      body: _loading ? _loadingView() : _body(),
    );
  }

  Widget _loadingView() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _accentColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator(
            color: Colors.white, strokeWidth: 3)),
      ),
      const SizedBox(height: 20),
      Text(_loadingMsg,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: Color(0xFF1A1F36))),
    ]));
  }

  Widget _body() {
    return Column(children: [
      _statsRow(),
      _sectionTabs(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _timetableGrid(),
            const SizedBox(height: 16),
            _absentPanel(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
      _bottomBar(),
    ]);
  }

  // ── Stats ──────────────────────────────────────────────────────────────

  Widget _statsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _stat('${_config.sections.length}', _config.sectionLabel,
              _accentColor),
          _stat(_config.numTeachers, _config.teacherLabel,
              const Color(0xFFF05252)),
          _stat('${_config.subjects.length}', 'Subjects',
              const Color(0xFFF59E0B)),
          _stat('${_config.periodsPerWeek}', 'Periods/Wk',
              const Color(0xFF7C3AED)),
        ]),
      ),
    );
  }

  Widget _stat(String val, String lbl, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(val,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(lbl,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
      ]),
    );
  }

  // ── Section tabs ───────────────────────────────────────────────────────

  Widget _sectionTabs() {
    return Container(
      height: 44,
      color: const Color(0xFFF4F6FA),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _config.sections.length,
        itemBuilder: (_, i) {
          final sec    = _config.sections[i];
          final active = sec == _activeSection;
          return GestureDetector(
            onTap: () => setState(() => _activeSection = sec),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: active ? _accentColor : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: active
                        ? _accentColor
                        : const Color(0xFFD1D5DB)),
                boxShadow: active
                    ? [BoxShadow(
                        color: _accentColor.withOpacity(0.2),
                        blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Center(child: Text(
                '${_config.standard}$sec',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13,
                  color: active ? Colors.white : const Color(0xFF6B7280)),
              )),
            ),
          );
        },
      ),
    );
  }

  // ── Grid ───────────────────────────────────────────────────────────────

  Widget _timetableGrid() {
    final days = _config.days;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(
                color: const Color(0xFFE5E7EB), width: 1),
            defaultColumnWidth: const FixedColumnWidth(108),
            columnWidths: const {0: FixedColumnWidth(72)},
            children: [
              TableRow(
                decoration:
                    const BoxDecoration(color: Color(0xFFF3F4F6)),
                children: [
                  _th('Day'),
                  ...List.generate(_config.periodsPerDay,
                      (i) => _th('P${i + 1}', accent: _accentColor)),
                ],
              ),
              ...days.asMap().entries.map((entry) {
                final day    = entry.value;
                final idx    = entry.key;
                final slots  = _tt[_activeSection]?[day] ?? [];
                final hasAbsent = slots.any(
                    (s) => _absentTeachers.contains(s.originalTeacher));
                final isAbsentDay = day == _absentDay;
                return TableRow(
                  decoration: BoxDecoration(
                    color: (hasAbsent && isAbsentDay)
                        ? const Color(0xFFF05252).withOpacity(0.05)
                        : idx % 2 == 0
                            ? Colors.white
                            : const Color(0xFFF9FAFB),
                  ),
                  children: [
                    _dayCell(day, hasAbsent && isAbsentDay),
                    ...List.generate(_config.periodsPerDay, (p) =>
                        p < slots.length
                            ? _periodCell(slots[p])
                            : _emptyCell()),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _th(String t, {Color? accent}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Text(t,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: accent ?? const Color(0xFF6B7280))),
  );

  Widget _dayCell(String day, bool hasAbsent) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(day.substring(0, 3).toUpperCase(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        color: hasAbsent
            ? const Color(0xFFF05252)
            : _accentColor)),
  );

  Widget _periodCell(PeriodSlot slot) {
    final isSub = slot.hasSubstitute;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(slot.subject,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            if (isSub)
              const Text('↔ ',
                  style: TextStyle(fontSize: 9, color: Color(0xFF0E9F6E))),
            Expanded(
              child: Text(slot.teacher,
                style: TextStyle(
                  fontSize: 10,
                  color: isSub
                      ? const Color(0xFF0E9F6E)
                      : const Color(0xFF9CA3AF),
                  fontStyle:
                      isSub ? FontStyle.italic : FontStyle.normal,
                  fontWeight:
                      isSub ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _emptyCell() => const Padding(
    padding: EdgeInsets.all(8),
    child: Text('—',
        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
  );

  // ── Absent Panel ───────────────────────────────────────────────────────

  Widget _absentPanel() {
    final teachers = _config.teachersForSection(_activeSection);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF05252).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_off_rounded,
                size: 16, color: Color(0xFFF05252)),
          ),
          const SizedBox(width: 10),
          const Text('Absent · Substitute Manager',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: Color(0xFF1A1F36))),
        ]),
        const SizedBox(height: 4),
        const Text('Pick a day, mark absent teachers, then assign subs',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),

        // Day selector
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _config.days.map((day) {
              final sel = day == _absentDay;
              return GestureDetector(
                onTap: () => setState(() => _absentDay = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFF05252).withOpacity(0.1)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFFF05252)
                            : const Color(0xFFD1D5DB)),
                  ),
                  child: Text(day.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: sel
                          ? const Color(0xFFF05252)
                          : const Color(0xFF6B7280))),
                ),
              );
            }).toList(),
          ),
        ),

        // Teacher chips
        const SizedBox(height: 12),
        if (teachers.isEmpty)
          const Text('No teachers for this section',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: teachers.map((t) {
              final absent = _absentTeachers.contains(t.name);
              return GestureDetector(
                onTap: () => setState(() {
                  if (absent) _absentTeachers.remove(t.name);
                  else _absentTeachers.add(t.name);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: absent
                        ? const Color(0xFFF05252).withOpacity(0.1)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: absent
                            ? const Color(0xFFF05252)
                            : const Color(0xFFD1D5DB)),
                  ),
                  child: Text(t.name,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: absent
                          ? const Color(0xFFF05252)
                          : const Color(0xFF6B7280))),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _assignSubs,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(
                  'Assign for ${_absentDay?.substring(0, 3) ?? "Day"}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _clearAbsent,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
            ),
            child: const Text('Clear'),
          ),
        ]),
      ]),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => HomeScreen(mode: _config.mode)),
            (route) => false,
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('New'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            foregroundColor: const Color(0xFF6B7280),
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _loading ? null : _downloadPDF,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: const Text('PDF'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _accentColor.withOpacity(0.5)),
            foregroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _regenerate,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Regenerate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }
}
