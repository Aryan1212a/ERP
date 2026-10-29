CREATE TABLE colleges (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id),
  email VARCHAR(255) UNIQUE NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) DEFAULT 'student',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE classes (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id),
  name VARCHAR(100) NOT NULL
);

CREATE TABLE attendance (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id),
  class_id INTEGER NOT NULL REFERENCES classes(id),
  student_id INTEGER NOT NULL REFERENCES users(id),
  date DATE NOT NULL,
  status VARCHAR(20) NOT NULL
);

CREATE TABLE timetable (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id),
  class_id INTEGER NOT NULL REFERENCES classes(id),
  day_of_week INTEGER NOT NULL,
  period INTEGER NOT NULL,
  subject VARCHAR(100) NOT NULL
);

CREATE TABLE fees (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id),
  student_id INTEGER NOT NULL REFERENCES users(id),
  amount INTEGER NOT NULL,
  due_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE notices (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id),
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- College academic structure. The existing school_id is the tenant/college key.
CREATE TABLE departments (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  name VARCHAR(150) NOT NULL,
  code VARCHAR(20) NOT NULL
);

CREATE TABLE programs (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  department_id INTEGER NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  name VARCHAR(150) NOT NULL,
  code VARCHAR(20) NOT NULL,
  duration_years INTEGER NOT NULL
);

CREATE TABLE courses (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  department_id INTEGER NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  code VARCHAR(20) NOT NULL,
  title VARCHAR(200) NOT NULL,
  credits INTEGER NOT NULL DEFAULT 3
);

CREATE TABLE academic_terms (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  name VARCHAR(80) NOT NULL,
  starts_on DATE NOT NULL,
  ends_on DATE NOT NULL
);

CREATE TABLE course_offerings (
  id SERIAL PRIMARY KEY,
  school_id INTEGER NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  term_id INTEGER NOT NULL REFERENCES academic_terms(id) ON DELETE CASCADE,
  faculty_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  section VARCHAR(20) NOT NULL DEFAULT 'A',
  room VARCHAR(50)
);

CREATE TABLE enrollments (
  id SERIAL PRIMARY KEY,
  offering_id INTEGER NOT NULL REFERENCES course_offerings(id) ON DELETE CASCADE,
  student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMP NOT NULL DEFAULT NOW(),
  status VARCHAR(20) NOT NULL DEFAULT 'enrolled',
  CONSTRAINT uq_enrollment_offering_student UNIQUE (offering_id, student_id)
);
