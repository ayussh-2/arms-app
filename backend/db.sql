-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.academicyear (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  start_date date,
  end_date date,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  organisation_id uuid NOT NULL,
  CONSTRAINT academicyear_pkey PRIMARY KEY (id),
  CONSTRAINT fk_academicyear_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.admin_rights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL,
  rights_id uuid NOT NULL,
  valid_from timestamp with time zone,
  valid_to timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT admin_rights_pkey PRIMARY KEY (id),
  CONSTRAINT admin_rights_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.admins(id),
  CONSTRAINT admin_rights_rights_id_fkey FOREIGN KEY (rights_id) REFERENCES public.rights(id)
);
CREATE TABLE public.admins (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text NOT NULL,
  phone1 text NOT NULL,
  phone2 text,
  gender text,
  age integer,
  img_url text,
  created_at timestamp with time zone DEFAULT now(),
  password text NOT NULL,
  role text NOT NULL DEFAULT 'admin'::text,
  image_version integer NOT NULL,
  is_deleted boolean NOT NULL DEFAULT false,
  admin_id text NOT NULL UNIQUE,
  organisation_id uuid NOT NULL,
  sign_url text,
  sign_url_version integer DEFAULT 1,
  CONSTRAINT admins_pkey PRIMARY KEY (id),
  CONSTRAINT fk_admins_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.alumni (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  code integer NOT NULL UNIQUE,
  batch text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT alumni_pkey PRIMARY KEY (id)
);
CREATE TABLE public.attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  student_id uuid NOT NULL,
  attendance_date date NOT NULL,
  morning_in timestamp with time zone,
  morning_out timestamp with time zone,
  evening_in timestamp with time zone,
  evening_out timestamp with time zone,
  morning_in_status text CHECK ((morning_in_status = ANY (ARRAY['present'::text, 'absent'::text, 'halfday'::text, 'na'::text])) OR morning_in_status IS NULL),
  attendance_source text NOT NULL CHECK (attendance_source = ANY (ARRAY['biometric'::text, 'admin'::text])),
  done_by_admin_id uuid,
  is_manual_override boolean NOT NULL DEFAULT false,
  remarks text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  morning_out_status text CHECK ((morning_out_status = ANY (ARRAY['present'::text, 'absent'::text, 'halfday'::text, 'na'::text])) OR morning_out_status IS NULL),
  evening_in_status text CHECK ((evening_in_status = ANY (ARRAY['present'::text, 'absent'::text, 'halfday'::text, 'na'::text])) OR evening_in_status IS NULL),
  evening_out_status text CHECK ((evening_out_status = ANY (ARRAY['present'::text, 'absent'::text, 'halfday'::text, 'na'::text])) OR evening_out_status IS NULL),
  CONSTRAINT attendance_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id),
  CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id),
  CONSTRAINT attendance_done_by_admin_id_fkey FOREIGN KEY (done_by_admin_id) REFERENCES public.admins(id)
);
CREATE TABLE public.attendance_holidays (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  holiday_name text NOT NULL,
  holiday_type text,
  from_date date NOT NULL,
  to_date date,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  applies_to_school_ids ARRAY,
  applies_to_class_ids ARRAY,
  CONSTRAINT attendance_holidays_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_holidays_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.attendance_leaves (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  student_id uuid NOT NULL,
  from_date date NOT NULL,
  to_date date,
  leave_type text NOT NULL CHECK (leave_type = ANY (ARRAY['fever'::text, 'medical_self'::text, 'medical_relative'::text, 'marriage'::text, 'casual'::text, 'stomach_pain'::text, 'body_pain_headache'::text])),
  reason text,
  approved boolean NOT NULL DEFAULT false,
  approved_by uuid,
  leave_application_image_url text,
  rejected_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT attendance_leaves_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_leaves_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id),
  CONSTRAINT attendance_leaves_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id),
  CONSTRAINT attendance_leaves_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.admins(id)
);
CREATE TABLE public.attendance_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  sync_time timestamp with time zone NOT NULL DEFAULT now(),
  raw_payload jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  received_via text,
  packet_count integer,
  processed_at timestamp with time zone,
  processing_status text,
  CONSTRAINT attendance_logs_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_logs_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.attendance_policies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  name text NOT NULL,
  policy_json jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT attendance_policies_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_policies_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.attendance_report_configurations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT attendance_report_configurations_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_report_configurations_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id),
  CONSTRAINT attendance_report_configurations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.admins(id)
);
CREATE TABLE public.classes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  display_order integer,
  organisation_id uuid NOT NULL,
  CONSTRAINT classes_pkey PRIMARY KEY (id),
  CONSTRAINT fk_classes_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  author_type text NOT NULL CHECK (author_type = ANY (ARRAY['teacher'::text, 'admin'::text])),
  comment_text text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  student_id uuid,
  CONSTRAINT comments_pkey PRIMARY KEY (id),
  CONSTRAINT fk_comments_student FOREIGN KEY (student_id) REFERENCES public.students(id)
);
CREATE TABLE public.exam_subjects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  exam_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  max_marks integer DEFAULT 100,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT exam_subjects_pkey PRIMARY KEY (id),
  CONSTRAINT exam_subjects_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES public.exams(id),
  CONSTRAINT exam_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id)
);
CREATE TABLE public.exams (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  series_id uuid NOT NULL,
  academic_year_id uuid,
  chapter text,
  topic text,
  exam_date date,
  total_marks integer,
  created_at timestamp with time zone DEFAULT now(),
  for_school ARRAY,
  for_class ARRAY,
  for_section ARRAY,
  mark_saved boolean,
  organisation_id uuid NOT NULL,
  attendance_pdf_url text,
  question_pdf_url text,
  is_deleted boolean,
  created_by uuid,
  CONSTRAINT exams_pkey PRIMARY KEY (id),
  CONSTRAINT exams_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.series(id),
  CONSTRAINT exams_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES public.academicyear(id),
  CONSTRAINT fk_exams_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.marks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL,
  exam_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  marks_obtained numeric,
  is_absent boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  mark_status text,
  CONSTRAINT marks_pkey PRIMARY KEY (id),
  CONSTRAINT marks_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id),
  CONSTRAINT marks_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES public.exams(id),
  CONSTRAINT marks_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id)
);
CREATE TABLE public.organisations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  display_name text,
  logo_url text,
  header_url text,
  created_at timestamp with time zone DEFAULT now(),
  helpline_no text DEFAULT '8599800108'::text,
  attendance_devices jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT organisations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.report (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL,
  exam_ids ARRAY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  is_deleted boolean NOT NULL DEFAULT false,
  name text NOT NULL,
  report_config jsonb NOT NULL DEFAULT '{"exam_order": {"order": [], "subjects": {}, "hidden_subjects": {}}, "fail_logic": {"enabled": false, "minimum_overall_percentage": 35, "minimum_subject_percentage": 33, "fail_on_single_subject_fail": true}, "show_exam_date": true, "show_max_marks": true, "round_percentage": 2, "show_grand_total": true, "show_student_pic": false, "calculate_best_of": {"basis": "exam", "enabled": false, "best_of_count": null}, "show_overall_rank": true, "summary_row_color": "#1e3a8a", "display_for_classes": [], "hide_empty_subjects": false, "display_series_total": true, "show_vertical_average": true, "include_absent_as_zero": false, "display_series_subjects": true, "show_overall_percentage": true, "show_vertical_percentage": false, "show_exam_horizontal_rank": false, "show_attendance_percentage": true, "show_subject_horizontal_rank": false, "show_exam_horizontal_percentage": false, "show_subject_horizontal_percentage": false, "display_average_and_percentgae_row_on_top": true}'::jsonb,
  report_preferences jsonb NOT NULL DEFAULT '{"pdf": {"dark_theme": true, "fit_sheet_one_page": false}, "font": {"size": 14, "family": "Inter", "small_size": 9, "header_size": 14}, "page": {"size": "A4", "margin": 0, "orientation": "portrait"}, "table": {"border": true, "header_bold": true, "compact_mode": false, "summary_row_color": "#1e3a8a", "alternate_row_shading": true}, "branding": {"show_school_logo": false, "show_school_name": false, "show_school_header": false}, "gradient": {"lower": {"color": "#ff4d4d", "value": 35}, "upper": {"color": "#00cc66", "value": 90}, "middle": {"color": "#ffd633", "value": 70}, "enabled": true}, "signature": {"show_principal": false, "teacher_admin_id": null, "show_class_teacher": false}, "mark_display": {"show_percentage_symbol": true}, "student_info": {"show_name": true, "show_class": true, "show_roll_no": true, "show_section": true, "show_admission_no": false}}'::jsonb,
  created_by uuid NOT NULL,
  report_card_preferences jsonb,
  CONSTRAINT report_pkey PRIMARY KEY (id),
  CONSTRAINT report_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisations(id),
  CONSTRAINT report_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.admins(id)
);
CREATE TABLE public.rights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  right_name character varying NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT rights_pkey PRIMARY KEY (id)
);
CREATE TABLE public.schools (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  display_order integer,
  organisation_id uuid NOT NULL,
  CONSTRAINT schools_pkey PRIMARY KEY (id),
  CONSTRAINT fk_schools_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.sections (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  display_order integer,
  organisation_id uuid NOT NULL,
  CONSTRAINT sections_pkey PRIMARY KEY (id),
  CONSTRAINT fk_sections_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.series (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  display_order integer,
  organisation_id uuid NOT NULL,
  CONSTRAINT series_pkey PRIMARY KEY (id),
  CONSTRAINT fk_series_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.series_subjects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  series_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  display_order integer,
  CONSTRAINT series_subjects_pkey PRIMARY KEY (id),
  CONSTRAINT series_subjects_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.series(id),
  CONSTRAINT series_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id)
);
CREATE TABLE public.student_tags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tag_id uuid UNIQUE,
  assigned_by uuid,
  assigned_by_type text CHECK (assigned_by_type = ANY (ARRAY['admin'::text, 'teacher'::text])),
  created_at timestamp with time zone DEFAULT now(),
  student_id uuid,
  CONSTRAINT student_tags_pkey PRIMARY KEY (id),
  CONSTRAINT student_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id),
  CONSTRAINT fk_student_tags_student FOREIGN KEY (student_id) REFERENCES public.students(id)
);
CREATE TABLE public.students (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  roll_no integer NOT NULL,
  image_url text,
  created_at timestamp with time zone DEFAULT now(),
  phone1 text,
  phone2 text,
  address text,
  gender text,
  age integer,
  is_deleted boolean DEFAULT false,
  image_version integer NOT NULL DEFAULT 0,
  email text,
  password text,
  school_id uuid,
  class_id uuid,
  section_id uuid,
  fl_batch_id uuid,
  organisation_id uuid NOT NULL,
  father_name text,
  mother_name text,
  dob date,
  category text,
  CONSTRAINT students_pkey PRIMARY KEY (id),
  CONSTRAINT fk_students_school_uuid FOREIGN KEY (school_id) REFERENCES public.schools(id),
  CONSTRAINT fk_students_class_uuid FOREIGN KEY (class_id) REFERENCES public.classes(id),
  CONSTRAINT fk_students_section_uuid FOREIGN KEY (section_id) REFERENCES public.sections(id),
  CONSTRAINT fk_students_fl_batch_uuid FOREIGN KEY (fl_batch_id) REFERENCES public.alumni(id),
  CONSTRAINT fk_students_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.subjects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text,
  created_at timestamp with time zone DEFAULT now(),
  display_order integer,
  organisation_id uuid NOT NULL,
  CONSTRAINT subjects_pkey PRIMARY KEY (id),
  CONSTRAINT fk_subjects_org FOREIGN KEY (organisation_id) REFERENCES public.organisations(id)
);
CREATE TABLE public.tags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT tags_pkey PRIMARY KEY (id)
);