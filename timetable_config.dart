// lib/models/teacher_model.dart

class TeacherModel {
  String name;
  List<String> subjects;

  TeacherModel({required this.name, required this.subjects});

  TeacherModel copyWith({String? name, List<String>? subjects}) =>
      TeacherModel(
        name: name ?? this.name,
        subjects: subjects ?? List.from(this.subjects),
      );

  @override
  String toString() => name;
}
