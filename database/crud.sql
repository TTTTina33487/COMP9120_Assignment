-- Basic CRUD examples for the database/data work package.
-- The script is wrapped in a transaction and rolled back, so seed data is unchanged.

BEGIN;
SET search_path TO remote_education, public;

-- CREATE: add a synthetic region, school and student.
INSERT INTO region
    (region_name, remoteness_level, internet_access_level, support_priority_level)
VALUES
    ('CRUD Demonstration Region', 'remote', 'low', 'high');

INSERT INTO school (region_id, school_name, school_type)
SELECT region_id, 'CRUD Demonstration School', 'combined'
FROM region
WHERE region_name = 'CRUD Demonstration Region';

INSERT INTO student
    (school_id, first_name, last_name, year_level, has_device, internet_access_level)
SELECT school_id, 'Test', 'Learner', 9, FALSE, 'low'
FROM school
WHERE school_name = 'CRUD Demonstration School';

-- READ: retrieve the student together with school and regional context.
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    s.year_level,
    sc.school_name,
    r.region_name,
    r.remoteness_level
FROM student AS s
JOIN school AS sc ON sc.school_id = s.school_id
JOIN region AS r ON r.region_id = sc.region_id
WHERE s.first_name = 'Test' AND s.last_name = 'Learner';

-- UPDATE: record that the student now has a suitable device.
UPDATE student
SET has_device = TRUE
WHERE first_name = 'Test' AND last_name = 'Learner'
RETURNING student_id, first_name, last_name, has_device;

-- DELETE: remove in child-to-parent order because the schema intentionally
-- uses RESTRICT for educational context records.
DELETE FROM student
WHERE first_name = 'Test' AND last_name = 'Learner';

DELETE FROM school
WHERE school_name = 'CRUD Demonstration School';

DELETE FROM region
WHERE region_name = 'CRUD Demonstration Region';

ROLLBACK;

