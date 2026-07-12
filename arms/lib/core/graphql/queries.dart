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
      $schoolId: ID
      $sectionId: ID
      $havingPhoto: Boolean
    ) {
      getPaginatedStudents(
        organisationId: $organisationId
        page: $page
        limit: $limit
        searchQuery: $searchQuery
        classId: $classId
        schoolId: $schoolId
        sectionId: $sectionId
        havingPhoto: $havingPhoto
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
      $schoolId: ID!
      $sectionId: ID!
    ) {
      getStudentsForAttendance(
        organisationId: $organisationId
        attendanceDate: $attendanceDate
        attendanceSession: $attendanceSession
        classId: $classId
        schoolId: $schoolId
        sectionId: $sectionId
      ) {
        student {
          id
          name
          roll_no
          image_url
          school_id
          section_id
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

  static const String getAttendanceReportData = r'''
    query GetAttendanceReportData(
      $organisationId: ID!
      $fromDate: String!
      $toDate: String!
      $schoolId: ID
      $classId: ID
      $sectionId: ID
    ) {
      getAttendanceReportData(
        organisationId: $organisationId
        fromDate: $fromDate
        toDate: $toDate
        schoolId: $schoolId
        classId: $classId
        sectionId: $sectionId
      ) {
        students {
          id
          name
          roll_no
          school_id
          class_id
          section_id
          image_url
          image_version
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
        attendance {
          id
          student_id
          attendance_date
          morning_in_status
          morning_out_status
          evening_in_status
          evening_out_status
          remarks
        }
        holidays {
          id
          holiday_name
          from_date
          to_date
          applies_to_school_ids
          applies_to_class_ids
        }
        leaves {
          id
          student_id
          from_date
          to_date
          leave_type
          reason
          approved
          leave_application_image_url
        }
      }
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

  static const String getExamLookups = r'''
    query GetExamLookups($organisationId: ID!) {
      getExamLookups(organisationId: $organisationId) {
        schools { id name display_order }
        classes { id name display_order }
        sections { id name display_order }
        series { id name code display_order subject_ids }
        subjects { id name code display_order }
      }
    }
  ''';

  static const String getExams = r'''
    query GetExams($organisationId: ID!, $isDeleted: Boolean) {
      getExams(organisationId: $organisationId, isDeleted: $isDeleted) {
        id
        name
        exam_date
        total_marks
        mark_saved
        series { id name code }
        subjects { id name code }
      }
    }
  ''';

  static const String getExamsPaginated = r'''
    query GetExamsPaginated(
      $organisationId: ID!
      $isDeleted: Boolean
      $pagination: PaginationInput!
    ) {
      getExamsPaginated(
        organisationId: $organisationId
        isDeleted: $isDeleted
        pagination: $pagination
      ) {
        items {
          id
          name
          exam_date
          total_marks
          mark_saved
          for_school
          for_class
          for_section
          series { id name code }
          subjects { id name code }
        }
        pagination {
          total
          limit
          offset
          hasMore
        }
      }
    }
  ''';

  static const String searchExams = r'''
    query SearchExams(
      $organisationId: ID!
      $query: String
      $filters: ExamFiltersInput
      $isDeleted: Boolean
      $pagination: PaginationInput!
    ) {
      searchExams(
        organisationId: $organisationId
        query: $query
        filters: $filters
        isDeleted: $isDeleted
        pagination: $pagination
      ) {
        items {
          id
          name
          exam_date
          total_marks
          mark_saved
          for_school
          for_class
          for_section
          series { id name code }
          subjects { id name code }
        }
        pagination {
          total
          limit
          offset
          hasMore
        }
      }
    }
  ''';

  static const String getExamDetails = r'''
    query GetExamDetails($examId: ID!, $organisationId: ID!) {
      getExamDetails(examId: $examId, organisationId: $organisationId) {
        exam {
          id
          name
          exam_date
          total_marks
          mark_saved
          attendance_pdf_url
          question_pdf_url
          for_school
          for_class
          for_section
          chapter
          topic
        }
        subjects {
          id
          name
          code
          max_marks
        }
        students {
          id
          name
          roll_no
          image_url
        }
        marks {
          id
          student_id
          subject_id
          marks_obtained
          mark_status
          is_absent
        }
      }
    }
  ''';

  static const String createExam = r'''
    mutation CreateExam($input: CreateExamInput!) {
      createExam(input: $input)
    }
  ''';

  static const String saveMarks = r'''
    mutation SaveMarks($examId: ID!, $marks: [MarkInput!]!) {
      saveMarks(examId: $examId, marks: $marks)
    }
  ''';

  static const String updateExamSetup = r'''
    mutation UpdateExamSetup($examId: ID!, $input: UpdateExamSetupInput!) {
      updateExamSetup(examId: $examId, input: $input)
    }
  ''';

  static const String updateExamPdfs = r'''
    mutation UpdateExamPdfs($examId: ID!, $attendancePdf: String, $questionPdf: String) {
      updateExamPdfs(examId: $examId, attendancePdf: $attendancePdf, questionPdf: $questionPdf)
    }
  ''';

  static const String toggleExamDelete = r'''
    mutation ToggleExamDelete($examId: ID!, $isDeleted: Boolean!) {
      toggleExamDelete(examId: $examId, isDeleted: $isDeleted)
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

  static const String getStudentDetails = r'''
    query GetStudentDetails($id: ID!, $organisationId: ID!) {
      getStudentDetails(id: $id, organisationId: $organisationId) {
        id
        name
        father_name
        mother_name
        dob
        email
        password
        phone1
        phone2
        category
        address
        gender
        age
        fl_batch_id
        organisation_id
        school_id
        class_id
        section_id
        roll_no
        image_url
        image_version
        tags {
          id
          name
          type
          assignedById
          assignedByType
          assignedByLabel
        }
      }
    }
  ''';

  static const String getAlumni = r'''
    query GetAlumni {
      getAlumni {
        id
        name
        code
      }
    }
  ''';

  static const String updateStudentDetails = r'''
    mutation UpdateStudentDetails($id: ID!, $organisationId: ID!, $input: UpdateStudentInput!) {
      updateStudentDetails(id: $id, organisationId: $organisationId, input: $input) {
        id
        name
      }
    }
  ''';

  static const String getAvailableTags = r'''
    query GetAvailableTags($organisationId: ID!) {
      getAvailableTags(organisationId: $organisationId) {
        id
        name
        type
      }
    }
  ''';

  static const String assignStudentTag = r'''
    mutation AssignStudentTag($studentId: ID!, $tagId: ID!, $assignedBy: ID!, $assignedByType: String!) {
      assignStudentTag(studentId: $studentId, tagId: $tagId, assignedBy: $assignedBy, assignedByType: $assignedByType)
    }
  ''';

  static const String removeStudentTag = r'''
    mutation RemoveStudentTag($studentId: ID!, $tagId: ID!) {
      removeStudentTag(studentId: $studentId, tagId: $tagId)
    }
  ''';
}

