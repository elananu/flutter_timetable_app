// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../models/teacher_model.dart';
import '../models/timetable_config.dart';
import '../services/timetable_generator.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  final String mode; // 'school' | 'college'
  const HomeScreen({super.key, required this.mode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _step = 1;

  final _standardCtrl    = TextEditingController();
  final _sectionsCtrl    = TextEditingController();
  final _subjectsCtrl    = TextEditingController();
  final _periodsCtrl     = TextEditingController();
  final _departmentCtrl  = TextEditingController();
  int _workingDays = 5;

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  List<TextEditingController> _subjectCtrls = [];

  int _numSections = 1;
  List<String> _sectionNames = ['A'];
  List<TextEditingController> _sectionTeacherCountCtrls = [];
  List<List<TextEditingController>> _sectionTeacherNameCtrls = [];
  List<List<Set<String>>>           _sectionTeacherSubjects   = [];

  int _activeTeacherSection = 0;

  bool get _isCollege => widget.mode == 'college';
  String get _stdLabel  => _isCollege ? 'Semester'   : 'Standard';
  String get _secLabel  => _isCollege ? 'Divisions'  : 'Sections';
  String get _tchLabel  => _isCollege ? 'Faculty'    : 'Teachers';

  Color get _accentColor =>
      _isCollege ? const Color(0xFF0E9F6E) : const Color(0xFF1A56DB);

  @override
  void dispose() {
    for (final c in [
      _standardCtrl, _sectionsCtrl, _subjectsCtrl,
      _periodsCtrl, _departmentCtrl,
      ..._subjectCtrls, ..._sectionTeacherCountCtrls,
      ..._sectionTeacherNameCtrls.expand((l) => l)
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Date Pickers ──────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
        if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
          _selectedEndDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? (_selectedStartDate ?? DateTime.now()),
      firstDate: _selectedStartDate ?? DateTime(2020), lastDate: DateTime(2100),
      helpText: 'Select End Date',
    );
    if (picked != null) setState(() => _selectedEndDate = picked);
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ── Step navigation ───────────────────────────────────────────────────

  void _goToStep2() {
    final n = int.tryParse(_subjectsCtrl.text) ?? 0;
    if (n < 1) { _snack('Enter number of subjects'); return; }
    _subjectCtrls = List.generate(n.clamp(1, 15), (_) => TextEditingController());
    setState(() => _step = 2);
  }

  void _goToStep3() {
    final subjects = _subjectCtrls.map((c) => c.text.trim()).toList();
    if (subjects.any((s) => s.isEmpty)) {
      _snack('Fill in all subject names'); return;
    }

    _numSections = (int.tryParse(_sectionsCtrl.text) ?? 1).clamp(1, 10);
    _sectionNames = List.generate(_numSections, (i) => String.fromCharCode(65 + i));

    _sectionTeacherCountCtrls = List.generate(_numSections, (_) => TextEditingController());
    _sectionTeacherNameCtrls  = List.generate(_numSections, (_) => []);
    _sectionTeacherSubjects   = List.generate(_numSections, (_) => []);
    _activeTeacherSection = 0;

    setState(() => _step = 3);
  }

  void _applyTeacherCount(int secIdx) {
    final count = (int.tryParse(_sectionTeacherCountCtrls[secIdx].text) ?? 0).clamp(1, 30);
    setState(() {
      _sectionTeacherNameCtrls[secIdx] =
          List.generate(count, (_) => TextEditingController());
      _sectionTeacherSubjects[secIdx] =
          List.generate(count, (_) => <String>{});
    });
  }

  Future<void> _generate() async {
    for (int i = 0; i < _numSections; i++) {
      if (_sectionTeacherNameCtrls[i].isEmpty) {
        _snack('Set $_tchLabel count for ${_secLabel.replaceAll('s', '')} ${_sectionNames[i]}');
        return;
      }
      final names = _sectionTeacherNameCtrls[i].map((c) => c.text.trim()).toList();
      if (names.any((n) => n.isEmpty)) {
        _snack('Fill all $_tchLabel names in ${_secLabel.replaceAll('s', '')} ${_sectionNames[i]}');
        return;
      }
    }

    final subjects = _subjectCtrls.map((c) => c.text.trim()).toList();

    final teachersBySection = List.generate(_numSections, (si) {
      final names = _sectionTeacherNameCtrls[si].map((c) => c.text.trim()).toList();
      return List.generate(names.length, (ti) => TeacherModel(
        name: names[ti],
        subjects: _sectionTeacherSubjects[si][ti].isEmpty
            ? [subjects[ti % subjects.length]]
            : _sectionTeacherSubjects[si][ti].toList(),
      ));
    });

    final config = TimetableConfig(
      mode:            widget.mode,
      standard:        int.tryParse(_standardCtrl.text) ?? 1,
      numSections:     _numSections,
      numSubjects:     subjects.length,
      periodsPerDay:   (int.tryParse(_periodsCtrl.text) ?? 4).clamp(4, 12),
      workingDays:     _workingDays,
      subjects:        subjects,
      teachersBySection: teachersBySection,
      startDate:       _selectedStartDate,
      endDate:         _selectedEndDate,
      departmentName:  _isCollege ? _departmentCtrl.text.trim() : null,
    );

    setState(() => _step = 4);
    final gen = TimetableGenerator(config: config);
    await gen.generate();

    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => TimetableScreen(generator: gen)));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _accentColor,
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Icon(Icons.calendar_month_rounded,
                color: Colors.white, size: 18)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _isCollege ? 'College Time' : 'TimeTable',
              style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 16, color: Colors.white)),
            Text(
              _isCollege ? 'College Mode' : 'School Mode',
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        ]),
      ),
      body: Column(children: [
        _stepIndicator(cs),
        Expanded(child: _buildStep(cs)),
      ]),
    );
  }

  // ── Step Indicator ────────────────────────────────────────────────────

  Widget _stepIndicator(ColorScheme cs) {
    const labels = ['Setup', 'Subjects', 'Staff', 'Generate'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: List.generate(4, (i) {
          final step   = i + 1;
          final done   = step < _step;
          final active = step == _step;
          final accent = _accentColor;
          final color  = done ? accent : active ? accent : const Color(0xFFE5E7EB);
          final textColor = (done || active) ? Colors.white : const Color(0xFF9CA3AF);
          return Expanded(child: Row(children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${done ? "✓" : step} · ${labels[i]}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: textColor),
                ),
              ),
            ),
            if (i < 3) Container(width: 4, height: 2, color: const Color(0xFFE5E7EB)),
          ]));
        }),
      ),
    );
  }

  Widget _buildStep(ColorScheme cs) {
    switch (_step) {
      case 1:  return _step1(cs);
      case 2:  return _step2(cs);
      case 3:  return _step3(cs);
      default: return _loadingView(cs);
    }
  }

  // ── STEP 1 ────────────────────────────────────────────────────────────

  Widget _step1(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('${widget.mode.toUpperCase()} SCHEDULE SETUP'),
        const SizedBox(height: 12),

        // Department name → TEXT keyboard (college only)
        if (_isCollege) ...[
          _textField(
            ctrl: _departmentCtrl,
            label: 'Department Name',
            icon: Icons.business_rounded,
          ),
          const SizedBox(height: 12),
        ],

        // Semester/Standard + Sections → NUMBER keyboard
        Row(children: [
          Expanded(child: _numberField(ctrl: _standardCtrl,
              label: _stdLabel, icon: Icons.layers_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _numberField(ctrl: _sectionsCtrl,
              label: _secLabel, icon: Icons.grid_view_rounded)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _numberField(ctrl: _subjectsCtrl,
              label: 'No. of Subjects', icon: Icons.book_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _numberField(ctrl: _periodsCtrl,
              label: 'Periods / Day', icon: Icons.schedule_rounded)),
        ]),
        const SizedBox(height: 12),
        _workingDaysDrop(),
        const SizedBox(height: 12),
        _datePicker(
          label: _selectedStartDate == null
              ? 'Start Date (optional)'
              : 'Start: ${_fmt(_selectedStartDate!)}',
          icon: Icons.calendar_today_rounded,
          color: _accentColor,
          hasValue: _selectedStartDate != null,
          onTap: _pickStartDate,
          onClear: () => setState(() => _selectedStartDate = null),
        ),
        const SizedBox(height: 10),
        _datePicker(
          label: _selectedEndDate == null
              ? 'End Date (optional)'
              : 'End: ${_fmt(_selectedEndDate!)}',
          icon: Icons.event_rounded,
          color: const Color(0xFFF05252),
          hasValue: _selectedEndDate != null,
          onTap: _pickEndDate,
          onClear: () => setState(() => _selectedEndDate = null),
        ),
        const SizedBox(height: 32),
        _primaryBtn('Next: Enter Subjects →', _goToStep2),
      ]),
    );
  }

  // ── STEP 2 ────────────────────────────────────────────────────────────

  Widget _step2(ColorScheme cs) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enter Subject Names',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: _accentColor)),
          Text('${_subjectCtrls.length} subjects · $_stdLabel ${_standardCtrl.text}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: _subjectCtrls.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            // Subject names → TEXT keyboard
            child: _fieldWithIndex(ctrl: _subjectCtrls[i], index: i + 1,
                label: 'Subject ${i + 1}'),
          ),
        ),
      ),
      _bottomNav(
        onBack: () => setState(() => _step = 1),
        onNext: _goToStep3,
        nextLabel: 'Next: Enter $_tchLabel →',
      ),
    ]);
  }

  // ── STEP 3: Per-section teachers ──────────────────────────────────────

  Widget _step3(ColorScheme cs) {
    final subjects = _subjectCtrls.map((c) => c.text.trim()).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_tchLabel per ${_secLabel.replaceAll('s', '')}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: _accentColor)),
          Text('Set count and names for each ${_secLabel.replaceAll('s', '')}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ]),
      ),
      Container(
        height: 40,
        margin: const EdgeInsets.only(top: 6),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _numSections,
          itemBuilder: (_, i) {
            final active = i == _activeTeacherSection;
            return GestureDetector(
              onTap: () => setState(() => _activeTeacherSection = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: active ? _accentColor : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(
                  '${_standardCtrl.text}${_sectionNames[i]}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: active ? Colors.white : const Color(0xFF6B7280)),
                )),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: _sectionTeacherPanel(_activeTeacherSection, subjects)),
      _bottomNav(
        onBack: () => setState(() => _step = 2),
        onNext: _generate,
        nextLabel: '✦ Generate Timetable',
        nextColor: _accentColor,
      ),
    ]);
  }

  Widget _sectionTeacherPanel(int secIdx, List<String> subjects) {
    final hasTeachers = _sectionTeacherNameCtrls[secIdx].isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _sectionTeacherCountCtrls[secIdx],
              keyboardType: TextInputType.number, // count → number keyboard
              style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Number of $_tchLabel',
                prefixIcon: const Icon(Icons.person_add_rounded, size: 18,
                    color: Color(0xFF6B7280)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => _applyTeacherCount(secIdx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Set'),
          ),
        ]),
        const SizedBox(height: 12),
        if (!hasTeachers)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              'Enter number of $_tchLabel above and tap "Set"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          )
        else
          ...List.generate(_sectionTeacherNameCtrls[secIdx].length,
              (ti) => _teacherCard(secIdx, ti, subjects)),
      ]),
    );
  }

  Widget _teacherCard(int secIdx, int ti, List<String> subjects) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text('T${ti + 1}',
              style: TextStyle(color: _accentColor,
                  fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _sectionTeacherNameCtrls[secIdx][ti],
              keyboardType: TextInputType.name,       // ← text keyboard
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 13),
              decoration: InputDecoration(
                hintText: '$_tchLabel name',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Text('Subjects (tap to assign):',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: subjects.map((sub) {
            final sel = _sectionTeacherSubjects[secIdx][ti].contains(sub);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) _sectionTeacherSubjects[secIdx][ti].remove(sub);
                else _sectionTeacherSubjects[secIdx][ti].add(sub);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? _accentColor : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? _accentColor : const Color(0xFFD1D5DB)),
                ),
                child: Text(sub,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : const Color(0xFF6B7280))),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────

  Widget _loadingView(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 3)),
          ),
          const SizedBox(height: 24),
          const Text('Generating timetable...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: Color(0xFF1A1F36))),
          const SizedBox(height: 8),
          const Text('Arranging subjects and assigning teachers',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────────

  Widget _sectionHeader(String text) => Text(text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
        letterSpacing: 0.8, color: Color(0xFF6B7280)));

  /// TEXT keyboard — department name, teacher names, subject names
  Widget _textField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }

  /// NUMBER keyboard — semester, sections, subject count, periods/day
  Widget _numberField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }

  Widget _datePicker({
    required String label, required IconData icon,
    required Color color, required bool hasValue,
    required VoidCallback onTap, required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasValue ? color.withOpacity(0.5) : const Color(0xFFD1D5DB)),
        ),
        child: Row(children: [
          Icon(icon, size: 18,
              color: hasValue ? color : const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
            style: TextStyle(fontSize: 14,
              color: hasValue ? const Color(0xFF1A1F36) : const Color(0xFF9CA3AF)))),
          if (hasValue)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
            ),
        ]),
      ),
    );
  }

  /// Indexed field for subject names — TEXT keyboard
  Widget _fieldWithIndex({
    required TextEditingController ctrl,
    required int index,
    required String label,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(8), width: 30, height: 30,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Text('$index',
            style: TextStyle(color: _accentColor,
                fontWeight: FontWeight.bold, fontSize: 12))),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }

  Widget _workingDaysDrop() {
    return DropdownButtonFormField<int>(
      value: _workingDays,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF1A1F36), fontSize: 14),
      decoration: const InputDecoration(
        labelText: 'Working Days',
        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18,
            color: Color(0xFF9CA3AF)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      items: const [
        DropdownMenuItem(value: 5, child: Text('Mon – Fri (5 days)')),
        DropdownMenuItem(value: 6, child: Text('Mon – Sat (6 days)')),
      ],
      onChanged: (v) => setState(() => _workingDays = v!),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? _accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _bottomNav({
    required VoidCallback onBack, required VoidCallback onNext,
    required String nextLabel, Color? nextColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            foregroundColor: const Color(0xFF6B7280),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: nextColor ?? _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            child: Text(nextLabel),
          ),
        ),
      ]),
    );
  }
}
