-- Realistic synthetic data for the remote education prototype.
-- Run once after database/schema.sql.

BEGIN;
SET search_path TO remote_education, public;

INSERT INTO region
    (region_name, remoteness_level, internet_access_level, support_priority_level)
VALUES
    ('Western Plains',     'remote',      'low',      'high'),
    ('Northern Highlands', 'very_remote', 'very_low', 'critical'),
    ('Desert Coast',       'very_remote', 'none',     'critical'),
    ('Riverland',          'regional',    'medium',   'medium'),
    ('Island Communities', 'remote',      'low',      'high');

INSERT INTO school (region_id, school_name, school_type)
SELECT region_id, 'Mallee Remote College', 'combined'
FROM region WHERE region_name = 'Western Plains'
UNION ALL
SELECT region_id, 'Outback Community School', 'combined'
FROM region WHERE region_name = 'Northern Highlands'
UNION ALL
SELECT region_id, 'Cape York Learning Centre', 'secondary'
FROM region WHERE region_name = 'Desert Coast'
UNION ALL
SELECT region_id, 'Riverland District High', 'secondary'
FROM region WHERE region_name = 'Riverland'
UNION ALL
SELECT region_id, 'Island Community College', 'combined'
FROM region WHERE region_name = 'Island Communities';

INSERT INTO coordinator (school_id, coordinator_name, role)
SELECT school_id, 'Amelia Carter', 'Student Support Coordinator'
FROM school WHERE school_name = 'Mallee Remote College'
UNION ALL
SELECT school_id, 'Noah Williams', 'Learning Access Coordinator'
FROM school WHERE school_name = 'Outback Community School'
UNION ALL
SELECT school_id, 'Olivia Chen', 'Education Support Coordinator'
FROM school WHERE school_name = 'Cape York Learning Centre'
UNION ALL
SELECT school_id, 'Ethan Brown', 'Student Services Coordinator'
FROM school WHERE school_name = 'Riverland District High'
UNION ALL
SELECT school_id, 'Mia Thompson', 'Remote Learning Coordinator'
FROM school WHERE school_name = 'Island Community College';

INSERT INTO student
    (school_id, first_name, last_name, year_level, has_device, internet_access_level)
SELECT school_id, 'Ava', 'Mitchell', 8, FALSE, 'low'
FROM school WHERE school_name = 'Mallee Remote College'
UNION ALL
SELECT school_id, 'Liam', 'Nguyen', 10, TRUE, 'low'
FROM school WHERE school_name = 'Mallee Remote College'
UNION ALL
SELECT school_id, 'Sophie', 'Johnson', 7, TRUE, 'very_low'
FROM school WHERE school_name = 'Outback Community School'
UNION ALL
SELECT school_id, 'Noah', 'Davis', 9, FALSE, 'very_low'
FROM school WHERE school_name = 'Outback Community School'
UNION ALL
SELECT school_id, 'Isla', 'Wilson', 11, TRUE, 'none'
FROM school WHERE school_name = 'Cape York Learning Centre'
UNION ALL
SELECT school_id, 'Jack', 'Martin', 6, FALSE, 'none'
FROM school WHERE school_name = 'Cape York Learning Centre'
UNION ALL
SELECT school_id, 'Mia', 'Lee', 12, TRUE, 'medium'
FROM school WHERE school_name = 'Riverland District High'
UNION ALL
SELECT school_id, 'Lucas', 'Taylor', 9, TRUE, 'medium'
FROM school WHERE school_name = 'Riverland District High'
UNION ALL
SELECT school_id, 'Chloe', 'Anderson', 8, FALSE, 'low'
FROM school WHERE school_name = 'Island Community College'
UNION ALL
SELECT school_id, 'Ethan', 'White', 10, TRUE, 'low'
FROM school WHERE school_name = 'Island Community College';

INSERT INTO eligibility_type (type_name, description)
VALUES
    ('Remote Area Resident', 'Student lives in an eligible remote or very remote region.'),
    ('Low Income Household', 'Household income meets the programme threshold.'),
    ('Device Access Need', 'Student does not have reliable access to a suitable learning device.'),
    ('Limited Internet Access', 'Student has no or very limited internet connectivity.'),
    ('First Nations Education Support', 'Student is eligible for the targeted First Nations education programme.');

INSERT INTO student_eligibility
    (student_id, eligibility_type_id, verified_date, expiry_date, verification_status)
SELECT s.student_id, et.eligibility_type_id, DATE '2026-08-01', DATE '2027-07-31', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Ava' AND s.last_name = 'Mitchell'
  AND et.type_name = 'Device Access Need'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-08-01', DATE '2027-07-31', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Ava' AND s.last_name = 'Mitchell'
  AND et.type_name = 'Remote Area Resident'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-07-20', DATE '2027-07-19', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Liam' AND s.last_name = 'Nguyen'
  AND et.type_name = 'Remote Area Resident'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-08-15', DATE '2027-08-14', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Sophie' AND s.last_name = 'Johnson'
  AND et.type_name = 'Limited Internet Access'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-08-15', DATE '2027-08-14', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Sophie' AND s.last_name = 'Johnson'
  AND et.type_name = 'Low Income Household'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, NULL, NULL, 'pending'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Noah' AND s.last_name = 'Davis'
  AND et.type_name = 'Low Income Household'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-06-01', DATE '2027-05-31', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Isla' AND s.last_name = 'Wilson'
  AND et.type_name = 'First Nations Education Support'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-06-01', DATE '2027-05-31', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Jack' AND s.last_name = 'Martin'
  AND et.type_name = 'Remote Area Resident'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-09-01', DATE '2027-08-31', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Lucas' AND s.last_name = 'Taylor'
  AND et.type_name = 'Low Income Household'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-09-05', DATE '2027-09-04', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Chloe' AND s.last_name = 'Anderson'
  AND et.type_name = 'Device Access Need'
UNION ALL
SELECT s.student_id, et.eligibility_type_id, DATE '2026-09-05', DATE '2027-09-04', 'verified'
FROM student s CROSS JOIN eligibility_type et
WHERE s.first_name = 'Ethan' AND s.last_name = 'White'
  AND et.type_name = 'Low Income Household';

INSERT INTO organisation (organisation_name, contact_email)
VALUES
    ('Open Learning Australia', 'resources@openlearning.example'),
    ('Global Education Fund', 'grants@globaleducation.example'),
    ('Rural Futures Network', 'programs@ruralfutures.example'),
    ('TechBridge Foundation', 'support@techbridge.example'),
    ('Community Tutor Alliance', 'coordination@communitytutors.example'),
    ('BrightStart Trust', 'funding@brightstart.example');

INSERT INTO provider (organisation_id)
SELECT organisation_id FROM organisation
WHERE organisation_name IN
      ('Open Learning Australia', 'Rural Futures Network',
       'TechBridge Foundation', 'Community Tutor Alliance');

INSERT INTO funder (organisation_id)
SELECT organisation_id FROM organisation
WHERE organisation_name IN
      ('Global Education Fund', 'Rural Futures Network',
       'TechBridge Foundation', 'BrightStart Trust');

INSERT INTO resource_offering
    (provider_id, required_eligibility_type_id, resource_name,
     resource_type, subject_area, total_quantity, expiry_date)
SELECT o.organisation_id, et.eligibility_type_id,
       'Offline Mathematics Course Pack', 'offline_course', 'Mathematics', 40, DATE '2027-06-30'
FROM organisation o CROSS JOIN eligibility_type et
WHERE o.organisation_name = 'Open Learning Australia'
  AND et.type_name = 'Remote Area Resident'
UNION ALL
SELECT o.organisation_id, et.eligibility_type_id,
       'Weekly Online Mathematics Tutoring', 'online_tutoring', 'Mathematics', 25, DATE '2027-04-30'
FROM organisation o CROSS JOIN eligibility_type et
WHERE o.organisation_name = 'Community Tutor Alliance'
  AND et.type_name = 'Low Income Household'
UNION ALL
SELECT o.organisation_id, et.eligibility_type_id,
       'Refurbished Learning Device', 'device', 'General', 30, DATE '2027-12-31'
FROM organisation o CROSS JOIN eligibility_type et
WHERE o.organisation_name = 'TechBridge Foundation'
  AND et.type_name = 'Device Access Need'
UNION ALL
SELECT o.organisation_id, et.eligibility_type_id,
       'Satellite Internet Learning Voucher', 'connectivity', 'General', 20, DATE '2027-09-30'
FROM organisation o CROSS JOIN eligibility_type et
WHERE o.organisation_name = 'Rural Futures Network'
  AND et.type_name = 'Limited Internet Access'
UNION ALL
SELECT o.organisation_id, et.eligibility_type_id,
       'Science Experiment Kit', 'physical_kit', 'Science', 35, DATE '2027-08-31'
FROM organisation o CROSS JOIN eligibility_type et
WHERE o.organisation_name = 'Open Learning Australia'
  AND et.type_name = 'Remote Area Resident'
UNION ALL
SELECT o.organisation_id, NULL,
       'English Literacy Mentoring', 'online_tutoring', 'English', 30, DATE '2027-05-31'
FROM organisation o
WHERE o.organisation_name = 'Community Tutor Alliance'
UNION ALL
SELECT o.organisation_id, et.eligibility_type_id,
       'First Nations STEM Mentoring', 'blended_mentoring', 'Science', 18, DATE '2027-10-31'
FROM organisation o CROSS JOIN eligibility_type et
WHERE o.organisation_name = 'Rural Futures Network'
  AND et.type_name = 'First Nations Education Support'
UNION ALL
SELECT o.organisation_id, NULL,
       'Downloadable Year 10 Study Library', 'digital_library', 'General', 100, DATE '2027-12-31'
FROM organisation o
WHERE o.organisation_name = 'Open Learning Australia';

INSERT INTO resource_funding (offering_id, funder_id)
SELECT ro.offering_id, o.organisation_id
FROM resource_offering ro CROSS JOIN organisation o
WHERE ro.resource_name IN
      ('Offline Mathematics Course Pack', 'Science Experiment Kit')
  AND o.organisation_name = 'Global Education Fund'
UNION ALL
SELECT ro.offering_id, o.organisation_id
FROM resource_offering ro CROSS JOIN organisation o
WHERE ro.resource_name IN
      ('Refurbished Learning Device', 'Satellite Internet Learning Voucher')
  AND o.organisation_name = 'TechBridge Foundation'
UNION ALL
SELECT ro.offering_id, o.organisation_id
FROM resource_offering ro CROSS JOIN organisation o
WHERE ro.resource_name IN
      ('Weekly Online Mathematics Tutoring', 'English Literacy Mentoring')
  AND o.organisation_name = 'BrightStart Trust'
UNION ALL
SELECT ro.offering_id, o.organisation_id
FROM resource_offering ro CROSS JOIN organisation o
WHERE ro.resource_name = 'First Nations STEM Mentoring'
  AND o.organisation_name IN ('Global Education Fund', 'Rural Futures Network');

-- Applications include pending, under-review, approved and rejected examples.
INSERT INTO application
    (student_id, offering_id, reviewer_id, application_date,
     requested_quantity, learning_goal, priority_level,
     decision_status, decision_date, decision_reason)
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-09-20',
       1, 'Gain reliable access to online learning activities.', 'high',
       'approved', TIMESTAMPTZ '2026-09-21 10:00:00+10', 'Verified device access need.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Ava' AND s.last_name = 'Mitchell'
  AND ro.resource_name = 'Refurbished Learning Device'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-09-22',
       2, 'Prepare for Year 10 mathematics assessment.', 'high',
       'approved', TIMESTAMPTZ '2026-09-23 11:00:00+10', 'Remote-area eligibility verified.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Liam' AND s.last_name = 'Nguyen'
  AND ro.resource_name = 'Offline Mathematics Course Pack'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-09-24',
       2, 'Improve connectivity for weekly course participation.', 'urgent',
       'approved', TIMESTAMPTZ '2026-09-25 09:30:00+10', 'Limited internet access verified.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Sophie' AND s.last_name = 'Johnson'
  AND ro.resource_name = 'Satellite Internet Learning Voucher'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-09-26',
       3, 'Receive additional mathematics tutoring.', 'medium',
       'rejected', TIMESTAMPTZ '2026-09-27 14:00:00+10', 'Required eligibility is still pending.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Noah' AND s.last_name = 'Davis'
  AND ro.resource_name = 'Weekly Online Mathematics Tutoring'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-09-28',
       1, 'Join a culturally relevant STEM mentoring programme.', 'high',
       'approved', TIMESTAMPTZ '2026-09-29 13:00:00+10', 'Programme eligibility verified.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Isla' AND s.last_name = 'Wilson'
  AND ro.resource_name = 'First Nations STEM Mentoring'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-10-02',
       1, 'Complete practical science activities without laboratory access.', 'high',
       'under_review', NULL, NULL
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Jack' AND s.last_name = 'Martin'
  AND ro.resource_name = 'Science Experiment Kit'
UNION ALL
SELECT s.student_id, ro.offering_id, NULL, DATE '2026-10-05',
       1, 'Access revision materials for final-year subjects.', 'medium',
       'pending', NULL, NULL
FROM student s CROSS JOIN resource_offering ro
WHERE s.first_name = 'Mia' AND s.last_name = 'Lee'
  AND ro.resource_name = 'Downloadable Year 10 Study Library'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-10-06',
       2, 'Improve academic writing and reading confidence.', 'medium',
       'approved', TIMESTAMPTZ '2026-10-07 10:30:00+11', 'Offering has no additional eligibility requirement.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Lucas' AND s.last_name = 'Taylor'
  AND ro.resource_name = 'English Literacy Mentoring'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-10-08',
       1, 'Obtain a device for homework and video lessons.', 'urgent',
       'approved', TIMESTAMPTZ '2026-10-09 12:00:00+11', 'Device access need verified.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Chloe' AND s.last_name = 'Anderson'
  AND ro.resource_name = 'Refurbished Learning Device'
UNION ALL
SELECT s.student_id, ro.offering_id, c.coordinator_id, DATE '2026-10-10',
       4, 'Receive weekly support for advanced mathematics.', 'high',
       'approved', TIMESTAMPTZ '2026-10-11 15:00:00+11', 'Low-income eligibility verified.'
FROM student s JOIN school sc ON sc.school_id = s.school_id
JOIN coordinator c ON c.school_id = sc.school_id
CROSS JOIN resource_offering ro
WHERE s.first_name = 'Ethan' AND s.last_name = 'White'
  AND ro.resource_name = 'Weekly Online Mathematics Tutoring';

-- Multiple rows for the same application demonstrate staged/partial allocation.
INSERT INTO allocation
    (application_id, allocation_date, quantity_allocated, allocation_status)
SELECT ap.application_id, TIMESTAMPTZ '2026-09-22 09:00:00+10', 1, 'completed'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Ava' AND s.last_name = 'Mitchell'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-09-24 09:00:00+10', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Liam' AND s.last_name = 'Nguyen'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-10-01 09:00:00+10', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Liam' AND s.last_name = 'Nguyen'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-09-26 09:00:00+10', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Sophie' AND s.last_name = 'Johnson'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-09-30 09:00:00+10', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Isla' AND s.last_name = 'Wilson'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-10-08 09:00:00+11', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Lucas' AND s.last_name = 'Taylor'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-10-12 09:00:00+11', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Lucas' AND s.last_name = 'Taylor'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-10-10 09:00:00+11', 1, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Chloe' AND s.last_name = 'Anderson'
UNION ALL
SELECT ap.application_id, TIMESTAMPTZ '2026-10-12 10:00:00+11', 2, 'active'
FROM application ap JOIN student s ON s.student_id = ap.student_id
WHERE s.first_name = 'Ethan' AND s.last_name = 'White';

INSERT INTO usage_record
    (allocation_id, record_no, record_date, usage_type, usage_status, notes)
SELECT al.allocation_id, 1, DATE '2026-09-25', 'device_delivery', 'completed', 'Device delivered to the school.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-09-22 09:00:00+10'
UNION ALL
SELECT al.allocation_id, 2, DATE '2026-10-05', 'device_setup', 'completed', 'Student account and offline materials configured.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-09-22 09:00:00+10'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-09-28', 'course_pack_delivery', 'completed', 'First course pack collected from school.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-09-24 09:00:00+10'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-04', 'course_pack_delivery', 'completed', 'Second course pack collected from school.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-10-01 09:00:00+10'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-01', 'voucher_activation', 'in_progress', 'First connectivity voucher activated.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-09-26 09:00:00+10'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-06', 'mentoring_session', 'completed', 'Initial STEM mentoring session attended.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-09-30 09:00:00+10'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-10', 'mentoring_session', 'completed', 'First literacy session completed.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-10-08 09:00:00+11'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-14', 'mentoring_session', 'scheduled', 'Second literacy session scheduled.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-10-12 09:00:00+11'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-13', 'device_delivery', 'completed', 'Device delivered through island school office.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-10-10 09:00:00+11'
UNION ALL
SELECT al.allocation_id, 1, DATE '2026-10-15', 'tutoring_session', 'scheduled', 'First two tutoring sessions reserved.'
FROM allocation al
WHERE al.allocation_date = TIMESTAMPTZ '2026-10-12 10:00:00+11';

COMMIT;
