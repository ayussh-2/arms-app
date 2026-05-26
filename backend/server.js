const { ApolloServer } = require("@apollo/server");
const { expressMiddleware } = require("@apollo/server/express4");
const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { db, initializeDatabase } = require("./db");

const PORT = process.env.PORT || 4000;

// Read the GraphQL Schema file
const typeDefs = fs.readFileSync(
    path.join(__dirname, "schema.graphql"),
    "utf-8",
);

// Define Resolvers
const resolvers = {
    Query: {
        organisations: () => db.all("SELECT * FROM organisations"),
        academicYears: () => db.all("SELECT * FROM academicyear"),
        schools: () => db.all("SELECT * FROM schools ORDER BY display_order"),
        classes: () => db.all("SELECT * FROM classes ORDER BY display_order"),
        sections: () => db.all("SELECT * FROM sections ORDER BY display_order"),
        subjects: () => db.all("SELECT * FROM subjects ORDER BY display_order"),
        series: () => db.all("SELECT * FROM series ORDER BY display_order"),
        admins: () => db.all("SELECT * FROM admins"),

        students: async (_, { classId, sectionId, schoolId }) => {
            let sql = "SELECT * FROM students WHERE is_deleted = 0";
            const params = [];
            if (classId) {
                sql += " AND class_id = ?";
                params.push(classId);
            }
            if (sectionId) {
                sql += " AND section_id = ?";
                params.push(sectionId);
            }
            if (schoolId) {
                sql += " AND school_id = ?";
                params.push(schoolId);
            }
            sql += " ORDER BY roll_no ASC";
            return db.all(sql, params);
        },

        student: (_, { id }) =>
            db.get("SELECT * FROM students WHERE id = ?", [id]),

        exams: async (_, { classId, sectionId, seriesId }) => {
            const allExams = await db.all(
                "SELECT * FROM exams WHERE is_deleted = 0",
            );
            return allExams.filter((exam) => {
                let match = true;
                if (classId) {
                    const classes = JSON.parse(exam.for_class || "[]");
                    if (!classes.includes(classId)) match = false;
                }
                if (sectionId) {
                    const sections = JSON.parse(exam.for_section || "[]");
                    if (!sections.includes(sectionId)) match = false;
                }
                if (seriesId && exam.series_id !== seriesId) {
                    match = false;
                }
                return match;
            });
        },

        exam: (_, { id }) => db.get("SELECT * FROM exams WHERE id = ?", [id]),

        attendance: (_, { classId, sectionId, date }) => {
            return db.all(
                `
        SELECT a.* FROM attendance a
        JOIN students s ON a.student_id = s.id
        WHERE s.class_id = ? AND s.section_id = ? AND a.attendance_date = ?
      `,
                [classId, sectionId, date],
            );
        },

        leaves: (_, { status }) => {
            let sql = "SELECT * FROM attendance_leaves";
            const params = [];
            if (status) {
                if (status.toLowerCase() === "approved") {
                    sql += " WHERE approved = 1";
                } else if (status.toLowerCase() === "pending") {
                    sql += " WHERE approved = 0 AND rejected_reason IS NULL";
                } else if (status.toLowerCase() === "rejected") {
                    sql +=
                        " WHERE approved = 0 AND rejected_reason IS NOT NULL";
                }
            }
            sql += " ORDER BY from_date DESC";
            return db.all(sql, params);
        },

        marks: (_, { examId }) => {
            return db.all("SELECT * FROM marks WHERE exam_id = ?", [examId]);
        },
    },

    Student: {
        school: (student) =>
            db.get("SELECT * FROM schools WHERE id = ?", [student.school_id]),
        class: (student) =>
            db.get("SELECT * FROM classes WHERE id = ?", [student.class_id]),
        section: (student) =>
            db.get("SELECT * FROM sections WHERE id = ?", [student.section_id]),
        alumniBatch: (student) =>
            db.get("SELECT * FROM alumni WHERE id = ?", [student.fl_batch_id]),
        attendance: (student) =>
            db.all(
                "SELECT * FROM attendance WHERE student_id = ? ORDER BY attendance_date DESC",
                [student.id],
            ),
        marks: (student) =>
            db.all("SELECT * FROM marks WHERE student_id = ?", [student.id]),
    },

    Attendance: {
        student: (att) =>
            db.get("SELECT * FROM students WHERE id = ?", [att.student_id]),
        done_by_admin: (att) =>
            att.done_by_admin_id
                ? db.get("SELECT * FROM admins WHERE id = ?", [
                      att.done_by_admin_id,
                  ])
                : null,
        is_manual_override: (att) => att.is_manual_override === 1,
    },

    AttendanceLeave: {
        student: (leave) =>
            db.get("SELECT * FROM students WHERE id = ?", [leave.student_id]),
        approved: (leave) => leave.approved === 1,
        approved_by: (leave) =>
            leave.approved_by
                ? db.get("SELECT * FROM admins WHERE id = ?", [
                      leave.approved_by,
                  ])
                : null,
    },

    Exam: {
        series: (exam) =>
            db.get("SELECT * FROM series WHERE id = ?", [exam.series_id]),
        academic_year: (exam) =>
            db.get("SELECT * FROM academicyear WHERE id = ?", [
                exam.academic_year_id,
            ]),
        created_by: (exam) =>
            exam.created_by
                ? db.get("SELECT * FROM admins WHERE id = ?", [exam.created_by])
                : null,
        mark_saved: (exam) => exam.mark_saved === 1,
        subjects: (exam) =>
            db.all("SELECT * FROM exam_subjects WHERE exam_id = ?", [exam.id]),
    },

    ExamSubject: {
        subject: (es) =>
            db.get("SELECT * FROM subjects WHERE id = ?", [es.subject_id]),
    },

    Mark: {
        student: (m) =>
            db.get("SELECT * FROM students WHERE id = ?", [m.student_id]),
        exam: (m) => db.get("SELECT * FROM exams WHERE id = ?", [m.exam_id]),
        subject: (m) =>
            db.get("SELECT * FROM subjects WHERE id = ?", [m.subject_id]),
        is_absent: (m) => m.is_absent === 1,
    },

    Mutation: {
        saveAttendance: async (_, { input }) => {
            console.log(
                `Received bulk attendance save: ${input.length} records.`,
            );
            for (const item of input) {
                const student = await db.get(
                    "SELECT organisation_id FROM students WHERE id = ?",
                    [item.student_id],
                );
                if (!student) continue;

                const orgId = student.organisation_id;
                const existing = await db.get(
                    "SELECT id FROM attendance WHERE student_id = ? AND attendance_date = ?",
                    [item.student_id, item.attendance_date],
                );

                const morningStatus = item.morning_in_status || "present";
                const eveningStatus = item.evening_in_status || "present";

                if (existing) {
                    await db.run(
                        `
            UPDATE attendance
            SET morning_in_status = ?, morning_out_status = ?, evening_in_status = ?, evening_out_status = ?,
                remarks = ?, done_by_admin_id = ?, is_manual_override = 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
          `,
                        [
                            morningStatus,
                            morningStatus,
                            eveningStatus,
                            eveningStatus,
                            item.remarks || "",
                            item.admin_id,
                            existing.id,
                        ],
                    );
                } else {
                    await db.run(
                        `
            INSERT INTO attendance (
              id, organisation_id, student_id, attendance_date,
              morning_in_status, morning_out_status, evening_in_status, evening_out_status,
              attendance_source, done_by_admin_id, is_manual_override, remarks
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'admin', ?, 1, ?)
          `,
                        [
                            crypto.randomUUID(),
                            orgId,
                            item.student_id,
                            item.attendance_date,
                            morningStatus,
                            morningStatus,
                            eveningStatus,
                            eveningStatus,
                            item.admin_id,
                            item.remarks || "",
                        ],
                    );
                }
            }
            return true;
        },

        applyLeave: async (_, { input }) => {
            console.log(`Applying leave for student: ${input.student_id}`);
            const student = await db.get(
                "SELECT organisation_id FROM students WHERE id = ?",
                [input.student_id],
            );
            if (!student) {
                throw new Error("Student not found");
            }

            const leaveId = crypto.randomUUID();
            await db.run(
                `
        INSERT INTO attendance_leaves (
          id, organisation_id, student_id, from_date, to_date, leave_type, reason, approved
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `,
                [
                    leaveId,
                    student.organisation_id,
                    input.student_id,
                    input.from_date,
                    input.to_date || null,
                    input.leave_type,
                    input.reason || "",
                    0,
                ],
            );

            return db.get("SELECT * FROM attendance_leaves WHERE id = ?", [
                leaveId,
            ]);
        },

        updateLeaveStatus: async (_, { id, approved, rejectedReason }) => {
            console.log(
                `Updating leave approval status: id=${id}, approved=${approved}`,
            );
            await db.run(
                `
        UPDATE attendance_leaves
        SET approved = ?, rejected_reason = ?
        WHERE id = ?
      `,
                [approved ? 1 : 0, rejectedReason || null, id],
            );

            return db.get("SELECT * FROM attendance_leaves WHERE id = ?", [id]);
        },

        saveMarks: async (_, { input }) => {
            console.log(`Saving marks: ${input.length} records.`);
            if (input.length === 0) return true;

            for (const item of input) {
                const existing = await db.get(
                    "SELECT id FROM marks WHERE student_id = ? AND exam_id = ? AND subject_id = ?",
                    [item.student_id, item.exam_id, item.subject_id],
                );

                if (existing) {
                    await db.run(
                        `
            UPDATE marks
            SET marks_obtained = ?, is_absent = ?, mark_status = ?
            WHERE id = ?
          `,
                        [
                            item.marks_obtained || 0.0,
                            item.is_absent ? 1 : 0,
                            item.mark_status || "NORMAL",
                            existing.id,
                        ],
                    );
                } else {
                    await db.run(
                        `
            INSERT INTO marks (id, student_id, exam_id, subject_id, marks_obtained, is_absent, mark_status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
          `,
                        [
                            crypto.randomUUID(),
                            item.student_id,
                            item.exam_id,
                            item.subject_id,
                            item.marks_obtained || 0.0,
                            item.is_absent ? 1 : 0,
                            item.mark_status || "NORMAL",
                        ],
                    );
                }
            }

            // Mark exam as marks_saved
            await db.run("UPDATE exams SET mark_saved = 1 WHERE id = ?", [
                input[0].exam_id,
            ]);
            return true;
        },
    },
};

async function startServer() {
    // Ensure database and mock seeds are fully ready
    await initializeDatabase();

    const app = express();

    // Set up Apollo Server
    const server = new ApolloServer({
        typeDefs,
        resolvers,
    });

    await server.start();

    // Middleware rules
    app.use(cors());
    app.use(express.json());

    // Mount GraphQL handler
    app.use("/graphql", expressMiddleware(server));
    app.get("/ping", (req, res) => res.send("pong"));
    // Mount index landing page
    app.get("/", (req, res) => {
        res.send(`
        <h1>Welcome to ARMS GraphQL API Mock Server</h1>
    `);
    });

    app.listen(PORT, () => {
        console.log(`\n🚀 ARMS GraphQL API Mock Server is ready!`);
        console.log(
            `👉 GraphQL API Endpoint: http://localhost:${PORT}/graphql`,
        );
        console.log(`👉 Web Portal:         http://localhost:${PORT}/\n`);
    });
}

startServer().catch((err) => {
    console.error("Failed to start GraphQL mock server:", err);
});
