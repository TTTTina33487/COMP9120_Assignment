-- Negative tests: each invalid statement must be rejected by PostgreSQL.

SET search_path TO remote_education, public;

DO $$
BEGIN
    BEGIN
        INSERT INTO student
            (school_id, first_name, last_name, year_level,
             has_device, internet_access_level)
        VALUES
            ((SELECT MIN(school_id) FROM school),
             'Invalid', 'YearLevel', 20, FALSE, 'low');
        RAISE EXCEPTION 'year-level CHECK test unexpectedly succeeded';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS: invalid year level rejected';
    END;

    BEGIN
        INSERT INTO school (region_id, school_name, school_type)
        VALUES (-999, 'Invalid FK School', 'combined');
        RAISE EXCEPTION 'foreign-key test unexpectedly succeeded';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'PASS: invalid region foreign key rejected';
    END;

    BEGIN
        INSERT INTO organisation (organisation_name, contact_email)
        VALUES ('Duplicate Email Organisation',
                (SELECT MIN(contact_email) FROM organisation));
        RAISE EXCEPTION 'unique-email test unexpectedly succeeded';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'PASS: duplicate organisation email rejected';
    END;

    BEGIN
        INSERT INTO application
            (student_id, offering_id, application_date,
             requested_quantity, learning_goal, priority_level,
             decision_status)
        VALUES
            ((SELECT MIN(student_id) FROM student),
             (SELECT MIN(offering_id) FROM resource_offering),
             DATE '2026-12-01', 0,
             'Invalid zero-quantity test', 'medium', 'pending');
        RAISE EXCEPTION 'requested-quantity CHECK test unexpectedly succeeded';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS: zero requested quantity rejected';
    END;

    BEGIN
        INSERT INTO usage_record
            (allocation_id, record_no, record_date,
             usage_type, usage_status)
        VALUES
            ((SELECT MIN(allocation_id) FROM allocation),
             0, CURRENT_DATE, 'invalid_test', 'scheduled');
        RAISE EXCEPTION 'weak-entity partial-key test unexpectedly succeeded';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'PASS: invalid usage record number rejected';
    END;
END
$$;

