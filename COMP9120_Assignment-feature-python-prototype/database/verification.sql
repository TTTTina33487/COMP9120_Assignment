-- Verification queries for schema, data and the two aggregate allocation rules.

SET search_path TO remote_education, public;

-- Row counts should confirm that all core relations were populated.
SELECT 'region' AS relation, COUNT(*) AS rows FROM region
UNION ALL SELECT 'school', COUNT(*) FROM school
UNION ALL SELECT 'coordinator', COUNT(*) FROM coordinator
UNION ALL SELECT 'student', COUNT(*) FROM student
UNION ALL SELECT 'eligibility_type', COUNT(*) FROM eligibility_type
UNION ALL SELECT 'student_eligibility', COUNT(*) FROM student_eligibility
UNION ALL SELECT 'organisation', COUNT(*) FROM organisation
UNION ALL SELECT 'provider', COUNT(*) FROM provider
UNION ALL SELECT 'funder', COUNT(*) FROM funder
UNION ALL SELECT 'resource_offering', COUNT(*) FROM resource_offering
UNION ALL SELECT 'resource_funding', COUNT(*) FROM resource_funding
UNION ALL SELECT 'application', COUNT(*) FROM application
UNION ALL SELECT 'allocation', COUNT(*) FROM allocation
UNION ALL SELECT 'usage_record', COUNT(*) FROM usage_record
ORDER BY relation;

-- Expected result: zero rows. No application is over-allocated.
SELECT *
FROM v_application_fulfilment
WHERE allocated_quantity > requested_quantity;

-- Expected result: zero rows. No offering is over-allocated.
SELECT *
FROM v_offering_capacity
WHERE allocated_quantity > total_quantity;

-- Demonstrates that one application may have multiple allocation rows.
SELECT
    s.first_name || ' ' || s.last_name AS student,
    ro.resource_name,
    ap.requested_quantity,
    COUNT(al.allocation_id) AS allocation_events,
    COALESCE(SUM(al.quantity_allocated), 0) AS allocated_quantity
FROM application ap
JOIN student s ON s.student_id = ap.student_id
JOIN resource_offering ro ON ro.offering_id = ap.offering_id
LEFT JOIN allocation al
       ON al.application_id = ap.application_id
      AND al.allocation_status IN ('active', 'completed')
GROUP BY ap.application_id, s.first_name, s.last_name,
         ro.resource_name, ap.requested_quantity
ORDER BY student;

-- Demonstrates the overlapping ISA case: organisations that are both roles.
SELECT o.organisation_name
FROM organisation o
JOIN provider p ON p.organisation_id = o.organisation_id
JOIN funder f ON f.organisation_id = o.organisation_id
ORDER BY o.organisation_name;

-- Demonstrates eligibility matching between student and offering.
SELECT
    s.first_name || ' ' || s.last_name AS student,
    ro.resource_name,
    et.type_name AS required_eligibility,
    se.verification_status,
    se.expiry_date
FROM application ap
JOIN student s ON s.student_id = ap.student_id
JOIN resource_offering ro ON ro.offering_id = ap.offering_id
LEFT JOIN eligibility_type et
       ON et.eligibility_type_id = ro.required_eligibility_type_id
LEFT JOIN student_eligibility se
       ON se.student_id = s.student_id
      AND se.eligibility_type_id = et.eligibility_type_id
ORDER BY student, ro.resource_name;

-- Validate primary, unique, foreign-key and check constraints exist.
SELECT
    tc.table_name,
    tc.constraint_type,
    tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'remote_education'
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

