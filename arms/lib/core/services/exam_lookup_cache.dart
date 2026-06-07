class ExamLookupCache {
  static final Map<String, String> schools = {};
  static final Map<String, String> classes = {};
  static final Map<String, String> sections = {};
  static final Map<String, String> subjects = {};

  static void updateLookups({
    required List<dynamic> schoolsList,
    required List<dynamic> classesList,
    required List<dynamic> sectionsList,
    required List<dynamic> subjectsList,
  }) {
    schools.clear();
    for (var item in schoolsList) {
      if (item is Map && item['id'] != null) {
        schools[item['id'].toString()] = item['name']?.toString() ?? '';
      }
    }

    classes.clear();
    for (var item in classesList) {
      if (item is Map && item['id'] != null) {
        classes[item['id'].toString()] = item['name']?.toString() ?? '';
      }
    }

    sections.clear();
    for (var item in sectionsList) {
      if (item is Map && item['id'] != null) {
        sections[item['id'].toString()] = item['name']?.toString() ?? '';
      }
    }

    subjects.clear();
    for (var item in subjectsList) {
      if (item is Map && item['id'] != null) {
        subjects[item['id'].toString()] = item['name']?.toString() ?? '';
      }
    }
  }

  static String resolve(String uuid, String type) {
    if (type == 'school') return schools[uuid] ?? uuid;
    if (type == 'class') return classes[uuid] ?? uuid;
    if (type == 'section') return sections[uuid] ?? uuid;
    if (type == 'subject') return subjects[uuid] ?? uuid;
    return uuid;
  }
}
