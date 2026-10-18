class ScorecardStudentMeta {
  final String id;
  final String name;
  final int? rollNo;
  final String? schoolId;
  final String? schoolName;
  final String? classId;
  final String? className;
  final String? sectionId;
  final String? sectionName;
  final String? imageUrl;
  final String? phone1;
  final String? phone2;
  final String? fatherName;
  final String? motherName;
  final String? organisationName;
  final String? organisationDisplayName;
  final String? organisationLogoUrl;

  const ScorecardStudentMeta({
    required this.id,
    required this.name,
    this.rollNo,
    this.schoolId,
    this.schoolName,
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.imageUrl,
    this.phone1,
    this.phone2,
    this.fatherName,
    this.motherName,
    this.organisationName,
    this.organisationDisplayName,
    this.organisationLogoUrl,
  });

  factory ScorecardStudentMeta.fromJson(Map<String, dynamic> json) {
    return ScorecardStudentMeta(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rollNo: (json['roll_no'] as num?)?.toInt(),
      schoolId: json['school_id']?.toString(),
      schoolName: json['school_name']?.toString(),
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString(),
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString(),
      imageUrl: json['image_url']?.toString(),
      phone1: json['phone1']?.toString(),
      phone2: json['phone2']?.toString(),
      fatherName: json['father_name']?.toString(),
      motherName: json['mother_name']?.toString(),
      organisationName: json['organisation_name']?.toString(),
      organisationDisplayName: json['organisation_display_name']?.toString(),
      organisationLogoUrl: json['organisation_logo_url']?.toString(),
    );
  }
}

class ScorecardHistoricalSession {
  final int year;
  final String label;
  final String fromDate;
  final String toDate;

  const ScorecardHistoricalSession({
    required this.year,
    required this.label,
    required this.fromDate,
    required this.toDate,
  });

  factory ScorecardHistoricalSession.fromJson(Map<String, dynamic> json) {
    return ScorecardHistoricalSession(
      year: (json['year'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      fromDate: json['fromDate']?.toString() ?? '',
      toDate: json['toDate']?.toString() ?? '',
    );
  }
}

class ScorecardSessionInfo {
  final int currentSessionYear;
  final int selectedSessionYear;
  final String label;
  final String fromDate;
  final String toDate;
  final List<int> availableSessionYears;
  final List<ScorecardHistoricalSession> historicalSessions;

  const ScorecardSessionInfo({
    required this.currentSessionYear,
    required this.selectedSessionYear,
    required this.label,
    required this.fromDate,
    required this.toDate,
    required this.availableSessionYears,
    required this.historicalSessions,
  });

  factory ScorecardSessionInfo.fromJson(Map<String, dynamic> json) {
    return ScorecardSessionInfo(
      currentSessionYear: (json['currentSessionYear'] as num?)?.toInt() ?? 0,
      selectedSessionYear: (json['selectedSessionYear'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      fromDate: json['fromDate']?.toString() ?? '',
      toDate: json['toDate']?.toString() ?? '',
      availableSessionYears: (json['availableSessionYears'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      historicalSessions: (json['historicalSessions'] as List<dynamic>?)
              ?.map((e) => ScorecardHistoricalSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScorecardOverview {
  final int totalExams;
  final double? overallPercentage;
  final double? overallRank;
  final int? totalParticipants;
  final double? bestPercentage;
  final double? averagePercentage;
  final double overallObtained;
  final double overallMaxMarks;

  const ScorecardOverview({
    required this.totalExams,
    this.overallPercentage,
    this.overallRank,
    this.totalParticipants,
    this.bestPercentage,
    this.averagePercentage,
    required this.overallObtained,
    required this.overallMaxMarks,
  });

  factory ScorecardOverview.fromJson(Map<String, dynamic> json) {
    return ScorecardOverview(
      totalExams: (json['totalExams'] as num?)?.toInt() ?? 0,
      overallPercentage: (json['overallPercentage'] as num?)?.toDouble(),
      overallRank: (json['overallRank'] as num?)?.toDouble(),
      totalParticipants: (json['totalParticipants'] as num?)?.toInt(),
      bestPercentage: (json['bestPercentage'] as num?)?.toDouble(),
      averagePercentage: (json['averagePercentage'] as num?)?.toDouble(),
      overallObtained: (json['overallObtained'] as num?)?.toDouble() ?? 0.0,
      overallMaxMarks: (json['overallMaxMarks'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ScorecardChartPoint {
  final String label;
  final double? studentValue;
  final double? bestValue;
  final double? averageValue;

  const ScorecardChartPoint({
    required this.label,
    this.studentValue,
    this.bestValue,
    this.averageValue,
  });

  factory ScorecardChartPoint.fromJson(Map<String, dynamic> json) {
    return ScorecardChartPoint(
      label: json['label']?.toString() ?? '',
      studentValue: (json['studentValue'] as num?)?.toDouble(),
      bestValue: (json['bestValue'] as num?)?.toDouble(),
      averageValue: (json['averageValue'] as num?)?.toDouble(),
    );
  }
}

class ScorecardChartData {
  final List<ScorecardChartPoint> percentage;
  final List<ScorecardChartPoint> marks;
  final List<ScorecardChartPoint> rank;

  const ScorecardChartData({
    required this.percentage,
    required this.marks,
    required this.rank,
  });

  factory ScorecardChartData.fromJson(Map<String, dynamic> json) {
    return ScorecardChartData(
      percentage: (json['percentage'] as List<dynamic>?)
              ?.map((e) => ScorecardChartPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      marks: (json['marks'] as List<dynamic>?)
              ?.map((e) => ScorecardChartPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rank: (json['rank'] as List<dynamic>?)
              ?.map((e) => ScorecardChartPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static const empty = ScorecardChartData(percentage: [], marks: [], rank: []);
}

class ScorecardSubjectCell {
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final double? obtained;
  final double maxMarks;
  final double? percentage;
  final int? rank;
  final int participants;
  final String? status;
  final double? bestMarks;
  final double? averageMarks;
  final double? bestPercentage;
  final double? averagePercentage;

  const ScorecardSubjectCell({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    this.obtained,
    required this.maxMarks,
    this.percentage,
    this.rank,
    required this.participants,
    this.status,
    this.bestMarks,
    this.averageMarks,
    this.bestPercentage,
    this.averagePercentage,
  });

  factory ScorecardSubjectCell.fromJson(Map<String, dynamic> json) {
    return ScorecardSubjectCell(
      subjectId: json['subjectId']?.toString() ?? '',
      subjectName: json['subjectName']?.toString() ?? '',
      subjectCode: json['subjectCode']?.toString(),
      obtained: (json['obtained'] as num?)?.toDouble(),
      maxMarks: (json['maxMarks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble(),
      rank: (json['rank'] as num?)?.toInt(),
      participants: (json['participants'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString(),
      bestMarks: (json['bestMarks'] as num?)?.toDouble(),
      averageMarks: (json['averageMarks'] as num?)?.toDouble(),
      bestPercentage: (json['bestPercentage'] as num?)?.toDouble(),
      averagePercentage: (json['averagePercentage'] as num?)?.toDouble(),
    );
  }
}

class ScorecardExamRow {
  final String examId;
  final String examName;
  final String? seriesId;
  final String? seriesName;
  final String? examDate;
  final double? totalMarks;
  final double obtained;
  final double maxMarks;
  final double? percentage;
  final int? rank;
  final int participants;
  final double? bestPercentage;
  final double? averagePercentage;
  final double? bestMarks;
  final double? averageMarks;
  final List<ScorecardSubjectCell> subjects;

  const ScorecardExamRow({
    required this.examId,
    required this.examName,
    this.seriesId,
    this.seriesName,
    this.examDate,
    this.totalMarks,
    required this.obtained,
    required this.maxMarks,
    this.percentage,
    this.rank,
    required this.participants,
    this.bestPercentage,
    this.averagePercentage,
    this.bestMarks,
    this.averageMarks,
    required this.subjects,
  });

  factory ScorecardExamRow.fromJson(Map<String, dynamic> json) {
    return ScorecardExamRow(
      examId: json['examId']?.toString() ?? '',
      examName: json['examName']?.toString() ?? '',
      seriesId: json['seriesId']?.toString(),
      seriesName: json['seriesName']?.toString(),
      examDate: json['examDate']?.toString(),
      totalMarks: (json['totalMarks'] as num?)?.toDouble(),
      obtained: (json['obtained'] as num?)?.toDouble() ?? 0.0,
      maxMarks: (json['maxMarks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble(),
      rank: (json['rank'] as num?)?.toInt(),
      participants: (json['participants'] as num?)?.toInt() ?? 0,
      bestPercentage: (json['bestPercentage'] as num?)?.toDouble(),
      averagePercentage: (json['averagePercentage'] as num?)?.toDouble(),
      bestMarks: (json['bestMarks'] as num?)?.toDouble(),
      averageMarks: (json['averageMarks'] as num?)?.toDouble(),
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((e) => ScorecardSubjectCell.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScorecardGroup {
  final String key;
  final String label;
  final String mode;
  final double? averagePercentage;
  final double? bestPercentage;
  final double? averageMarks;
  final double? bestMarks;
  final ScorecardChartData charts;
  final List<ScorecardExamRow> exams;

  const ScorecardGroup({
    required this.key,
    required this.label,
    required this.mode,
    this.averagePercentage,
    this.bestPercentage,
    this.averageMarks,
    this.bestMarks,
    required this.charts,
    required this.exams,
  });

  factory ScorecardGroup.fromJson(Map<String, dynamic> json) {
    return ScorecardGroup(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'series',
      averagePercentage: (json['averagePercentage'] as num?)?.toDouble(),
      bestPercentage: (json['bestPercentage'] as num?)?.toDouble(),
      averageMarks: (json['averageMarks'] as num?)?.toDouble(),
      bestMarks: (json['bestMarks'] as num?)?.toDouble(),
      charts: json['charts'] != null
          ? ScorecardChartData.fromJson(json['charts'] as Map<String, dynamic>)
          : ScorecardChartData.empty,
      exams: (json['exams'] as List<dynamic>?)
              ?.map((e) => ScorecardExamRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScorecardDayStatus {
  final String date;
  final int day;
  final String status; // 'present', 'absent', 'leave', 'holiday', 'unmarked'

  const ScorecardDayStatus({
    required this.date,
    required this.day,
    required this.status,
  });

  factory ScorecardDayStatus.fromJson(Map<String, dynamic> json) {
    return ScorecardDayStatus(
      date: json['date']?.toString() ?? '',
      day: (json['day'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'unmarked',
    );
  }
}

class ScorecardMonthCalendar {
  final String month;
  final String monthName;
  final int presentDays;
  final int workingDays;
  final List<ScorecardDayStatus> days;

  const ScorecardMonthCalendar({
    required this.month,
    required this.monthName,
    required this.presentDays,
    required this.workingDays,
    required this.days,
  });

  factory ScorecardMonthCalendar.fromJson(Map<String, dynamic> json) {
    return ScorecardMonthCalendar(
      month: json['month']?.toString() ?? '',
      monthName: json['monthName']?.toString() ?? '',
      presentDays: (json['presentDays'] as num?)?.toInt() ?? 0,
      workingDays: (json['workingDays'] as num?)?.toInt() ?? 0,
      days: (json['days'] as List<dynamic>?)
              ?.map((e) => ScorecardDayStatus.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScorecardAttendanceSummary {
  final int presentDays;
  final int workingDays;
  final int absentDays;
  final int leaveDays;
  final int holidayDays;
  final double percentage;
  final List<ScorecardMonthCalendar> calendar;

  const ScorecardAttendanceSummary({
    required this.presentDays,
    required this.workingDays,
    required this.absentDays,
    required this.leaveDays,
    required this.holidayDays,
    required this.percentage,
    required this.calendar,
  });

  factory ScorecardAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return ScorecardAttendanceSummary(
      presentDays: (json['presentDays'] as num?)?.toInt() ?? 0,
      workingDays: (json['workingDays'] as num?)?.toInt() ?? 0,
      absentDays: (json['absentDays'] as num?)?.toInt() ?? 0,
      leaveDays: (json['leaveDays'] as num?)?.toInt() ?? 0,
      holidayDays: (json['holidayDays'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      calendar: (json['calendar'] as List<dynamic>?)
              ?.map((e) => ScorecardMonthCalendar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static const empty = ScorecardAttendanceSummary(
    presentDays: 0,
    workingDays: 0,
    absentDays: 0,
    leaveDays: 0,
    holidayDays: 0,
    percentage: 0.0,
    calendar: [],
  );
}

class ScorecardComment {
  final String id;
  final String commentText;
  final String authorId;
  final String authorType;
  final String authorName;
  final String? createdAt;

  const ScorecardComment({
    required this.id,
    required this.commentText,
    required this.authorId,
    required this.authorType,
    required this.authorName,
    this.createdAt,
  });

  factory ScorecardComment.fromJson(Map<String, dynamic> json) {
    return ScorecardComment(
      id: json['id']?.toString() ?? '',
      commentText: json['commentText']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorType: json['authorType']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Admin',
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class StudentAcademicScorecard {
  final ScorecardStudentMeta student;
  final ScorecardSessionInfo session;
  final ScorecardOverview overview;
  final List<ScorecardGroup> groups;
  final ScorecardChartData overallCharts;
  final ScorecardAttendanceSummary attendance;
  final List<String> tags;
  final List<ScorecardComment> comments;

  const StudentAcademicScorecard({
    required this.student,
    required this.session,
    required this.overview,
    required this.groups,
    required this.overallCharts,
    required this.attendance,
    required this.tags,
    required this.comments,
  });

  factory StudentAcademicScorecard.fromJson(Map<String, dynamic> json) {
    return StudentAcademicScorecard(
      student: ScorecardStudentMeta.fromJson(json['student'] as Map<String, dynamic>? ?? {}),
      session: ScorecardSessionInfo.fromJson(json['session'] as Map<String, dynamic>? ?? {}),
      overview: ScorecardOverview.fromJson(json['overview'] as Map<String, dynamic>? ?? {}),
      groups: (json['groups'] as List<dynamic>?)
              ?.map((e) => ScorecardGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      overallCharts: json['overallCharts'] != null
          ? ScorecardChartData.fromJson(json['overallCharts'] as Map<String, dynamic>)
          : ScorecardChartData.empty,
      attendance: json['attendance'] != null
          ? ScorecardAttendanceSummary.fromJson(json['attendance'] as Map<String, dynamic>)
          : ScorecardAttendanceSummary.empty,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => ScorecardComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
