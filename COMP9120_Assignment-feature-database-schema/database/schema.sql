-- Remote Education Resource Allocation Platform
-- PostgreSQL 18 schema aligned with the revised conceptual ER model.

BEGIN;

CREATE SCHEMA IF NOT EXISTS remote_education;
SET search_path TO remote_education, public;

-- ============================================================
-- Educational context
-- ============================================================

CREATE TABLE region (
    region_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_name            VARCHAR(150) NOT NULL UNIQUE,
    remoteness_level       VARCHAR(30) NOT NULL,
    internet_access_level  VARCHAR(30) NOT NULL,
    support_priority_level VARCHAR(20) NOT NULL,

    CONSTRAINT region_remoteness_ck
        CHECK (remoteness_level IN
               ('metropolitan', 'regional', 'remote', 'very_remote')),
    CONSTRAINT region_internet_access_ck
        CHECK (internet_access_level IN
               ('none', 'very_low', 'low', 'medium', 'high')),
    CONSTRAINT region_support_priority_ck
        CHECK (support_priority_level IN
               ('low', 'medium', 'high', 'critical'))
);

CREATE TABLE school (
    school_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_id   BIGINT NOT NULL,
    school_name VARCHAR(200) NOT NULL,
    school_type VARCHAR(50) NOT NULL,

    CONSTRAINT school_region_fk
        FOREIGN KEY (region_id)
        REFERENCES region (region_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT school_region_name_uq
        UNIQUE (region_id, school_name)
);

CREATE TABLE coordinator (
    coordinator_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    school_id        BIGINT NOT NULL,
    coordinator_name VARCHAR(150) NOT NULL,
    role             VARCHAR(80) NOT NULL,

    CONSTRAINT coordinator_school_fk
        FOREIGN KEY (school_id)
        REFERENCES school (school_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT coordinator_school_name_uq
        UNIQUE (school_id, coordinator_name)
);

CREATE TABLE student (
    student_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    school_id             BIGINT NOT NULL,
    first_name            VARCHAR(80) NOT NULL,
    last_name             VARCHAR(80) NOT NULL,
    year_level            SMALLINT NOT NULL,
    has_device            BOOLEAN NOT NULL DEFAULT FALSE,
    internet_access_level VARCHAR(30) NOT NULL,

    CONSTRAINT student_school_fk
        FOREIGN KEY (school_id)
        REFERENCES school (school_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT student_year_level_ck
        CHECK (year_level BETWEEN 1 AND 13),
    CONSTRAINT student_internet_access_ck
        CHECK (internet_access_level IN
               ('none', 'very_low', 'low', 'medium', 'high')),
    CONSTRAINT student_school_name_uq
        UNIQUE (school_id, first_name, last_name)
);

-- ============================================================
-- Eligibility: ELIGIBILITY_TYPE and the M:N HOLDS relationship
-- ============================================================

CREATE TABLE eligibility_type (
    eligibility_type_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name           VARCHAR(100) NOT NULL UNIQUE,
    description         TEXT NOT NULL
);

CREATE TABLE student_eligibility (
    student_id          BIGINT NOT NULL,
    eligibility_type_id BIGINT NOT NULL,
    verified_date       DATE,
    expiry_date         DATE,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'pending',

    CONSTRAINT student_eligibility_pk
        PRIMARY KEY (student_id, eligibility_type_id),
    CONSTRAINT student_eligibility_student_fk
        FOREIGN KEY (student_id)
        REFERENCES student (student_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT student_eligibility_type_fk
        FOREIGN KEY (eligibility_type_id)
        REFERENCES eligibility_type (eligibility_type_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT student_eligibility_status_ck
        CHECK (verification_status IN
               ('pending', 'verified', 'rejected', 'expired')),
    CONSTRAINT student_eligibility_verified_date_ck
        CHECK (verification_status <> 'verified' OR verified_date IS NOT NULL),
    CONSTRAINT student_eligibility_dates_ck
        CHECK (expiry_date IS NULL
               OR (verified_date IS NOT NULL AND expiry_date >= verified_date))
);

-- ============================================================
-- Organisation ISA hierarchy and resource supply
-- PROVIDER and FUNDER are overlapping, partial subtypes.
-- ============================================================

CREATE TABLE organisation (
    organisation_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    organisation_name VARCHAR(200) NOT NULL UNIQUE,
    contact_email     VARCHAR(254) NOT NULL UNIQUE,

    CONSTRAINT organisation_email_ck
        CHECK (contact_email LIKE '%_@_%._%')
);

CREATE TABLE provider (
    organisation_id BIGINT PRIMARY KEY,

    CONSTRAINT provider_organisation_fk
        FOREIGN KEY (organisation_id)
        REFERENCES organisation (organisation_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE funder (
    organisation_id BIGINT PRIMARY KEY,

    CONSTRAINT funder_organisation_fk
        FOREIGN KEY (organisation_id)
        REFERENCES organisation (organisation_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE resource_offering (
    offering_id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider_id                 BIGINT NOT NULL,
    required_eligibility_type_id BIGINT,
    resource_name               VARCHAR(200) NOT NULL,
    resource_type               VARCHAR(80) NOT NULL,
    subject_area                VARCHAR(100) NOT NULL,
    total_quantity              INTEGER NOT NULL,
    expiry_date                 DATE NOT NULL,

    CONSTRAINT resource_offering_provider_fk
        FOREIGN KEY (provider_id)
        REFERENCES provider (organisation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT resource_offering_eligibility_fk
        FOREIGN KEY (required_eligibility_type_id)
        REFERENCES eligibility_type (eligibility_type_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT resource_offering_quantity_ck
        CHECK (total_quantity > 0),
    CONSTRAINT resource_offering_provider_name_expiry_uq
        UNIQUE (provider_id, resource_name, expiry_date)
);

-- M:N FUNDS relationship. One organisation may also be a provider.
CREATE TABLE resource_funding (
    offering_id BIGINT NOT NULL,
    funder_id   BIGINT NOT NULL,

    CONSTRAINT resource_funding_pk
        PRIMARY KEY (offering_id, funder_id),
    CONSTRAINT resource_funding_offering_fk
        FOREIGN KEY (offering_id)
        REFERENCES resource_offering (offering_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT resource_funding_funder_fk
        FOREIGN KEY (funder_id)
        REFERENCES funder (organisation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- ============================================================
-- Applications, optional single review, partial allocations
-- ============================================================

CREATE TABLE application (
    application_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id         BIGINT NOT NULL,
    offering_id        BIGINT NOT NULL,
    reviewer_id        BIGINT,
    application_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    requested_quantity INTEGER NOT NULL,
    learning_goal      TEXT NOT NULL,
    priority_level     VARCHAR(20) NOT NULL DEFAULT 'medium',
    decision_status    VARCHAR(20) NOT NULL DEFAULT 'pending',
    decision_date      TIMESTAMPTZ,
    decision_reason    TEXT,

    CONSTRAINT application_student_fk
        FOREIGN KEY (student_id)
        REFERENCES student (student_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT application_offering_fk
        FOREIGN KEY (offering_id)
        REFERENCES resource_offering (offering_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT application_reviewer_fk
        FOREIGN KEY (reviewer_id)
        REFERENCES coordinator (coordinator_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT application_requested_quantity_ck
        CHECK (requested_quantity > 0),
    CONSTRAINT application_priority_ck
        CHECK (priority_level IN ('low', 'medium', 'high', 'urgent')),
    CONSTRAINT application_decision_status_ck
        CHECK (decision_status IN
               ('pending', 'under_review', 'approved', 'rejected', 'withdrawn')),
    CONSTRAINT application_decision_state_ck
        CHECK (
            (decision_status = 'pending'
             AND reviewer_id IS NULL AND decision_date IS NULL)
         OR (decision_status = 'under_review'
             AND reviewer_id IS NOT NULL AND decision_date IS NULL)
         OR (decision_status IN ('approved', 'rejected')
             AND reviewer_id IS NOT NULL AND decision_date IS NOT NULL)
         OR (decision_status = 'withdrawn'
             AND decision_date IS NOT NULL)
        ),
    CONSTRAINT application_rejection_reason_ck
        CHECK (decision_status <> 'rejected' OR decision_reason IS NOT NULL),
    CONSTRAINT application_student_offering_date_uq
        UNIQUE (student_id, offering_id, application_date)
);

CREATE TABLE allocation (
    allocation_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    application_id    BIGINT NOT NULL,
    allocation_date   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    quantity_allocated INTEGER NOT NULL,
    allocation_status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT allocation_application_fk
        FOREIGN KEY (application_id)
        REFERENCES application (application_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT allocation_quantity_ck
        CHECK (quantity_allocated > 0),
    CONSTRAINT allocation_status_ck
        CHECK (allocation_status IN
               ('active', 'completed', 'cancelled', 'returned'))
);

-- Weak entity identified by owner allocation_id and partial key record_no.
CREATE TABLE usage_record (
    allocation_id BIGINT NOT NULL,
    record_no     INTEGER NOT NULL,
    record_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    usage_type    VARCHAR(80) NOT NULL,
    usage_status  VARCHAR(30) NOT NULL,
    notes         TEXT,

    CONSTRAINT usage_record_pk
        PRIMARY KEY (allocation_id, record_no),
    CONSTRAINT usage_record_allocation_fk
        FOREIGN KEY (allocation_id)
        REFERENCES allocation (allocation_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT usage_record_no_ck
        CHECK (record_no > 0),
    CONSTRAINT usage_record_status_ck
        CHECK (usage_status IN
               ('scheduled', 'in_progress', 'completed', 'missed', 'returned'))
);

-- ============================================================
-- Indexes for FK joins and common operational searches
-- ============================================================

CREATE INDEX school_region_idx
    ON school (region_id);
CREATE INDEX coordinator_school_idx
    ON coordinator (school_id);
CREATE INDEX student_school_idx
    ON student (school_id);
CREATE INDEX student_eligibility_type_idx
    ON student_eligibility (eligibility_type_id);
CREATE INDEX resource_offering_provider_idx
    ON resource_offering (provider_id);
CREATE INDEX resource_offering_eligibility_idx
    ON resource_offering (required_eligibility_type_id);
CREATE INDEX resource_offering_subject_expiry_idx
    ON resource_offering (subject_area, expiry_date);
CREATE INDEX resource_funding_funder_idx
    ON resource_funding (funder_id);
CREATE INDEX application_student_idx
    ON application (student_id);
CREATE INDEX application_offering_status_idx
    ON application (offering_id, decision_status);
CREATE INDEX application_reviewer_idx
    ON application (reviewer_id);
CREATE INDEX allocation_application_status_idx
    ON allocation (application_id, allocation_status);
CREATE INDEX usage_record_status_date_idx
    ON usage_record (usage_status, record_date);

-- ============================================================
-- Views used by queries and by the allocation transaction layer
-- ============================================================

CREATE VIEW v_offering_capacity AS
SELECT
    ro.offering_id,
    ro.resource_name,
    ro.total_quantity,
    COALESCE(SUM(al.quantity_allocated)
             FILTER (WHERE al.allocation_status IN ('active', 'completed')), 0)::INTEGER
        AS allocated_quantity,
    ro.total_quantity
      - COALESCE(SUM(al.quantity_allocated)
                 FILTER (WHERE al.allocation_status IN ('active', 'completed')), 0)::INTEGER
        AS remaining_quantity
FROM resource_offering AS ro
LEFT JOIN application AS ap
       ON ap.offering_id = ro.offering_id
LEFT JOIN allocation AS al
       ON al.application_id = ap.application_id
GROUP BY ro.offering_id, ro.resource_name, ro.total_quantity;

CREATE VIEW v_application_fulfilment AS
SELECT
    ap.application_id,
    ap.student_id,
    ap.offering_id,
    ap.requested_quantity,
    COALESCE(SUM(al.quantity_allocated)
             FILTER (WHERE al.allocation_status IN ('active', 'completed')), 0)::INTEGER
        AS allocated_quantity,
    ap.requested_quantity
      - COALESCE(SUM(al.quantity_allocated)
                 FILTER (WHERE al.allocation_status IN ('active', 'completed')), 0)::INTEGER
        AS quantity_still_requested
FROM application AS ap
LEFT JOIN allocation AS al
       ON al.application_id = ap.application_id
GROUP BY ap.application_id, ap.student_id, ap.offering_id, ap.requested_quantity;

COMMIT;

-- The following aggregate rules intentionally belong to the transaction layer:
-- 1. total allocation per application <= application.requested_quantity;
-- 2. total allocation per offering <= resource_offering.total_quantity.
-- They cannot be expressed as ordinary row-level CHECK constraints. The service
-- transaction must lock the relevant application and offering rows, validate
-- both views/aggregates, insert the allocation, and roll back on any failure.
