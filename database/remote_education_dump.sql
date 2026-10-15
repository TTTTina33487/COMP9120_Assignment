--
-- PostgreSQL database dump
--

\restrict vcNDH01Ff8pMUVOheDn2O4qbClKMclQC0hxawSgBFg45LjTCFPW9ImGYjNeb4mZ

-- Dumped from database version 18.6 (Homebrew)
-- Dumped by pg_dump version 18.6 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: remote_education; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA remote_education;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: allocation; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.allocation (
    allocation_id bigint NOT NULL,
    application_id bigint NOT NULL,
    allocation_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    quantity_allocated integer NOT NULL,
    allocation_status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    CONSTRAINT allocation_quantity_ck CHECK ((quantity_allocated > 0)),
    CONSTRAINT allocation_status_ck CHECK (((allocation_status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'returned'::character varying])::text[])))
);


--
-- Name: allocation_allocation_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.allocation ALTER COLUMN allocation_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.allocation_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: application; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.application (
    application_id bigint NOT NULL,
    student_id bigint NOT NULL,
    offering_id bigint NOT NULL,
    reviewer_id bigint,
    application_date date DEFAULT CURRENT_DATE NOT NULL,
    requested_quantity integer NOT NULL,
    learning_goal text NOT NULL,
    priority_level character varying(20) DEFAULT 'medium'::character varying NOT NULL,
    decision_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    decision_date timestamp with time zone,
    decision_reason text,
    CONSTRAINT application_decision_state_ck CHECK (((((decision_status)::text = 'pending'::text) AND (reviewer_id IS NULL) AND (decision_date IS NULL)) OR (((decision_status)::text = 'under_review'::text) AND (reviewer_id IS NOT NULL) AND (decision_date IS NULL)) OR (((decision_status)::text = ANY ((ARRAY['approved'::character varying, 'rejected'::character varying])::text[])) AND (reviewer_id IS NOT NULL) AND (decision_date IS NOT NULL)) OR (((decision_status)::text = 'withdrawn'::text) AND (decision_date IS NOT NULL)))),
    CONSTRAINT application_decision_status_ck CHECK (((decision_status)::text = ANY ((ARRAY['pending'::character varying, 'under_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'withdrawn'::character varying])::text[]))),
    CONSTRAINT application_priority_ck CHECK (((priority_level)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'urgent'::character varying])::text[]))),
    CONSTRAINT application_rejection_reason_ck CHECK ((((decision_status)::text <> 'rejected'::text) OR (decision_reason IS NOT NULL))),
    CONSTRAINT application_requested_quantity_ck CHECK ((requested_quantity > 0))
);


--
-- Name: application_application_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.application ALTER COLUMN application_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.application_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: coordinator; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.coordinator (
    coordinator_id bigint NOT NULL,
    school_id bigint NOT NULL,
    coordinator_name character varying(150) NOT NULL,
    role character varying(80) NOT NULL
);


--
-- Name: coordinator_coordinator_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.coordinator ALTER COLUMN coordinator_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.coordinator_coordinator_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: eligibility_type; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.eligibility_type (
    eligibility_type_id bigint NOT NULL,
    type_name character varying(100) NOT NULL,
    description text NOT NULL
);


--
-- Name: eligibility_type_eligibility_type_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.eligibility_type ALTER COLUMN eligibility_type_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.eligibility_type_eligibility_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: funder; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.funder (
    organisation_id bigint NOT NULL
);


--
-- Name: organisation; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.organisation (
    organisation_id bigint NOT NULL,
    organisation_name character varying(200) NOT NULL,
    contact_email character varying(254) NOT NULL,
    CONSTRAINT organisation_email_ck CHECK (((contact_email)::text ~~ '%_@_%._%'::text))
);


--
-- Name: organisation_organisation_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.organisation ALTER COLUMN organisation_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.organisation_organisation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: provider; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.provider (
    organisation_id bigint NOT NULL
);


--
-- Name: region; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.region (
    region_id bigint NOT NULL,
    region_name character varying(150) NOT NULL,
    remoteness_level character varying(30) NOT NULL,
    internet_access_level character varying(30) NOT NULL,
    support_priority_level character varying(20) NOT NULL,
    CONSTRAINT region_internet_access_ck CHECK (((internet_access_level)::text = ANY ((ARRAY['none'::character varying, 'very_low'::character varying, 'low'::character varying, 'medium'::character varying, 'high'::character varying])::text[]))),
    CONSTRAINT region_remoteness_ck CHECK (((remoteness_level)::text = ANY ((ARRAY['metropolitan'::character varying, 'regional'::character varying, 'remote'::character varying, 'very_remote'::character varying])::text[]))),
    CONSTRAINT region_support_priority_ck CHECK (((support_priority_level)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying])::text[])))
);


--
-- Name: region_region_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.region ALTER COLUMN region_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.region_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: resource_funding; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.resource_funding (
    offering_id bigint NOT NULL,
    funder_id bigint NOT NULL
);


--
-- Name: resource_offering; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.resource_offering (
    offering_id bigint NOT NULL,
    provider_id bigint NOT NULL,
    required_eligibility_type_id bigint,
    resource_name character varying(200) NOT NULL,
    resource_type character varying(80) NOT NULL,
    subject_area character varying(100) NOT NULL,
    total_quantity integer NOT NULL,
    expiry_date date NOT NULL,
    CONSTRAINT resource_offering_quantity_ck CHECK ((total_quantity > 0))
);


--
-- Name: resource_offering_offering_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.resource_offering ALTER COLUMN offering_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.resource_offering_offering_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: school; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.school (
    school_id bigint NOT NULL,
    region_id bigint NOT NULL,
    school_name character varying(200) NOT NULL,
    school_type character varying(50) NOT NULL
);


--
-- Name: school_school_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.school ALTER COLUMN school_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.school_school_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: student; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.student (
    student_id bigint NOT NULL,
    school_id bigint NOT NULL,
    first_name character varying(80) NOT NULL,
    last_name character varying(80) NOT NULL,
    year_level smallint NOT NULL,
    has_device boolean DEFAULT false NOT NULL,
    internet_access_level character varying(30) NOT NULL,
    CONSTRAINT student_internet_access_ck CHECK (((internet_access_level)::text = ANY ((ARRAY['none'::character varying, 'very_low'::character varying, 'low'::character varying, 'medium'::character varying, 'high'::character varying])::text[]))),
    CONSTRAINT student_year_level_ck CHECK (((year_level >= 1) AND (year_level <= 13)))
);


--
-- Name: student_eligibility; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.student_eligibility (
    student_id bigint NOT NULL,
    eligibility_type_id bigint NOT NULL,
    verified_date date,
    expiry_date date,
    verification_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    CONSTRAINT student_eligibility_dates_ck CHECK (((expiry_date IS NULL) OR ((verified_date IS NOT NULL) AND (expiry_date >= verified_date)))),
    CONSTRAINT student_eligibility_status_ck CHECK (((verification_status)::text = ANY ((ARRAY['pending'::character varying, 'verified'::character varying, 'rejected'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT student_eligibility_verified_date_ck CHECK ((((verification_status)::text <> 'verified'::text) OR (verified_date IS NOT NULL)))
);


--
-- Name: student_student_id_seq; Type: SEQUENCE; Schema: remote_education; Owner: -
--

ALTER TABLE remote_education.student ALTER COLUMN student_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME remote_education.student_student_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usage_record; Type: TABLE; Schema: remote_education; Owner: -
--

CREATE TABLE remote_education.usage_record (
    allocation_id bigint NOT NULL,
    record_no integer NOT NULL,
    record_date date DEFAULT CURRENT_DATE NOT NULL,
    usage_type character varying(80) NOT NULL,
    usage_status character varying(30) NOT NULL,
    notes text,
    CONSTRAINT usage_record_no_ck CHECK ((record_no > 0)),
    CONSTRAINT usage_record_status_ck CHECK (((usage_status)::text = ANY ((ARRAY['scheduled'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'missed'::character varying, 'returned'::character varying])::text[])))
);


--
-- Name: v_application_fulfilment; Type: VIEW; Schema: remote_education; Owner: -
--

CREATE VIEW remote_education.v_application_fulfilment AS
 SELECT ap.application_id,
    ap.student_id,
    ap.offering_id,
    ap.requested_quantity,
    (COALESCE(sum(al.quantity_allocated) FILTER (WHERE ((al.allocation_status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying])::text[]))), (0)::bigint))::integer AS allocated_quantity,
    (ap.requested_quantity - (COALESCE(sum(al.quantity_allocated) FILTER (WHERE ((al.allocation_status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying])::text[]))), (0)::bigint))::integer) AS quantity_still_requested
   FROM (remote_education.application ap
     LEFT JOIN remote_education.allocation al ON ((al.application_id = ap.application_id)))
  GROUP BY ap.application_id, ap.student_id, ap.offering_id, ap.requested_quantity;


--
-- Name: v_offering_capacity; Type: VIEW; Schema: remote_education; Owner: -
--

CREATE VIEW remote_education.v_offering_capacity AS
 SELECT ro.offering_id,
    ro.resource_name,
    ro.total_quantity,
    (COALESCE(sum(al.quantity_allocated) FILTER (WHERE ((al.allocation_status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying])::text[]))), (0)::bigint))::integer AS allocated_quantity,
    (ro.total_quantity - (COALESCE(sum(al.quantity_allocated) FILTER (WHERE ((al.allocation_status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying])::text[]))), (0)::bigint))::integer) AS remaining_quantity
   FROM ((remote_education.resource_offering ro
     LEFT JOIN remote_education.application ap ON ((ap.offering_id = ro.offering_id)))
     LEFT JOIN remote_education.allocation al ON ((al.application_id = ap.application_id)))
  GROUP BY ro.offering_id, ro.resource_name, ro.total_quantity;


--
-- Data for Name: allocation; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.allocation (allocation_id, application_id, allocation_date, quantity_allocated, allocation_status) FROM stdin;
1	1	2026-09-22 09:00:00+10	1	completed
2	2	2026-09-24 09:00:00+10	1	active
3	2	2026-10-01 09:00:00+10	1	active
4	3	2026-09-26 09:00:00+10	1	active
5	5	2026-09-30 09:00:00+10	1	active
6	8	2026-10-08 09:00:00+11	1	active
7	8	2026-10-12 09:00:00+11	1	active
8	9	2026-10-10 09:00:00+11	1	active
9	10	2026-10-12 10:00:00+11	2	active
\.


--
-- Data for Name: application; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.application (application_id, student_id, offering_id, reviewer_id, application_date, requested_quantity, learning_goal, priority_level, decision_status, decision_date, decision_reason) FROM stdin;
1	1	3	1	2026-09-20	1	Gain reliable access to online learning activities.	high	approved	2026-09-21 10:00:00+10	Verified device access need.
2	2	1	1	2026-09-22	2	Prepare for Year 10 mathematics assessment.	high	approved	2026-09-23 11:00:00+10	Remote-area eligibility verified.
3	3	4	2	2026-09-24	2	Improve connectivity for weekly course participation.	urgent	approved	2026-09-25 09:30:00+10	Limited internet access verified.
4	4	2	2	2026-09-26	3	Receive additional mathematics tutoring.	medium	rejected	2026-09-27 14:00:00+10	Required eligibility is still pending.
5	5	7	3	2026-09-28	1	Join a culturally relevant STEM mentoring programme.	high	approved	2026-09-29 13:00:00+10	Programme eligibility verified.
6	6	5	3	2026-10-02	1	Complete practical science activities without laboratory access.	high	under_review	\N	\N
7	7	8	\N	2026-10-05	1	Access revision materials for final-year subjects.	medium	pending	\N	\N
8	8	6	4	2026-10-06	2	Improve academic writing and reading confidence.	medium	approved	2026-10-07 10:30:00+11	Offering has no additional eligibility requirement.
9	9	3	5	2026-10-08	1	Obtain a device for homework and video lessons.	urgent	approved	2026-10-09 12:00:00+11	Device access need verified.
10	10	2	5	2026-10-10	4	Receive weekly support for advanced mathematics.	high	approved	2026-10-11 15:00:00+11	Low-income eligibility verified.
\.


--
-- Data for Name: coordinator; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.coordinator (coordinator_id, school_id, coordinator_name, role) FROM stdin;
1	1	Amelia Carter	Student Support Coordinator
2	2	Noah Williams	Learning Access Coordinator
3	3	Olivia Chen	Education Support Coordinator
4	4	Ethan Brown	Student Services Coordinator
5	5	Mia Thompson	Remote Learning Coordinator
\.


--
-- Data for Name: eligibility_type; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.eligibility_type (eligibility_type_id, type_name, description) FROM stdin;
1	Remote Area Resident	Student lives in an eligible remote or very remote region.
2	Low Income Household	Household income meets the programme threshold.
3	Device Access Need	Student does not have reliable access to a suitable learning device.
4	Limited Internet Access	Student has no or very limited internet connectivity.
5	First Nations Education Support	Student is eligible for the targeted First Nations education programme.
\.


--
-- Data for Name: funder; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.funder (organisation_id) FROM stdin;
2
3
4
6
\.


--
-- Data for Name: organisation; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.organisation (organisation_id, organisation_name, contact_email) FROM stdin;
1	Open Learning Australia	resources@openlearning.example
2	Global Education Fund	grants@globaleducation.example
3	Rural Futures Network	programs@ruralfutures.example
4	TechBridge Foundation	support@techbridge.example
5	Community Tutor Alliance	coordination@communitytutors.example
6	BrightStart Trust	funding@brightstart.example
\.


--
-- Data for Name: provider; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.provider (organisation_id) FROM stdin;
1
3
4
5
\.


--
-- Data for Name: region; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.region (region_id, region_name, remoteness_level, internet_access_level, support_priority_level) FROM stdin;
1	Western Plains	remote	low	high
2	Northern Highlands	very_remote	very_low	critical
3	Desert Coast	very_remote	none	critical
4	Riverland	regional	medium	medium
5	Island Communities	remote	low	high
\.


--
-- Data for Name: resource_funding; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.resource_funding (offering_id, funder_id) FROM stdin;
1	2
5	2
3	4
4	4
2	6
6	6
7	2
7	3
\.


--
-- Data for Name: resource_offering; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.resource_offering (offering_id, provider_id, required_eligibility_type_id, resource_name, resource_type, subject_area, total_quantity, expiry_date) FROM stdin;
1	1	1	Offline Mathematics Course Pack	offline_course	Mathematics	40	2027-06-30
2	5	2	Weekly Online Mathematics Tutoring	online_tutoring	Mathematics	25	2027-04-30
3	4	3	Refurbished Learning Device	device	General	30	2027-12-31
4	3	4	Satellite Internet Learning Voucher	connectivity	General	20	2027-09-30
5	1	1	Science Experiment Kit	physical_kit	Science	35	2027-08-31
6	5	\N	English Literacy Mentoring	online_tutoring	English	30	2027-05-31
7	3	5	First Nations STEM Mentoring	blended_mentoring	Science	18	2027-10-31
8	1	\N	Downloadable Year 10 Study Library	digital_library	General	100	2027-12-31
\.


--
-- Data for Name: school; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.school (school_id, region_id, school_name, school_type) FROM stdin;
1	1	Mallee Remote College	combined
2	2	Outback Community School	combined
3	3	Cape York Learning Centre	secondary
4	4	Riverland District High	secondary
5	5	Island Community College	combined
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.student (student_id, school_id, first_name, last_name, year_level, has_device, internet_access_level) FROM stdin;
1	1	Ava	Mitchell	8	f	low
2	1	Liam	Nguyen	10	t	low
3	2	Sophie	Johnson	7	t	very_low
4	2	Noah	Davis	9	f	very_low
5	3	Isla	Wilson	11	t	none
6	3	Jack	Martin	6	f	none
7	4	Mia	Lee	12	t	medium
8	4	Lucas	Taylor	9	t	medium
9	5	Chloe	Anderson	8	f	low
10	5	Ethan	White	10	t	low
\.


--
-- Data for Name: student_eligibility; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.student_eligibility (student_id, eligibility_type_id, verified_date, expiry_date, verification_status) FROM stdin;
1	3	2026-08-01	2027-07-31	verified
1	1	2026-08-01	2027-07-31	verified
2	1	2026-07-20	2027-07-19	verified
3	4	2026-08-15	2027-08-14	verified
3	2	2026-08-15	2027-08-14	verified
4	2	\N	\N	pending
5	5	2026-06-01	2027-05-31	verified
6	1	2026-06-01	2027-05-31	verified
8	2	2026-09-01	2027-08-31	verified
9	3	2026-09-05	2027-09-04	verified
10	2	2026-09-05	2027-09-04	verified
\.


--
-- Data for Name: usage_record; Type: TABLE DATA; Schema: remote_education; Owner: -
--

COPY remote_education.usage_record (allocation_id, record_no, record_date, usage_type, usage_status, notes) FROM stdin;
1	1	2026-09-25	device_delivery	completed	Device delivered to the school.
1	2	2026-10-05	device_setup	completed	Student account and offline materials configured.
2	1	2026-09-28	course_pack_delivery	completed	First course pack collected from school.
3	1	2026-10-04	course_pack_delivery	completed	Second course pack collected from school.
4	1	2026-10-01	voucher_activation	in_progress	First connectivity voucher activated.
5	1	2026-10-06	mentoring_session	completed	Initial STEM mentoring session attended.
6	1	2026-10-10	mentoring_session	completed	First literacy session completed.
7	1	2026-10-14	mentoring_session	scheduled	Second literacy session scheduled.
8	1	2026-10-13	device_delivery	completed	Device delivered through island school office.
9	1	2026-10-15	tutoring_session	scheduled	First two tutoring sessions reserved.
\.


--
-- Name: allocation_allocation_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.allocation_allocation_id_seq', 9, true);


--
-- Name: application_application_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.application_application_id_seq', 11, true);


--
-- Name: coordinator_coordinator_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.coordinator_coordinator_id_seq', 5, true);


--
-- Name: eligibility_type_eligibility_type_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.eligibility_type_eligibility_type_id_seq', 5, true);


--
-- Name: organisation_organisation_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.organisation_organisation_id_seq', 7, true);


--
-- Name: region_region_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.region_region_id_seq', 6, true);


--
-- Name: resource_offering_offering_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.resource_offering_offering_id_seq', 8, true);


--
-- Name: school_school_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.school_school_id_seq', 7, true);


--
-- Name: student_student_id_seq; Type: SEQUENCE SET; Schema: remote_education; Owner: -
--

SELECT pg_catalog.setval('remote_education.student_student_id_seq', 12, true);


--
-- Name: allocation allocation_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.allocation
    ADD CONSTRAINT allocation_pkey PRIMARY KEY (allocation_id);


--
-- Name: application application_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (application_id);


--
-- Name: application application_student_offering_date_uq; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.application
    ADD CONSTRAINT application_student_offering_date_uq UNIQUE (student_id, offering_id, application_date);


--
-- Name: coordinator coordinator_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.coordinator
    ADD CONSTRAINT coordinator_pkey PRIMARY KEY (coordinator_id);


--
-- Name: coordinator coordinator_school_name_uq; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.coordinator
    ADD CONSTRAINT coordinator_school_name_uq UNIQUE (school_id, coordinator_name);


--
-- Name: eligibility_type eligibility_type_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.eligibility_type
    ADD CONSTRAINT eligibility_type_pkey PRIMARY KEY (eligibility_type_id);


--
-- Name: eligibility_type eligibility_type_type_name_key; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.eligibility_type
    ADD CONSTRAINT eligibility_type_type_name_key UNIQUE (type_name);


--
-- Name: funder funder_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.funder
    ADD CONSTRAINT funder_pkey PRIMARY KEY (organisation_id);


--
-- Name: organisation organisation_contact_email_key; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.organisation
    ADD CONSTRAINT organisation_contact_email_key UNIQUE (contact_email);


--
-- Name: organisation organisation_organisation_name_key; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.organisation
    ADD CONSTRAINT organisation_organisation_name_key UNIQUE (organisation_name);


--
-- Name: organisation organisation_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.organisation
    ADD CONSTRAINT organisation_pkey PRIMARY KEY (organisation_id);


--
-- Name: provider provider_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.provider
    ADD CONSTRAINT provider_pkey PRIMARY KEY (organisation_id);


--
-- Name: region region_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.region
    ADD CONSTRAINT region_pkey PRIMARY KEY (region_id);


--
-- Name: region region_region_name_key; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.region
    ADD CONSTRAINT region_region_name_key UNIQUE (region_name);


--
-- Name: resource_funding resource_funding_pk; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_funding
    ADD CONSTRAINT resource_funding_pk PRIMARY KEY (offering_id, funder_id);


--
-- Name: resource_offering resource_offering_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_offering
    ADD CONSTRAINT resource_offering_pkey PRIMARY KEY (offering_id);


--
-- Name: resource_offering resource_offering_provider_name_expiry_uq; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_offering
    ADD CONSTRAINT resource_offering_provider_name_expiry_uq UNIQUE (provider_id, resource_name, expiry_date);


--
-- Name: school school_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.school
    ADD CONSTRAINT school_pkey PRIMARY KEY (school_id);


--
-- Name: school school_region_name_uq; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.school
    ADD CONSTRAINT school_region_name_uq UNIQUE (region_id, school_name);


--
-- Name: student_eligibility student_eligibility_pk; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.student_eligibility
    ADD CONSTRAINT student_eligibility_pk PRIMARY KEY (student_id, eligibility_type_id);


--
-- Name: student student_pkey; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (student_id);


--
-- Name: student student_school_name_uq; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.student
    ADD CONSTRAINT student_school_name_uq UNIQUE (school_id, first_name, last_name);


--
-- Name: usage_record usage_record_pk; Type: CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.usage_record
    ADD CONSTRAINT usage_record_pk PRIMARY KEY (allocation_id, record_no);


--
-- Name: allocation_application_status_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX allocation_application_status_idx ON remote_education.allocation USING btree (application_id, allocation_status);


--
-- Name: application_offering_status_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX application_offering_status_idx ON remote_education.application USING btree (offering_id, decision_status);


--
-- Name: application_reviewer_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX application_reviewer_idx ON remote_education.application USING btree (reviewer_id);


--
-- Name: application_student_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX application_student_idx ON remote_education.application USING btree (student_id);


--
-- Name: coordinator_school_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX coordinator_school_idx ON remote_education.coordinator USING btree (school_id);


--
-- Name: resource_funding_funder_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX resource_funding_funder_idx ON remote_education.resource_funding USING btree (funder_id);


--
-- Name: resource_offering_eligibility_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX resource_offering_eligibility_idx ON remote_education.resource_offering USING btree (required_eligibility_type_id);


--
-- Name: resource_offering_provider_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX resource_offering_provider_idx ON remote_education.resource_offering USING btree (provider_id);


--
-- Name: resource_offering_subject_expiry_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX resource_offering_subject_expiry_idx ON remote_education.resource_offering USING btree (subject_area, expiry_date);


--
-- Name: school_region_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX school_region_idx ON remote_education.school USING btree (region_id);


--
-- Name: student_eligibility_type_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX student_eligibility_type_idx ON remote_education.student_eligibility USING btree (eligibility_type_id);


--
-- Name: student_school_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX student_school_idx ON remote_education.student USING btree (school_id);


--
-- Name: usage_record_status_date_idx; Type: INDEX; Schema: remote_education; Owner: -
--

CREATE INDEX usage_record_status_date_idx ON remote_education.usage_record USING btree (usage_status, record_date);


--
-- Name: allocation allocation_application_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.allocation
    ADD CONSTRAINT allocation_application_fk FOREIGN KEY (application_id) REFERENCES remote_education.application(application_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: application application_offering_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.application
    ADD CONSTRAINT application_offering_fk FOREIGN KEY (offering_id) REFERENCES remote_education.resource_offering(offering_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: application application_reviewer_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.application
    ADD CONSTRAINT application_reviewer_fk FOREIGN KEY (reviewer_id) REFERENCES remote_education.coordinator(coordinator_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: application application_student_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.application
    ADD CONSTRAINT application_student_fk FOREIGN KEY (student_id) REFERENCES remote_education.student(student_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: coordinator coordinator_school_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.coordinator
    ADD CONSTRAINT coordinator_school_fk FOREIGN KEY (school_id) REFERENCES remote_education.school(school_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: funder funder_organisation_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.funder
    ADD CONSTRAINT funder_organisation_fk FOREIGN KEY (organisation_id) REFERENCES remote_education.organisation(organisation_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: provider provider_organisation_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.provider
    ADD CONSTRAINT provider_organisation_fk FOREIGN KEY (organisation_id) REFERENCES remote_education.organisation(organisation_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: resource_funding resource_funding_funder_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_funding
    ADD CONSTRAINT resource_funding_funder_fk FOREIGN KEY (funder_id) REFERENCES remote_education.funder(organisation_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: resource_funding resource_funding_offering_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_funding
    ADD CONSTRAINT resource_funding_offering_fk FOREIGN KEY (offering_id) REFERENCES remote_education.resource_offering(offering_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: resource_offering resource_offering_eligibility_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_offering
    ADD CONSTRAINT resource_offering_eligibility_fk FOREIGN KEY (required_eligibility_type_id) REFERENCES remote_education.eligibility_type(eligibility_type_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: resource_offering resource_offering_provider_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.resource_offering
    ADD CONSTRAINT resource_offering_provider_fk FOREIGN KEY (provider_id) REFERENCES remote_education.provider(organisation_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: school school_region_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.school
    ADD CONSTRAINT school_region_fk FOREIGN KEY (region_id) REFERENCES remote_education.region(region_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: student_eligibility student_eligibility_student_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.student_eligibility
    ADD CONSTRAINT student_eligibility_student_fk FOREIGN KEY (student_id) REFERENCES remote_education.student(student_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: student_eligibility student_eligibility_type_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.student_eligibility
    ADD CONSTRAINT student_eligibility_type_fk FOREIGN KEY (eligibility_type_id) REFERENCES remote_education.eligibility_type(eligibility_type_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: student student_school_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.student
    ADD CONSTRAINT student_school_fk FOREIGN KEY (school_id) REFERENCES remote_education.school(school_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: usage_record usage_record_allocation_fk; Type: FK CONSTRAINT; Schema: remote_education; Owner: -
--

ALTER TABLE ONLY remote_education.usage_record
    ADD CONSTRAINT usage_record_allocation_fk FOREIGN KEY (allocation_id) REFERENCES remote_education.allocation(allocation_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict vcNDH01Ff8pMUVOheDn2O4qbClKMclQC0hxawSgBFg45LjTCFPW9ImGYjNeb4mZ

