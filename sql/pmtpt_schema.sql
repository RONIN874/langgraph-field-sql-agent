-- =============================================================================
-- PMTPT INDIA 2021 — DATABASE SCHEMA & SEED DATA
-- Derived from: Guidelines for Programmatic Management of TB Preventive
-- Treatment in India, 2021 (Ministry of Health & Family Welfare, GoI / WHO)
-- =============================================================================

-- ─────────────────────────────────────────────
-- SECTION 0 — DROP EXISTING OBJECTS
-- Tables are dropped in reverse-dependency order
-- (children first, parents last) so FK constraints
-- are never violated. CASCADE is omitted on purpose
-- to make any missed dependency an explicit error.
-- ─────────────────────────────────────────────

-- 0.1  Drop views first (they depend on tables)
DROP VIEW IF EXISTS v_drug_interactions_summary;
DROP VIEW IF EXISTS v_tpt_cascade_district;
DROP VIEW IF EXISTS v_active_tpt_enrolments;

-- 0.2  Drop tables — leaf / most-dependent tables first
DROP TABLE IF EXISTS indicator_reports;
DROP TABLE IF EXISTS monitoring_indicators;
DROP TABLE IF EXISTS drug_stock;
DROP TABLE IF EXISTS supply_chain_levels;
DROP TABLE IF EXISTS treatment_interruptions;
DROP TABLE IF EXISTS adverse_event_reports;
DROP TABLE IF EXISTS followup_visits;
DROP TABLE IF EXISTS tpt_dose_records;
DROP TABLE IF EXISTS tpt_enrolments;
DROP TABLE IF EXISTS tpt_eligibility_assessments;
DROP TABLE IF EXISTS tbi_test_results;
DROP TABLE IF EXISTS tb_screenings;
DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS index_tb_patients;
DROP TABLE IF EXISTS persons;
DROP TABLE IF EXISTS treatment_outcome_types;
DROP TABLE IF EXISTS drug_interactions;
DROP TABLE IF EXISTS adverse_events_catalogue;
DROP TABLE IF EXISTS risk_groups;
DROP TABLE IF EXISTS tbi_tests;
DROP TABLE IF EXISTS drug_formulations;
DROP TABLE IF EXISTS tpt_regimens;
DROP TABLE IF EXISTS health_facilities;
DROP TABLE IF EXISTS tb_units;
DROP TABLE IF EXISTS districts;
DROP TABLE IF EXISTS states;

-- ─────────────────────────────────────────────
-- SECTION 1 — REFERENCE / LOOKUP TABLES
-- ─────────────────────────────────────────────

-- 1.1  States & UTs of India (administrative geography)
CREATE TABLE states (
    state_id       SERIAL        PRIMARY KEY,
    state_code     VARCHAR(3)    UNIQUE NOT NULL,
    state_name     VARCHAR(100)  NOT NULL,
    region         VARCHAR(50),
    created_at     TIMESTAMPTZ   DEFAULT NOW()
);

-- 1.2  Districts
CREATE TABLE districts (
    district_id    SERIAL        PRIMARY KEY,
    state_id       INT           NOT NULL REFERENCES states(state_id),
    district_code  VARCHAR(10)   UNIQUE NOT NULL,
    district_name  VARCHAR(100)  NOT NULL,
    created_at     TIMESTAMPTZ   DEFAULT NOW()
);

-- 1.3  TB Units (TU) — intermediate administrative unit
CREATE TABLE tb_units (
    tu_id          SERIAL        PRIMARY KEY,
    district_id    INT           NOT NULL REFERENCES districts(district_id),
    tu_code        VARCHAR(20)   UNIQUE NOT NULL,
    tu_name        VARCHAR(150)  NOT NULL,
    created_at     TIMESTAMPTZ   DEFAULT NOW()
);

-- 1.4  Health Facilities (HF) — including HWC, PHC, CHC, ART, private
CREATE TABLE health_facilities (
    hf_id              SERIAL        PRIMARY KEY,
    tu_id              INT           REFERENCES tb_units(tu_id),
    district_id        INT           NOT NULL REFERENCES districts(district_id),
    nikshay_hf_code    VARCHAR(30)   UNIQUE,
    facility_name      VARCHAR(200)  NOT NULL,
    facility_type      VARCHAR(50)   NOT NULL
        CHECK (facility_type IN (
            'HWC','Sub-Centre','PHC','UPHC','CHC','District Hospital',
            'Medical College','ART Centre','Link ART Centre',
            'DR-TB Centre','Private Clinic','ICTC','Corporate Hospital',
            'Dialysis Centre','Cancer Facility'
        )),
    sector             VARCHAR(10)   NOT NULL DEFAULT 'Public'
        CHECK (sector IN ('Public','Private','NGO')),
    address            TEXT,
    phone              VARCHAR(15),
    is_tbi_testing     BOOLEAN       DEFAULT FALSE,
    is_igra_available  BOOLEAN       DEFAULT FALSE,
    is_xray_available  BOOLEAN       DEFAULT FALSE,
    is_active          BOOLEAN       DEFAULT TRUE,
    created_at         TIMESTAMPTZ   DEFAULT NOW()
);

-- 1.5  TPT Regimens (per NTEP guidelines Chapter 5 & 8)
CREATE TABLE tpt_regimens (
    regimen_id          SERIAL        PRIMARY KEY,
    regimen_code        VARCHAR(10)   UNIQUE NOT NULL,
    regimen_name        VARCHAR(100)  NOT NULL,
    drugs               VARCHAR(200)  NOT NULL,        -- e.g. "Isoniazid + Rifapentine"
    duration_months     SMALLINT      NOT NULL,
    dose_frequency      VARCHAR(20)   NOT NULL,        -- 'Daily' | 'Weekly'
    total_doses         SMALLINT      NOT NULL,
    completion_threshold_pct NUMERIC(5,2) NOT NULL,   -- 80% or 90%
    extended_duration_days  SMALLINT  NOT NULL,        -- 133% of planned duration
    indication          TEXT,                          -- which target population
    contraindications   TEXT,
    notes               TEXT
);

-- 1.6  Drug Formulations (dose by weight/age band per Table 5.1)
CREATE TABLE drug_formulations (
    formulation_id    SERIAL        PRIMARY KEY,
    regimen_id        INT           NOT NULL REFERENCES tpt_regimens(regimen_id),
    age_group         VARCHAR(40)   NOT NULL,    -- 'Adult (>14yrs)' | 'Child (2-14yrs)'
    weight_band_min_kg NUMERIC(5,1),
    weight_band_max_kg NUMERIC(5,1),
    drug_name         VARCHAR(80)   NOT NULL,
    dose_mg           NUMERIC(8,2)  NOT NULL,
    formulation_mg    NUMERIC(8,2)  NOT NULL,    -- tablet strength
    tablets_per_dose  NUMERIC(5,2)  NOT NULL
);

-- 1.7  TBI Diagnostic Tests
CREATE TABLE tbi_tests (
    test_id         SERIAL        PRIMARY KEY,
    test_code       VARCHAR(10)   UNIQUE NOT NULL,
    test_name       VARCHAR(100)  NOT NULL,
    test_type       VARCHAR(10)   NOT NULL CHECK (test_type IN ('TST','IGRA')),
    positive_cutoff VARCHAR(100),
    specificity     VARCHAR(50),
    sensitivity     VARCHAR(50),
    requires_lab    BOOLEAN       DEFAULT FALSE,
    cost_category   VARCHAR(10)   CHECK (cost_category IN ('Low','High')),
    notes           TEXT
);

-- 1.8  Risk Groups / Target Populations (Chapter 2)
CREATE TABLE risk_groups (
    group_id       SERIAL        PRIMARY KEY,
    group_code     VARCHAR(20)   UNIQUE NOT NULL,
    group_name     VARCHAR(150)  NOT NULL,
    tpt_strategy   VARCHAR(200)  NOT NULL,     -- "TPT to all after ruling out" vs "TPT if TBI positive"
    tbi_test_required BOOLEAN    DEFAULT FALSE,
    priority_level  SMALLINT     DEFAULT 1,    -- 1=highest
    description    TEXT
);

-- 1.9  Adverse Event Catalogue (Table 6.1)
CREATE TABLE adverse_events_catalogue (
    ae_id          SERIAL        PRIMARY KEY,
    drug           VARCHAR(50)   NOT NULL,
    event_name     VARCHAR(150)  NOT NULL,
    severity_class VARCHAR(20)   NOT NULL CHECK (severity_class IN ('Known','Rare','Serious')),
    management_action TEXT,
    stop_tpt       BOOLEAN       DEFAULT FALSE
);

-- 1.10  Drug-Drug Interactions (Table 6.3)
CREATE TABLE drug_interactions (
    interaction_id    SERIAL       PRIMARY KEY,
    tpt_drug          VARCHAR(50)  NOT NULL,   -- Isoniazid | Rifamycin
    drug_class        VARCHAR(100) NOT NULL,
    interacting_drugs VARCHAR(200) NOT NULL,
    effect            VARCHAR(20)  NOT NULL    -- 'Increases' | 'Decreases'
        CHECK (effect IN ('Increases','Decreases')),
    clinical_note     TEXT
);

-- 1.11  Treatment Outcomes (Chapter 9)
CREATE TABLE treatment_outcome_types (
    outcome_id     SERIAL        PRIMARY KEY,
    outcome_code   VARCHAR(30)   UNIQUE NOT NULL,
    outcome_name   VARCHAR(100)  NOT NULL,
    description    TEXT
);

-- ─────────────────────────────────────────────
-- SECTION 2 — PERSONS & PATIENTS
-- ─────────────────────────────────────────────

-- 2.1  Persons (anyone in the system — index patients, contacts, HRGs)
CREATE TABLE persons (
    person_id          SERIAL        PRIMARY KEY,
    nikshay_id         VARCHAR(30)   UNIQUE,          -- Nikshay UIC
    first_name         VARCHAR(80)   NOT NULL,
    last_name          VARCHAR(80),
    date_of_birth      DATE,
    age_years          SMALLINT,                       -- if DOB not available
    sex                VARCHAR(10)   NOT NULL CHECK (sex IN ('Male','Female','Other')),
    district_id        INT           REFERENCES districts(district_id),
    address_line       TEXT,
    phone              VARCHAR(15),
    aadhar_last4       VARCHAR(4),
    hiv_status         VARCHAR(20)   CHECK (hiv_status IN ('Positive','Negative','Unknown')),
    on_art             BOOLEAN,
    art_regimen        VARCHAR(80),
    has_diabetes       BOOLEAN       DEFAULT FALSE,
    has_silicosis      BOOLEAN       DEFAULT FALSE,
    on_immunosuppressant BOOLEAN     DEFAULT FALSE,
    on_dialysis        BOOLEAN       DEFAULT FALSE,
    preparing_transplant BOOLEAN     DEFAULT FALSE,
    on_anti_tnf        BOOLEAN       DEFAULT FALSE,
    is_pregnant        BOOLEAN       DEFAULT FALSE,
    is_breastfeeding   BOOLEAN       DEFAULT FALSE,
    pwud               BOOLEAN       DEFAULT FALSE,    -- people who use drugs
    registered_at      INT           REFERENCES health_facilities(hf_id),
    registered_on      DATE          DEFAULT CURRENT_DATE,
    created_at         TIMESTAMPTZ   DEFAULT NOW(),
    updated_at         TIMESTAMPTZ   DEFAULT NOW()
);

-- 2.2  Index TB Patients (pulmonary TB cases that trigger contact tracing)
CREATE TABLE index_tb_patients (
    index_patient_id     SERIAL        PRIMARY KEY,
    person_id            INT           NOT NULL UNIQUE REFERENCES persons(person_id),
    nikshay_patient_id   VARCHAR(30)   UNIQUE,
    notification_date    DATE          NOT NULL,
    notification_source  VARCHAR(20)   NOT NULL CHECK (notification_source IN ('Public','Private')),
    hf_id                INT           NOT NULL REFERENCES health_facilities(hf_id),
    tb_type              VARCHAR(50)   NOT NULL
        CHECK (tb_type IN ('Pulmonary-Bacteriologically Confirmed','Pulmonary-Clinically Diagnosed',
                           'DS-TB','MDR-TB','RR-TB','Hr-TB','XDR-TB')),
    bacteriologically_confirmed BOOLEAN DEFAULT FALSE,
    dst_pattern          VARCHAR(200),   -- drug susceptibility pattern
    is_fq_sensitive      BOOLEAN,
    is_h_resistant       BOOLEAN,
    is_r_resistant       BOOLEAN,
    treatment_start_date DATE,
    is_active            BOOLEAN       DEFAULT TRUE,
    notes                TEXT
);

-- 2.3  Contacts (household & close contacts of index TB patients)
CREATE TABLE contacts (
    contact_id           SERIAL        PRIMARY KEY,
    person_id            INT           NOT NULL REFERENCES persons(person_id),
    index_patient_id     INT           NOT NULL REFERENCES index_tb_patients(index_patient_id),
    relationship         VARCHAR(50),   -- Spouse, Child, Parent, Sibling, Co-worker …
    contact_type         VARCHAR(20)   NOT NULL DEFAULT 'Household'
        CHECK (contact_type IN ('Household','Close','Workplace')),
    enumeration_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    enumerated_by_hf     INT           REFERENCES health_facilities(hf_id),
    home_visit_done      BOOLEAN       DEFAULT FALSE,
    tele_call_done       BOOLEAN       DEFAULT FALSE,
    created_at           TIMESTAMPTZ   DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- SECTION 3 — CLINICAL WORKFLOW
-- ─────────────────────────────────────────────

-- 3.1  TB Symptom Screenings
CREATE TABLE tb_screenings (
    screening_id       SERIAL        PRIMARY KEY,
    person_id          INT           NOT NULL REFERENCES persons(person_id),
    hf_id              INT           NOT NULL REFERENCES health_facilities(hf_id),
    screening_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    has_cough          BOOLEAN       DEFAULT FALSE,
    has_fever          BOOLEAN       DEFAULT FALSE,
    has_weight_loss    BOOLEAN       DEFAULT FALSE,
    has_night_sweats   BOOLEAN       DEFAULT FALSE,
    has_haemoptysis    BOOLEAN       DEFAULT FALSE,
    has_chest_pain     BOOLEAN       DEFAULT FALSE,
    has_breathlessness BOOLEAN       DEFAULT FALSE,
    has_fatigue        BOOLEAN       DEFAULT FALSE,
    -- paediatric extras
    has_anorexia       BOOLEAN       DEFAULT FALSE,
    failure_to_thrive  BOOLEAN       DEFAULT FALSE,
    decreased_activity BOOLEAN       DEFAULT FALSE,
    symptom_positive   BOOLEAN       GENERATED ALWAYS AS (
        has_cough OR has_fever OR has_weight_loss OR has_night_sweats OR
        has_haemoptysis OR has_chest_pain OR has_breathlessness OR has_fatigue
    ) STORED,
    cxr_done           BOOLEAN       DEFAULT FALSE,
    cxr_result         VARCHAR(20)   CHECK (cxr_result IN ('Normal','Abnormal','Not Available')),
    outcome            VARCHAR(30)   NOT NULL
        CHECK (outcome IN ('Refer for TB Workup','Eligible for TBI Test','Eligible for TPT','Not Eligible')),
    screened_by        VARCHAR(100),
    notes              TEXT
);

-- 3.2  TBI Test Requests & Results
CREATE TABLE tbi_test_results (
    tbi_result_id     SERIAL        PRIMARY KEY,
    person_id         INT           NOT NULL REFERENCES persons(person_id),
    test_id           INT           NOT NULL REFERENCES tbi_tests(test_id),
    hf_id             INT           NOT NULL REFERENCES health_facilities(hf_id),
    request_date      DATE          NOT NULL DEFAULT CURRENT_DATE,
    test_date         DATE,
    result_date       DATE,
    result            VARCHAR(20)   CHECK (result IN ('Positive','Negative','Indeterminate','Not Available')),
    tst_mm            NUMERIC(5,1),  -- induration in mm for TST
    igra_iu_ml        NUMERIC(8,4),  -- IU/ml for IGRA
    performed_by      VARCHAR(100),
    notes             TEXT
);

-- 3.3  TPT Eligibility Assessments
CREATE TABLE tpt_eligibility_assessments (
    assessment_id       SERIAL        PRIMARY KEY,
    person_id           INT           NOT NULL REFERENCES persons(person_id),
    hf_id               INT           NOT NULL REFERENCES health_facilities(hf_id),
    assessment_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    risk_group_id       INT           REFERENCES risk_groups(group_id),
    active_tb_excluded  BOOLEAN       NOT NULL DEFAULT FALSE,
    tbi_test_result_id  INT           REFERENCES tbi_test_results(tbi_result_id),
    -- contraindications
    has_active_tb       BOOLEAN       DEFAULT FALSE,
    has_acute_hepatitis BOOLEAN       DEFAULT FALSE,
    has_peripheral_neuropathy BOOLEAN DEFAULT FALSE,
    heavy_alcohol_use   BOOLEAN       DEFAULT FALSE,
    known_drug_allergy  BOOLEAN       DEFAULT FALSE,
    concurrent_hepatotoxic_drugs BOOLEAN DEFAULT FALSE,
    -- LFT baseline
    lft_done            BOOLEAN       DEFAULT FALSE,
    alt_ul              NUMERIC(6,1),
    ast_ul              NUMERIC(6,1),
    alt_xULN            NUMERIC(4,2), -- multiple of upper limit of normal
    -- decision
    is_eligible         BOOLEAN,
    reason_ineligible   TEXT,
    recommended_regimen INT           REFERENCES tpt_regimens(regimen_id),
    assessed_by         VARCHAR(100),
    notes               TEXT
);

-- 3.4  TPT Enrolments (treatment initiation)
CREATE TABLE tpt_enrolments (
    enrolment_id          SERIAL        PRIMARY KEY,
    person_id             INT           NOT NULL REFERENCES persons(person_id),
    assessment_id         INT           NOT NULL REFERENCES tpt_eligibility_assessments(assessment_id),
    hf_id                 INT           NOT NULL REFERENCES health_facilities(hf_id),
    regimen_id            INT           NOT NULL REFERENCES tpt_regimens(regimen_id),
    start_date            DATE          NOT NULL,
    planned_end_date      DATE          NOT NULL,
    extended_end_date     DATE          NOT NULL,  -- 133% cutoff
    weight_kg             NUMERIC(5,1),
    pyridoxine_prescribed BOOLEAN       DEFAULT FALSE,
    pyridoxine_dose_mg    SMALLINT,
    treatment_supporter   VARCHAR(150),
    adherence_method      VARCHAR(50)
        CHECK (adherence_method IN ('Direct Observation','99DOTS','MERM','Tele-Video Call',
                                    'Self-Administration','Refill Monitoring')),
    is_post_tb_tpt        BOOLEAN       DEFAULT FALSE,  -- post-treatment TPT for PLHIV
    counselling_done      BOOLEAN       DEFAULT FALSE,
    initiated_by          VARCHAR(100),
    current_status        VARCHAR(30)   NOT NULL DEFAULT 'Active'
        CHECK (current_status IN ('Active','Completed','Failed','Died',
                                   'Lost to Follow-up','Discontinued-Toxicity','Not Evaluated')),
    outcome_id            INT           REFERENCES treatment_outcome_types(outcome_id),
    outcome_date          DATE,
    created_at            TIMESTAMPTZ   DEFAULT NOW(),
    updated_at            TIMESTAMPTZ   DEFAULT NOW()
);

-- 3.5  TPT Dose Tracking (adherence)
CREATE TABLE tpt_dose_records (
    dose_id          SERIAL        PRIMARY KEY,
    enrolment_id     INT           NOT NULL REFERENCES tpt_enrolments(enrolment_id),
    scheduled_date   DATE          NOT NULL,
    taken_date       DATE,
    dose_taken       BOOLEAN       NOT NULL DEFAULT FALSE,
    observed_by      VARCHAR(100),
    method           VARCHAR(30),  -- 99DOTS / Direct / Video / Self-Reported
    notes            TEXT
);

-- 3.6  Follow-up Visits
CREATE TABLE followup_visits (
    visit_id           SERIAL        PRIMARY KEY,
    enrolment_id       INT           NOT NULL REFERENCES tpt_enrolments(enrolment_id),
    visit_date         DATE          NOT NULL DEFAULT CURRENT_DATE,
    visit_type         VARCHAR(30)   NOT NULL
        CHECK (visit_type IN ('Monthly Clinical','LFT Check','Pregnancy Test',
                              'Post-TPT 6M','Post-TPT 12M','Post-TPT 18M','Post-TPT 24M',
                              'Adherence Review','Emergency')),
    weight_kg          NUMERIC(5,1),
    tb_symptoms_present BOOLEAN      DEFAULT FALSE,
    tb_workup_initiated BOOLEAN      DEFAULT FALSE,
    ae_noted           BOOLEAN       DEFAULT FALSE,
    lft_done           BOOLEAN       DEFAULT FALSE,
    alt_ul             NUMERIC(6,1),
    ast_ul             NUMERIC(6,1),
    pregnancy_test_done BOOLEAN      DEFAULT FALSE,
    pregnancy_detected BOOLEAN       DEFAULT FALSE,
    doses_taken_so_far SMALLINT,
    adherence_pct      NUMERIC(5,2),
    action_taken       TEXT,
    visited_by         VARCHAR(100),
    notes              TEXT
);

-- 3.7  Adverse Event Reports
CREATE TABLE adverse_event_reports (
    ae_report_id     SERIAL        PRIMARY KEY,
    enrolment_id     INT           NOT NULL REFERENCES tpt_enrolments(enrolment_id),
    ae_catalogue_id  INT           REFERENCES adverse_events_catalogue(ae_id),
    report_date      DATE          NOT NULL DEFAULT CURRENT_DATE,
    onset_date       DATE,
    ae_description   TEXT          NOT NULL,
    severity         VARCHAR(20)   NOT NULL
        CHECK (severity IN ('Mild','Moderate','Severe','Life-threatening')),
    suspected_drug   VARCHAR(50),
    action           VARCHAR(50)
        CHECK (action IN ('Continue','Hold','Discontinue','Refer','Substitute Regimen')),
    tpt_stopped      BOOLEAN       DEFAULT FALSE,
    tpt_restarted    BOOLEAN       DEFAULT FALSE,
    alternative_regimen INT        REFERENCES tpt_regimens(regimen_id),
    outcome_of_ae    TEXT,
    reported_by      VARCHAR(100)
);

-- 3.8  Treatment Interruptions
CREATE TABLE treatment_interruptions (
    interruption_id     SERIAL        PRIMARY KEY,
    enrolment_id        INT           NOT NULL REFERENCES tpt_enrolments(enrolment_id),
    interruption_start  DATE          NOT NULL,
    interruption_end    DATE,
    duration_days       SMALLINT      GENERATED ALWAYS AS (
        (interruption_end - interruption_start)::SMALLINT
    ) STORED,
    reason              VARCHAR(200),
    doses_taken_before  SMALLINT,
    pct_doses_taken     NUMERIC(5,2),
    management_action   VARCHAR(50)
        CHECK (management_action IN ('Resume','Restart Full Course','Switch Regimen','Discontinue')),
    notes               TEXT
);

-- ─────────────────────────────────────────────
-- SECTION 4 — SUPPLY CHAIN (Chapter 10)
-- ─────────────────────────────────────────────

CREATE TABLE supply_chain_levels (
    level_id        SERIAL        PRIMARY KEY,
    level_name      VARCHAR(50)   UNIQUE NOT NULL,
    buffer_months   SMALLINT      NOT NULL,
    replenishment   VARCHAR(50),
    notes           TEXT
);

CREATE TABLE drug_stock (
    stock_id        SERIAL        PRIMARY KEY,
    hf_id           INT           NOT NULL REFERENCES health_facilities(hf_id),
    regimen_id      INT           NOT NULL REFERENCES tpt_regimens(regimen_id),
    level_id        INT           NOT NULL REFERENCES supply_chain_levels(level_id),
    as_of_date      DATE          NOT NULL DEFAULT CURRENT_DATE,
    full_courses_in_stock  INT    NOT NULL DEFAULT 0,
    batch_number    VARCHAR(50),
    expiry_date     DATE,
    last_supplied_from VARCHAR(80),
    notes           TEXT
);

-- ─────────────────────────────────────────────
-- SECTION 5 — MONITORING INDICATORS (Chapter 14)
-- ─────────────────────────────────────────────

CREATE TABLE monitoring_indicators (
    indicator_id    SERIAL        PRIMARY KEY,
    indicator_code  VARCHAR(30)   UNIQUE NOT NULL,
    indicator_name  VARCHAR(200)  NOT NULL,
    numerator_def   TEXT          NOT NULL,
    denominator_def TEXT          NOT NULL,
    target_pct      NUMERIC(5,2),
    reporting_frequency VARCHAR(20) DEFAULT 'Monthly'
);

CREATE TABLE indicator_reports (
    report_id       SERIAL        PRIMARY KEY,
    indicator_id    INT           NOT NULL REFERENCES monitoring_indicators(indicator_id),
    district_id     INT           REFERENCES districts(district_id),
    hf_id           INT           REFERENCES health_facilities(hf_id),
    reporting_period_start DATE   NOT NULL,
    reporting_period_end   DATE   NOT NULL,
    numerator_value INT           NOT NULL,
    denominator_value INT         NOT NULL,
    result_pct      NUMERIC(5,2)  GENERATED ALWAYS AS (
        CASE WHEN denominator_value > 0
             THEN ROUND((numerator_value::NUMERIC / denominator_value) * 100, 2)
             ELSE 0 END
    ) STORED,
    reported_by     VARCHAR(100),
    created_at      TIMESTAMPTZ   DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- SECTION 6 — USEFUL INDEXES
-- ─────────────────────────────────────────────

CREATE INDEX idx_persons_nikshay        ON persons(nikshay_id);
CREATE INDEX idx_persons_hiv            ON persons(hiv_status);
CREATE INDEX idx_contacts_index         ON contacts(index_patient_id);
CREATE INDEX idx_enrolment_person       ON tpt_enrolments(person_id);
CREATE INDEX idx_enrolment_regimen      ON tpt_enrolments(regimen_id);
CREATE INDEX idx_enrolment_status       ON tpt_enrolments(current_status);
CREATE INDEX idx_dose_enrolment         ON tpt_dose_records(enrolment_id);
CREATE INDEX idx_screening_person       ON tb_screenings(person_id);
CREATE INDEX idx_stock_hf_regimen       ON drug_stock(hf_id, regimen_id);


-- QUICK-REFERENCE VIEWS
-- =============================================================================

-- Active TPT Enrolments with patient and regimen detail
CREATE VIEW v_active_tpt_enrolments AS
SELECT
    e.enrolment_id,
    p.nikshay_id,
    p.first_name || ' ' || COALESCE(p.last_name,'') AS patient_name,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.date_of_birth))::INT AS age_yrs,
    p.sex,
    p.hiv_status,
    r.regimen_code,
    r.regimen_name,
    e.start_date,
    e.planned_end_date,
    e.extended_end_date,
    e.weight_kg,
    e.pyridoxine_prescribed,
    e.adherence_method,
    e.current_status,
    hf.facility_name AS treating_facility,
    d.district_name
FROM tpt_enrolments e
JOIN persons p            ON p.person_id   = e.person_id
JOIN tpt_regimens r       ON r.regimen_id  = e.regimen_id
JOIN health_facilities hf ON hf.hf_id      = e.hf_id
JOIN districts d          ON d.district_id = p.district_id
WHERE e.current_status = 'Active';

-- TPT Care Cascade summary per district
CREATE VIEW v_tpt_cascade_district AS
SELECT
    d.district_name,
    COUNT(DISTINCT c.contact_id)                                   AS contacts_enumerated,
    COUNT(DISTINCT sc.screening_id)                                AS contacts_screened,
    COUNT(DISTINCT tr.tbi_result_id)                               AS contacts_tbi_tested,
    COUNT(DISTINCT ea.assessment_id) FILTER (WHERE ea.is_eligible) AS contacts_eligible,
    COUNT(DISTINCT en.enrolment_id)                                AS contacts_initiated,
    COUNT(DISTINCT en.enrolment_id) FILTER (WHERE en.current_status = 'Completed') AS contacts_completed
FROM districts d
LEFT JOIN persons p  ON p.district_id = d.district_id
LEFT JOIN contacts c ON c.person_id   = p.person_id
LEFT JOIN tb_screenings sc ON sc.person_id = p.person_id
LEFT JOIN tbi_test_results tr ON tr.person_id = p.person_id
LEFT JOIN tpt_eligibility_assessments ea ON ea.person_id = p.person_id
LEFT JOIN tpt_enrolments en ON en.person_id = p.person_id
GROUP BY d.district_name
ORDER BY d.district_name;

-- Drug interaction lookup
CREATE VIEW v_drug_interactions_summary AS
SELECT
    tpt_drug,
    drug_class,
    interacting_drugs,
    effect,
    clinical_note
FROM drug_interactions
ORDER BY tpt_drug, drug_class;

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
