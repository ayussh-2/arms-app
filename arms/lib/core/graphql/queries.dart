class GqlQueries {
  GqlQueries._();

  // ──────────── Lookups ────────────

  static const String getLookups = r'''
    query GetLookups($organisationId: ID!) {
      getLookups(organisationId: $organisationId) {
        schools { id name display_order }
        classes { id name display_order }
        sections { id name display_order }
      }
    }
  ''';

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

  static const String getPaginatedStudents = r'''
    query GetPaginatedStudents(
      $organisationId: ID!
      $page: Int
      $limit: Int
      $searchQuery: String
      $classId: ID
    ) {
      getPaginatedStudents(
        organisationId: $organisationId
        page: $page
        limit: $limit
        searchQuery: $searchQuery
        classId: $classId
      ) {
        students {
          id
          name
          roll_no
          image_url
          class { id name }
          section { id name }
        }
        pagination {
          totalCount
          totalPages
          currentPage
          limit
        }
      }
    }
  ''';

  // ──────────── Attendance ────────────

  static const String getStudentsForAttendance = r'''
    query GetStudentsForAttendance(
      $organisationId: ID!
      $attendanceDate: String!
      $attendanceSession: String!
      $classId: ID!
    ) {
      getStudentsForAttendance(
        organisationId: $organisationId
        attendanceDate: $attendanceDate
        attendanceSession: $attendanceSession
        classId: $classId
      ) {
        student {
          id
          name
          roll_no
          image_url
        }
        status
        attendance {
          id
          morning_in_status
          morning_out_status
          remarks
        }
      }
    }
  ''';

  static const String saveAttendance = r'''
    mutation SaveAttendance(
      $organisationId: ID!
      $adminId: ID!
      $attendanceDate: String!
      $attendanceSession: String!
      $updates: [AttendanceUpdateInput!]!
    ) {
      saveAttendance(
        organisationId: $organisationId
        adminId: $adminId
        attendanceDate: $attendanceDate
        attendanceSession: $attendanceSession
        updates: $updates
      )
    }
  ''';

  // ──────────── Leaves ────────────

  static const String getLeaves = r'''
    query GetLeaves($organisationId: ID!) {
      getLeaves(organisationId: $organisationId) {
        id
        student {
          id
          name
          roll_no
          image_url
          school {
            id
            name
          }
          class {
            id
            name
          }
          section {
            id
            name
          }
        }
        from_date
        to_date
        leave_type
        reason
        approved
        approved_by
        leave_application_image_url
        rejected_reason
        created_at
      }
    }
  ''';

  static const String getStudentLeaveHistory = r'''
    query GetStudentLeaveHistory($studentId: ID!, $organisationId: ID!) {
      getStudentLeaveHistory(studentId: $studentId, organisationId: $organisationId) {
        id
        from_date
        to_date
        leave_type
        reason
        approved
        rejected_reason
      }
    }
  ''';

  static const String createLeave = r'''
    mutation CreateLeave($input: SaveLeaveInput!) {
      saveLeave(input: $input)
    }
  ''';

  static const String updateLeave = r'''
    mutation UpdateLeave($input: SaveLeaveInput!) {
      saveLeave(input: $input)
    }
  ''';

  static const String deleteLeave = r'''
    mutation DeleteLeave($id: ID!, $organisationId: ID!) {
      deleteLeave(id: $id, organisationId: $organisationId)
    }
  ''';

  // ──────────── Exams ────────────

  static const String getExams = r'''
    query GetExams($seriesId: ID, $classId: ID, $sectionId: ID) {
      exams(seriesId: $seriesId, classId: $classId, sectionId: $sectionId) {
        id name exam_date total_marks mark_saved topic
        series { id name code }
        subjects { id subject { id name code } max_marks }
        for_school for_class for_section
      }
    }
  ''';

  static const String getExam = r'''
    query GetExam($id: ID!) {
      exam(id: $id) {
        id name exam_date total_marks mark_saved topic
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

  static const String login = r'''
    query Login($adminId: String!, $password: String!) {
      login(adminId: $adminId, password: $password) {
        data {
          id
          adminID
          name
          email
          phone1
          phone2
          gender
          age
          imageURL
          role
          address
          signURL
          signURLVersion
          organization {
            id
            name
            displayName
            headerURL
            logoURL
            helpLineNumber
            createdAt
          }
        }
        error
      }
    }
  ''';
}
