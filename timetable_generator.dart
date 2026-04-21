// lib/services/timetable_generator.dart

import 'dart:math';
import '../models/period_slot.dart';
import '../models/timetable_config.dart';
import '../models/teacher_model.dart';

typedef TimetableData = Map<String, Map<String, List<PeriodSlot>>>;

class TimetableGenerator {
  final TimetableConfig config;
  TimetableData timetable = {};

  TimetableGenerator({required this.config});

  // ── PUBLIC API ─────────────────────────────────────────────────────────

  Future<void> generate() async => _generateLocally();

  /// Assigns substitutes ONLY for [targetDay] in every section.
  Future<void> assignSubstitutes(
    Set<String> absentTeachers,
    String targetDay,
  ) async =>
      _assignSubstitutesLocally(absentTeachers, targetDay);

  /// Clears substitutes for [targetDay] only (or all days if null).
  void clearSubstitutes({String? targetDay}) {
    for (final sec in config.sections) {
      final days = targetDay != null ? [targetDay] : config.days;
      for (final day in days) {
        for (final slot in timetable[sec]?[day] ?? []) {
          slot.teacher = slot.originalTeacher;
        }
      }
    }
  }

  // ── LOCAL GENERATION ───────────────────────────────────────────────────

  final _rand = Random();

  void _generateLocally() {
    timetable.clear();
    for (int si = 0; si < config.sections.length; si++) {
      final sec = config.sections[si];
      final teachers = config.teachersBySection[si];
      timetable[sec] = {};
      for (final day in config.days) {
        timetable[sec]![day] = _buildDay(teachers);
      }
    }
  }

  List<PeriodSlot> _buildDay(List<TeacherModel> teachers) {
    final slots        = <PeriodSlot>[];
    final teacherCount = <String, int>{};

    final daySubjects = <String>[];
    final pool = List<String>.from(config.subjects);
    while (daySubjects.length < config.periodsPerDay) {
      pool.shuffle(_rand);
      daySubjects.addAll(pool);
    }
    final shuffled = daySubjects.sublist(0, config.periodsPerDay);

    // No two consecutive same subjects
    for (int i = 1; i < shuffled.length; i++) {
      if (shuffled[i] == shuffled[i - 1]) {
        for (int j = i + 1; j < shuffled.length; j++) {
          if (shuffled[j] != shuffled[i - 1]) {
            final tmp = shuffled[i];
            shuffled[i] = shuffled[j];
            shuffled[j] = tmp;
            break;
          }
        }
      }
    }

    for (final subject in shuffled) {
      final eligible = teachers
          .where((t) =>
              t.subjects.contains(subject) &&
              (teacherCount[t.name] ?? 0) < 3)
          .toList();

      TeacherModel teacher;
      if (eligible.isNotEmpty) {
        teacher = eligible[_rand.nextInt(eligible.length)];
      } else {
        final fallback =
            teachers.where((t) => (teacherCount[t.name] ?? 0) < 4).toList();
        teacher = fallback.isNotEmpty
            ? fallback[_rand.nextInt(fallback.length)]
            : teachers[_rand.nextInt(teachers.length)];
      }

      teacherCount[teacher.name] = (teacherCount[teacher.name] ?? 0) + 1;
      slots.add(PeriodSlot(
        subject: subject,
        teacher: teacher.name,
        originalTeacher: teacher.name,
      ));
    }
    return slots;
  }

  void _assignSubstitutesLocally(
    Set<String> absentTeachers,
    String targetDay,
  ) {
    for (int si = 0; si < config.sections.length; si++) {
      final sec       = config.sections[si];
      final available = config.teachersBySection[si]
          .where((t) => !absentTeachers.contains(t.name))
          .toList();
      if (available.isEmpty) continue;

      // Only touch targetDay slots
      for (final slot in timetable[sec]?[targetDay] ?? []) {
        if (absentTeachers.contains(slot.originalTeacher)) {
          final subs =
              available.where((t) => t.subjects.contains(slot.subject)).toList();
          final sub = subs.isNotEmpty
              ? subs[_rand.nextInt(subs.length)]
              : available[_rand.nextInt(available.length)];
          slot.teacher = sub.name;
        }
        // Leave non-absent teachers untouched on this day
      }
    }
  }
}
