// lib/models/period_slot.dart

class PeriodSlot {
  String subject;
  String teacher;
  String originalTeacher;

  PeriodSlot({
    required this.subject,
    required this.teacher,
    required this.originalTeacher,
  });

  bool isAbsent(Set<String> absentTeachers) =>
      absentTeachers.contains(originalTeacher);

  bool get hasSubstitute => teacher != originalTeacher;
}
