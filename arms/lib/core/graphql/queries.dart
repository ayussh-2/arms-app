/// All GraphQL query and mutation strings used by the app.
/// Centralised here so changes to the schema propagate from one file.
class GqlQueries {
  GqlQueries._();

  // ──────────── Lookups ────────────

  static const String getClasses = r'''
    query GetClasses {
      classes { id name display_order }
    }
  ''';

  static const String getSections = r'''
    query GetSections {
      sections { id name display_order }
    }
  ''';

  static const String getSchools = r'''
    query GetSchools {
      schools { id name display_order }
    }
  ''';

  // ──────────── Students ────────────

  static const String getStudents = r'''
    query GetStudents($classId: ID, $sectionId: ID) {
      students(classId: $classId, sectionId: $sectionId) {
        id name roll_no image_url
        class { id name }
        section { id name }
      }
    }
  ''';

  // ──────────── Attendance ────────────

  static const String getAttendance = r'''
    query GetAttendance($classId: ID!, $sectionId: ID!, $date: String!) {
      attendance(classId: $classId, sectionId: $sectionId, date: $date) {
        id
        student { id name roll_no image_url }
        morning_in_status morning_out_status
        evening_in_status evening_out_status
        attendance_date
      }
    }
  ''';

  static const String saveAttendance = r'''
    mutation SaveAttendance($input: [AttendanceInput!]!) {
      saveAttendance(input: $input)
    }
  ''';

  // ──────────── Leaves ────────────

  static const String getLeaves = r'''
    query GetLeaves($status: String) {
      leaves(status: $status) {
        id
        student { id name roll_no image_url }
        from_date to_date leave_type reason
        approved rejected_reason
        created_at
      }
    }
  ''';

  static const String applyLeave = r'''
    mutation ApplyLeave($input: LeaveInput!) {
      applyLeave(input: $input) {
        id from_date to_date leave_type reason approved
      }
    }
  ''';

  // ──────────── Exams ────────────

  static const String getExams = r'''
    query GetExams($seriesId: ID, $classId: ID, $sectionId: ID) {
      exams(seriesId: $seriesId, classId: $classId, sectionId: $sectionId) {
        id name exam_date total_marks mark_saved
        series { id name code }
        subjects { id subject { id name code } max_marks }
        for_school for_class for_section
      }
    }
  ''';

  static const String getExam = r'''
    query GetExam($id: ID!) {
      exam(id: $id) {
        id name exam_date total_marks mark_saved
        series { id name code }
        subjects { id subject { id name code } max_marks }
        for_school for_class for_section
      }
    }
  ''';

  static const String getMarks = r'''
    query GetMarks($examId: ID!) {
      marks(examId: $examId) {
        id marks_obtained is_absent mark_status
        student { id name roll_no image_url }
        subject { id name }
      }
    }
  ''';

  static const String saveMarks = r'''
    mutation SaveMarks($input: [MarkInput!]!) {
      saveMarks(input: $input)
    }
  ''';

  // ──────────── Admins (for login mock) ────────────

  static const String getAdmins = r'''
    query GetAdmins {
      admins { id name email admin_id role img_url }
    }
  ''';
}
