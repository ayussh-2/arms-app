const sqlite3 = require("sqlite3").verbose();
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");

const DB_PATH = path.join(__dirname, "arms.db");

// Helper to generate UUIDs
function generateUUID() {
    return crypto.randomUUID();
}

// Promisified database run/all helpers
class Database {
    constructor(dbPath) {
        this.db = new sqlite3.Database(dbPath);
    }

    run(sql, params = []) {
        return new Promise((resolve, reject) => {
            this.db.run(sql, params, function (err) {
                if (err) reject(err);
                else resolve({ id: this.lastID, changes: this.changes });
            });
        });
    }

    all(sql, params = []) {
        return new Promise((resolve, reject) => {
            this.db.all(sql, params, (err, rows) => {
                if (err) reject(err);
                else resolve(rows);
            });
        });
    }

    get(sql, params = []) {
        return new Promise((resolve, reject) => {
            this.db.get(sql, params, (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });
    }

    close() {
        return new Promise((resolve, reject) => {
            this.db.close((err) => {
                if (err) reject(err);
                else resolve();
            });
        });
    }
}

const db = new Database(DB_PATH);

async function initializeDatabase() {
    console.log("Initializing SQLite Database...");

    // Create tables translated from PostgreSQL to SQLite
    await db.run(`
    CREATE TABLE IF NOT EXISTS organisations (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      display_name TEXT,
      logo_url TEXT,
      header_url TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      helpline_no TEXT DEFAULT '8599800108',
      attendance_devices TEXT DEFAULT '[]'
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS academicyear (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      start_date TEXT,
      end_date TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      organisation_id TEXT,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS schools (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      display_order INTEGER,
      organisation_id TEXT,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS classes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      display_order INTEGER,
      organisation_id TEXT,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS sections (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      display_order INTEGER,
      organisation_id TEXT,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS subjects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      display_order INTEGER,
      organisation_id TEXT,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS series (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT NOT NULL,
      description TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      display_order INTEGER,
      organisation_id TEXT,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS alumni (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      code INTEGER NOT NULL UNIQUE,
      batch TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS admins (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      phone1 TEXT NOT NULL,
      phone2 TEXT,
      gender TEXT,
      age INTEGER,
      img_url TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      password TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'admin',
      image_version INTEGER NOT NULL DEFAULT 1,
      is_deleted INTEGER DEFAULT 0,
      admin_id TEXT NOT NULL UNIQUE,
      organisation_id TEXT,
      sign_url TEXT,
      sign_url_version INTEGER DEFAULT 1,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS rights (
      id TEXT PRIMARY KEY,
      right_name TEXT NOT NULL UNIQUE,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS admin_rights (
      id TEXT PRIMARY KEY,
      admin_id TEXT NOT NULL,
      rights_id TEXT NOT NULL,
      valid_from TEXT,
      valid_to TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (admin_id) REFERENCES admins(id),
      FOREIGN KEY (rights_id) REFERENCES rights(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS students (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      roll_no INTEGER NOT NULL,
      image_url TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      phone1 TEXT,
      phone2 TEXT,
      address TEXT,
      gender TEXT,
      age INTEGER,
      is_deleted INTEGER DEFAULT 0,
      image_version INTEGER NOT NULL DEFAULT 0,
      email TEXT,
      password TEXT,
      school_id TEXT,
      class_id TEXT,
      section_id TEXT,
      fl_batch_id TEXT,
      organisation_id TEXT NOT NULL,
      father_name TEXT,
      mother_name TEXT,
      dob TEXT,
      category TEXT,
      FOREIGN KEY (school_id) REFERENCES schools(id),
      FOREIGN KEY (class_id) REFERENCES classes(id),
      FOREIGN KEY (section_id) REFERENCES sections(id),
      FOREIGN KEY (fl_batch_id) REFERENCES alumni(id),
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS attendance (
      id TEXT PRIMARY KEY,
      organisation_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      attendance_date TEXT NOT NULL,
      morning_in TEXT,
      morning_out TEXT,
      evening_in TEXT,
      evening_out TEXT,
      morning_in_status TEXT,
      morning_out_status TEXT,
      evening_in_status TEXT,
      evening_out_status TEXT,
      attendance_source TEXT NOT NULL CHECK (attendance_source IN ('biometric', 'admin')),
      done_by_admin_id TEXT,
      is_manual_override INTEGER NOT NULL DEFAULT 0,
      remarks TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id),
      FOREIGN KEY (student_id) REFERENCES students(id),
      FOREIGN KEY (done_by_admin_id) REFERENCES admins(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS attendance_holidays (
      id TEXT PRIMARY KEY,
      organisation_id TEXT NOT NULL,
      holiday_name TEXT NOT NULL,
      holiday_type TEXT,
      from_date TEXT NOT NULL,
      to_date TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      applies_to_school_ids TEXT, -- JSON Array String
      applies_to_class_ids TEXT,  -- JSON Array String
      FOREIGN KEY (organisation_id) REFERENCES organisations(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS attendance_leaves (
      id TEXT PRIMARY KEY,
      organisation_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      from_date TEXT NOT NULL,
      to_date TEXT,
      leave_type TEXT NOT NULL CHECK (leave_type IN ('fever', 'medical_self', 'medical_relative', 'marriage', 'casual', 'stomach_pain', 'body_pain_headache')),
      reason TEXT,
      approved INTEGER NOT NULL DEFAULT 0,
      approved_by TEXT,
      leave_application_image_url TEXT,
      rejected_reason TEXT,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (organisation_id) REFERENCES organisations(id),
      FOREIGN KEY (student_id) REFERENCES students(id),
      FOREIGN KEY (approved_by) REFERENCES admins(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS exams (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      series_id TEXT NOT NULL,
      academic_year_id TEXT,
      chapter TEXT,
      topic TEXT,
      exam_date TEXT,
      total_marks INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      for_school TEXT,   -- JSON Array
      for_class TEXT,    -- JSON Array
      for_section TEXT,  -- JSON Array
      mark_saved INTEGER DEFAULT 0,
      organisation_id TEXT NOT NULL,
      attendance_pdf_url TEXT,
      question_pdf_url TEXT,
      is_deleted INTEGER DEFAULT 0,
      created_by TEXT,
      FOREIGN KEY (series_id) REFERENCES series(id),
      FOREIGN KEY (academic_year_id) REFERENCES academicyear(id),
      FOREIGN KEY (organisation_id) REFERENCES organisations(id),
      FOREIGN KEY (created_by) REFERENCES admins(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS exam_subjects (
      id TEXT PRIMARY KEY,
      exam_id TEXT NOT NULL,
      subject_id TEXT NOT NULL,
      max_marks INTEGER DEFAULT 100,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (exam_id) REFERENCES exams(id),
      FOREIGN KEY (subject_id) REFERENCES subjects(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS marks (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      exam_id TEXT NOT NULL,
      subject_id TEXT NOT NULL,
      marks_obtained REAL,
      is_absent INTEGER DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      mark_status TEXT,
      FOREIGN KEY (student_id) REFERENCES students(id),
      FOREIGN KEY (exam_id) REFERENCES exams(id),
      FOREIGN KEY (subject_id) REFERENCES subjects(id)
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS tags (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

    await db.run(`
    CREATE TABLE IF NOT EXISTS student_tags (
      id TEXT PRIMARY KEY,
      tag_id TEXT UNIQUE,
      assigned_by TEXT,
      assigned_by_type TEXT CHECK (assigned_by_type IN ('admin', 'teacher')),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      student_id TEXT,
      FOREIGN KEY (tag_id) REFERENCES tags(id),
      FOREIGN KEY (student_id) REFERENCES students(id)
    )
  `);

    console.log("Tables created successfully.");
    await seedMockData();
}

async function seedMockData() {
    const orgCheck = await db.get(
        "SELECT COUNT(*) as count FROM organisations",
    );
    if (orgCheck.count > 0) {
        console.log("Database already seeded. Skipping seed phase.");
        return;
    }

    console.log("Seeding Mock Data...");

    // 1. Organisation
    const orgId = generateUUID();
    await db.run(
        `
    INSERT INTO organisations (id, name, display_name, helpline_no, created_at)
    VALUES (?, ?, ?, ?, ?)
  `,
        [
            orgId,
            "Pariksit School Group",
            "Pariksit Academies & Schools",
            "+91 8599800108",
            "2026-01-01T00:00:00Z",
        ],
    );

    // 2. Academic Year
    const ayId = generateUUID();
    await db.run(
        `
    INSERT INTO academicyear (id, name, start_date, end_date, is_active, organisation_id)
    VALUES (?, ?, ?, ?, 1, ?)
  `,
        [ayId, "Academic Year 2026", "2026-04-01", "2027-03-31", orgId],
    );

    // 3. Schools
    const schoolId = generateUUID();
    await db.run(
        `
    INSERT INTO schools (id, name, display_order, organisation_id)
    VALUES (?, ?, ?, ?)
  `,
        [schoolId, "Main Campus Academy", 1, orgId],
    );

    // 4. Classes & Sections
    const classId = generateUUID();
    await db.run(
        `
    INSERT INTO classes (id, name, display_order, organisation_id)
    VALUES (?, ?, ?, ?)
  `,
        [classId, "Grade 10", 10, orgId],
    );

    const secId = generateUUID();
    await db.run(
        `
    INSERT INTO sections (id, name, display_order, organisation_id)
    VALUES (?, ?, ?, ?)
  `,
        [secId, "Science A", 1, orgId],
    );

    // 5. Subjects
    const subjMathId = generateUUID();
    const subjPhysId = generateUUID();
    const subjChemId = generateUUID();
    const subjBiolId = generateUUID();
    await db.run(
        `INSERT INTO subjects (id, name, code, display_order, organisation_id) VALUES (?, 'Mathematics', 'MATH', 1, ?)`,
        [subjMathId, orgId],
    );
    await db.run(
        `INSERT INTO subjects (id, name, code, display_order, organisation_id) VALUES (?, 'Physics', 'PHYS', 2, ?)`,
        [subjPhysId, orgId],
    );
    await db.run(
        `INSERT INTO subjects (id, name, code, display_order, organisation_id) VALUES (?, 'Chemistry', 'CHEM', 3, ?)`,
        [subjChemId, orgId],
    );
    await db.run(
        `INSERT INTO subjects (id, name, code, display_order, organisation_id) VALUES (?, 'Biology', 'BIOL', 4, ?)`,
        [subjBiolId, orgId],
    );

    // 6. Series
    const seriesId = generateUUID();
    await db.run(
        `
    INSERT INTO series (id, name, code, description, display_order, organisation_id)
    VALUES (?, ?, ?, ?, ?, ?)
  `,
        [
            seriesId,
            "NEET Prep Series",
            "RE-NEET",
            "Mock testing for competitive medical entrance",
            1,
            orgId,
        ],
    );

    // 7. Admins (Teacher)
    const adminId = generateUUID();
    await db.run(
        `
    INSERT INTO admins (id, name, email, phone1, password, role, admin_id, organisation_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `,
        [
            adminId,
            "Professor Pariksit",
            "admin@pariksit.edu",
            "9988776655",
            "1234",
            "admin",
            "admin",
            orgId,
        ],
    );

    // 8. Students
    const studentsData = [
        { name: "Alice Chen", roll: 1, email: "alice@pariksit.edu" },
        { name: "Bob Smith", roll: 2, email: "bob@pariksit.edu" },
        { name: "Charlie Davis", roll: 3, email: "charlie@pariksit.edu" },
        { name: "Diana Evans", roll: 4, email: "diana@pariksit.edu" },
        { name: "Evan Foster", roll: 5, email: "evan@pariksit.edu" },
    ];

    const studentUUIDs = [];
    for (const s of studentsData) {
        const sId = generateUUID();
        studentUUIDs.push(sId);
        await db.run(
            `
      INSERT INTO students (id, name, roll_no, email, phone1, school_id, class_id, section_id, organisation_id, dob, category)
      VALUES (?, ?, ?, ?, '9876543210', ?, ?, ?, ?, '2010-05-15', 'General')
    `,
            [sId, s.name, s.roll, s.email, schoolId, classId, secId, orgId],
        );
    }

    // 9. Attendance Logs (Historical)
    const dates = ["2026-05-24", "2026-05-25", "2026-05-26"];
    for (const date of dates) {
        for (let i = 0; i < studentUUIDs.length; i++) {
            const sId = studentUUIDs[i];
            // Diana is absent on the last day, Bob on the second, others present
            let morningStatus = "present";
            if (date === "2026-05-26" && i === 3) morningStatus = "absent"; // Diana absent
            if (date === "2026-05-25" && i === 1) morningStatus = "absent"; // Bob absent

            await db.run(
                `
        INSERT INTO attendance (
          id, organisation_id, student_id, attendance_date,
          morning_in_status, morning_out_status, evening_in_status, evening_out_status,
          attendance_source, done_by_admin_id, is_manual_override
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'admin', ?, 1)
      `,
                [
                    generateUUID(),
                    orgId,
                    sId,
                    date,
                    morningStatus,
                    morningStatus,
                    morningStatus,
                    morningStatus,
                    adminId,
                ],
            );
        }
    }

    // 10. Leaves Applications
    await db.run(
        `
    INSERT INTO attendance_leaves (id, organisation_id, student_id, from_date, to_date, leave_type, reason, approved, approved_by)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `,
        [
            generateUUID(),
            orgId,
            studentUUIDs[0],
            "2026-05-08",
            "2026-05-09",
            "fever",
            "Fever and cold. Doctor advised rest.",
            1,
            adminId,
        ],
    );

    await db.run(
        `
    INSERT INTO attendance_leaves (id, organisation_id, student_id, from_date, to_date, leave_type, reason, approved)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `,
        [
            generateUUID(),
            orgId,
            studentUUIDs[1],
            "2026-05-12",
            "2026-05-14",
            "casual",
            "Family emergency, traveling out of state.",
            0,
        ],
    );

    // 11. Exams
    const examId = generateUUID();
    await db.run(
        `
    INSERT INTO exams (id, name, series_id, academic_year_id, topic, exam_date, total_marks, organisation_id, created_by, for_school, for_class, for_section, mark_saved)
    VALUES (?, ?, ?, ?, ?, ?, 100, ?, ?, ?, ?, ?, 1)
  `,
        [
            examId,
            "DTS - 07 - RE - NEET - CHEMISTRY",
            seriesId,
            ayId,
            "Calculus & Mechanics",
            "2026-05-23",
            orgId,
            adminId,
            JSON.stringify([schoolId]),
            JSON.stringify([classId]),
            JSON.stringify([secId]),
        ],
    );

    // Exam Subjects
    await db.run(
        `INSERT INTO exam_subjects (id, exam_id, subject_id, max_marks) VALUES (?, ?, ?, 50)`,
        [generateUUID(), examId, subjChemId],
    );
    await db.run(
        `INSERT INTO exam_subjects (id, exam_id, subject_id, max_marks) VALUES (?, ?, ?, 50)`,
        [generateUUID(), examId, subjPhysId],
    );

    // Seed marks for this exam
    const chemMarks = [45, 32, 48, 0, 42];
    const physMarks = [40, 35, 47, 0, 41];
    for (let i = 0; i < studentUUIDs.length; i++) {
        const sId = studentUUIDs[i];
        const isAbs = i === 3 ? 1 : 0; // Diana was absent

        // Chem Marks
        await db.run(
            `
      INSERT INTO marks (id, student_id, exam_id, subject_id, marks_obtained, is_absent, mark_status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
            [
                generateUUID(),
                sId,
                examId,
                subjChemId,
                isAbs ? 0.0 : chemMarks[i],
                isAbs,
                isAbs ? "ABSENT" : "NORMAL",
            ],
        );

        // Phys Marks
        await db.run(
            `
      INSERT INTO marks (id, student_id, exam_id, subject_id, marks_obtained, is_absent, mark_status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
            [
                generateUUID(),
                sId,
                examId,
                subjPhysId,
                isAbs ? 0.0 : physMarks[i],
                isAbs,
                isAbs ? "ABSENT" : "NORMAL",
            ],
        );
    }

    console.log("Mock Data seeded successfully.");
}

module.exports = {
    db,
    initializeDatabase,
    generateUUID,
};
