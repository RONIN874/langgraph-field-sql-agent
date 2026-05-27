-- =============================================================================
-- PMTPT INDIA 2021 — SEED DATA
-- Run this AFTER pmtpt_schema.sql has been executed.
-- Derived from: Guidelines for Programmatic Management of TB Preventive
-- Treatment in India, 2021 (Ministry of Health & Family Welfare, GoI / WHO)
-- =============================================================================

-- SECTION 7 — SEED DATA
-- =============================================================================

-- ─── 7.1  States ─────────────────────────────
INSERT INTO states (state_code, state_name, region) VALUES
('MH',  'Maharashtra',       'West'),
('DL',  'Delhi',             'North'),
('KL',  'Kerala',            'South'),
('CG',  'Chhattisgarh',      'Central'),
('UP',  'Uttar Pradesh',     'North'),
('TN',  'Tamil Nadu',        'South'),
('GJ',  'Gujarat',           'West'),
('WB',  'West Bengal',       'East'),
('KA',  'Karnataka',         'South'),
('RJ',  'Rajasthan',         'North');

-- ─── 7.2  Districts ───────────────────────────
INSERT INTO districts (state_id, district_code, district_name) VALUES
(1,  'MH-MUM', 'Mumbai'),
(1,  'MH-PUN', 'Pune'),
(2,  'DL-CEN', 'Central Delhi'),
(2,  'DL-STH', 'South Delhi'),
(3,  'KL-TVM', 'Thiruvananthapuram'),
(3,  'KL-EKM', 'Ernakulam'),
(4,  'CG-RIP', 'Raipur'),
(4,  'CG-DUG', 'Durg'),
(5,  'UP-LKO', 'Lucknow'),
(5,  'UP-VNS', 'Varanasi'),
(6,  'TN-CHE', 'Chennai'),
(7,  'GJ-AHM', 'Ahmedabad'),
(8,  'WB-KOL', 'Kolkata'),
(9,  'KA-BLR', 'Bengaluru'),
(10, 'RJ-JAI', 'Jaipur');

-- ─── 7.3  TB Units ───────────────────────────
INSERT INTO tb_units (district_id, tu_code, tu_name) VALUES
(1,  'TU-MUM-01', 'Mumbai North TU'),
(1,  'TU-MUM-02', 'Mumbai South TU'),
(3,  'TU-DLC-01', 'Central Delhi TU-1'),
(5,  'TU-TVM-01', 'Thiruvananthapuram TU-1'),
(7,  'TU-RIP-01', 'Raipur TU-1'),
(9,  'TU-LKO-01', 'Lucknow TU-1'),
(11, 'TU-CHE-01', 'Chennai North TU'),
(14, 'TU-BLR-01', 'Bengaluru TU-1');

-- ─── 7.4  Health Facilities ───────────────────
INSERT INTO health_facilities
    (tu_id, district_id, nikshay_hf_code, facility_name, facility_type,
     sector, is_tbi_testing, is_igra_available, is_xray_available) VALUES
(1,  1,  'HF-MUM-001', 'Dharavi HWC',                  'HWC',             'Public', TRUE,  FALSE, FALSE),
(1,  1,  'HF-MUM-002', 'KEM Hospital',                 'Medical College',  'Public', TRUE,  TRUE,  TRUE),
(2,  1,  'HF-MUM-003', 'Sion ART Centre',              'ART Centre',       'Public', TRUE,  FALSE, TRUE),
(3,  3,  'HF-DLC-001', 'GTB Hospital Delhi',           'District Hospital','Public', TRUE,  TRUE,  TRUE),
(4,  5,  'HF-TVM-001', 'SAT Hospital ART Centre',      'ART Centre',       'Public', TRUE,  TRUE,  TRUE),
(4,  5,  'HF-TVM-002', 'Peroorkada PHC',               'PHC',              'Public', TRUE,  FALSE, FALSE),
(5,  7,  'HF-RIP-001', 'Raipur DR-TB Centre',          'DR-TB Centre',     'Public', TRUE,  TRUE,  TRUE),
(5,  7,  'HF-RIP-002', 'Mowa Sub-Centre',              'Sub-Centre',       'Public', FALSE, FALSE, FALSE),
(6,  9,  'HF-LKO-001', 'KGMU ART Centre',              'ART Centre',       'Public', TRUE,  TRUE,  TRUE),
(6,  9,  'HF-LKO-002', 'Chinhat HWC',                  'HWC',              'Public', TRUE,  FALSE, FALSE),
(7,  11, 'HF-CHE-001', 'NIRT Chennai',                 'Medical College',  'Public', TRUE,  TRUE,  TRUE),
(8,  14, 'HF-BLR-001', 'Victoria Hospital',            'District Hospital','Public', TRUE,  TRUE,  TRUE),
(NULL, 1,'HF-PRV-001', 'Dr Mehta Private Clinic',      'Private Clinic',   'Private',FALSE, FALSE, FALSE),
(NULL, 3,'HF-PRV-002', 'Apollo Hospital Delhi',        'Corporate Hospital','Private',TRUE, TRUE,  TRUE);

-- ─── 7.5  TPT Regimens ───────────────────────
INSERT INTO tpt_regimens
    (regimen_code, regimen_name, drugs, duration_months, dose_frequency,
     total_doses, completion_threshold_pct, extended_duration_days, indication, contraindications, notes) VALUES
('6H',   'Six months daily Isoniazid',
    'Isoniazid (H)',
    6, 'Daily', 180, 80.00, 239,
    'PLHIV (adults & children >12m); Infants <12m HIV+ in contact with active TB; HHC <5yrs; HHC ≥5yrs; Other risk groups. Safe in pregnancy.',
    'Active TB disease; Acute/chronic hepatitis; Peripheral neuropathy; Heavy alcohol use; Allergy to isoniazid',
    'Maximum dose 300 mg/day for adults. Pyridoxine co-prescribed for at-risk groups.'),

('3HP',  'Three months weekly Isoniazid + Rifapentine',
    'Isoniazid (H) + Rifapentine (P)',
    3, 'Weekly', 12, 90.00, 120,
    'Persons ≥2 years: HHC of DS-TB patients; PLHIV (not on PI/NVP/TAF); Other risk groups. Higher completion rate vs 6H.',
    'Pregnancy; PI-based ART; Nevirapine; TAF; Children <2 years; Allergy to rifamycins',
    'Best taken with a meal. Causes orange discolouration of secretions. Directly observed preferable.'),

('6Lfx', 'Six months daily Levofloxacin',
    'Levofloxacin (Lfx)',
    6, 'Daily', 180, 80.00, 239,
    'Contacts of MDR-TB / RR-TB patients with FQ-sensitive index patient.',
    'FQ resistance; Children: monitor for joint abnormalities',
    'Paediatric dispersible 100mg tablet available. Monitor for Achilles tendon pain.'),

('4R',   'Four months daily Rifampicin',
    'Rifampicin (R)',
    4, 'Daily', 120, 80.00, 160,
    'Contacts of H-resistant R-sensitive DR-TB patients (Hr-TB contacts).',
    'Pregnancy; Nevirapine-based ART; PI-based ART; Allergy to rifamycins',
    'Children 0-14yrs: limited geographies for evidence generation only. Max dose 600mg/day.');

-- ─── 7.6  Drug Formulations ──────────────────
-- 6H child doses (age <10yrs: 10mg/kg; age ≥10yrs: 5mg/kg, max 300mg)
INSERT INTO drug_formulations
    (regimen_id, age_group, weight_band_min_kg, weight_band_max_kg, drug_name, dose_mg, formulation_mg, tablets_per_dose) VALUES
(1, 'Adult (>14yrs)',  NULL, NULL, 'Isoniazid', 300, 300, 1.0),
(1, 'Child (≥10yrs)', NULL, NULL, 'Isoniazid', 300, 300, 1.0),
(1, 'Child (<10yrs)', NULL, NULL, 'Isoniazid (10mg/kg)', 100, 100, 1.0),

-- 3HP child doses (2-14yrs) per weight band
(2, 'Child (2-14yrs)', 10, 15,  'Isoniazid',               300, 100, 3.0),
(2, 'Child (2-14yrs)', 10, 15,  'Rifapentine',             300, 150, 2.0),
(2, 'Child (2-14yrs)', 16, 23,  'Isoniazid',               500, 100, 5.0),
(2, 'Child (2-14yrs)', 16, 23,  'Rifapentine',             450, 150, 3.0),
(2, 'Child (2-14yrs)', 24, 30,  'Isoniazid',               600, 100, 6.0),
(2, 'Child (2-14yrs)', 24, 30,  'Rifapentine',             600, 150, 4.0),
(2, 'Child (2-14yrs)', 31, 34,  'Isoniazid',               700, 100, 7.0),
(2, 'Child (2-14yrs)', 31, 34,  'Rifapentine',             750, 150, 5.0),
(2, 'Child (2-14yrs)', 34, NULL,'Isoniazid',               700, 100, 7.0),
(2, 'Child (2-14yrs)', 34, NULL,'Rifapentine',             750, 150, 5.0),

-- 3HP adult doses (>14yrs) — fixed dose by weight band
(2, 'Adult (>14yrs)', 30, 35,  'Isoniazid',               900,  300, 3.0),
(2, 'Adult (>14yrs)', 30, 35,  'Rifapentine',             900,  150, 6.0),
(2, 'Adult (>14yrs)', 36, 45,  'Isoniazid',               900,  300, 3.0),
(2, 'Adult (>14yrs)', 36, 45,  'Rifapentine',             900,  150, 6.0),
(2, 'Adult (>14yrs)', 46, 55,  'Isoniazid',               900,  300, 3.0),
(2, 'Adult (>14yrs)', 46, 55,  'Rifapentine',             900,  150, 6.0),
(2, 'Adult (>14yrs)', 56, 70,  'Isoniazid',               900,  300, 3.0),
(2, 'Adult (>14yrs)', 56, 70,  'Rifapentine',             900,  150, 6.0),
(2, 'Adult (>14yrs)', 70, NULL,'Isoniazid',               900,  300, 3.0),
(2, 'Adult (>14yrs)', 70, NULL,'Rifapentine',             900,  150, 6.0),

-- 6Lfx adult
(3, 'Adult (>14yrs, <45kg)',  NULL, 45,  'Levofloxacin', 750,  500, 1.5),
(3, 'Adult (>14yrs, ≥45kg)',  45, NULL, 'Levofloxacin', 1000, 500, 2.0),
-- 6Lfx paediatric weight bands
(3, 'Child (<15yrs)',  5,  9,  'Levofloxacin', 150,  100, 1.5),
(3, 'Child (<15yrs)', 10, 15,  'Levofloxacin', 250,  100, 2.5),
(3, 'Child (<15yrs)', 16, 23,  'Levofloxacin', 350,  100, 3.5),
(3, 'Child (<15yrs)', 24, 34,  'Levofloxacin', 625,  100, 6.25),

-- 4R doses
(4, 'Adult (≥10yrs)',  NULL, NULL,'Rifampicin', 600, 150, 4.0),
(4, 'Child (<10yrs)',  NULL, NULL,'Rifampicin (15mg/kg)', 300, 150, 2.0);

-- ─── 7.7  TBI Diagnostic Tests ───────────────
INSERT INTO tbi_tests
    (test_code, test_name, test_type, positive_cutoff, specificity, sensitivity,
     requires_lab, cost_category, notes) VALUES
('TST',  'Tuberculin Skin Test (Mantoux)',
    'TST', '≥5 mm in PLHIV; ≥10 mm in immunocompetent adults; ≥6 mm increase at follow-up',
    'Low in BCG-vaccinated', 'High',
    FALSE, 'Low',
    'Read at 48-72h. Intradermal injection of PPD. Field-friendly. Cold chain required for tuberculin.'),
('QGIT', 'QuantiFERON-Gold In-Tube (IGRA)',
    'IGRA', '≥0.35 IU/ml',
    'High also in BCG-vaccinated', 'High',
    TRUE, 'High',
    'Blood must reach lab within 8-30h. ELISA reading. High specificity. Not affected by BCG vaccination.'),
('TSPOT','T-SPOT.TB (IGRA)',
    'IGRA', 'Spot count ≥6 on ESAT-6 or CFP-10 antigen plate',
    'High also in BCG-vaccinated', 'High',
    TRUE, 'High',
    'Alternative IGRA. Measures number of IFN-γ secreting T-lymphocytes.');

-- ─── 7.8  Risk Groups ────────────────────────
INSERT INTO risk_groups
    (group_code, group_name, tpt_strategy, tbi_test_required, priority_level, description) VALUES
('PLHIV-ADL',   'People Living with HIV – Adults & Adolescents (>12m)',
    'TPT to all after ruling out active TB disease via 4-symptom screen ± CXR',
    FALSE, 1,
    'Includes those on ART or not. 4-symptoms: cough, fever, weight loss, night sweats.'),
('PLHIV-INF',   'HIV-positive Infants <12 months in contact with pulmonary TB',
    'TPT with 6H after ruling out active TB; TST/IGRA not required',
    FALSE, 1,
    'Asymptomatic HIV+ infants <1yr: TPT only if household contact of TB.'),
('HHC-U5',      'Household Contacts <5 years of pulmonary* TB patients',
    'TPT after ruling out active TB – no TBI test required',
    FALSE, 1,
    'Highest paediatric risk. CXR & TBI not mandatory. Must not defer TPT in their absence.'),
('HHC-5PLUS',   'Household Contacts ≥5 years of pulmonary* TB patients',
    'TPT if TBI positive or unavailable, CXR normal or unavailable, after ruling out active TB',
    TRUE, 2,
    'Includes adults and children ≥5 yrs. CXR offered wherever available.'),
('IMMUNO-SUPP', 'Persons on Immunosuppressive Therapy',
    'TBI testing mandatory before TPT; TPT if TBI positive and active TB excluded',
    TRUE, 2,
    'Anti-TNF agents, steroids, organ transplant prep, dialysis, silicosis.'),
('SILICOSIS',   'Persons with Silicosis',
    'TBI testing mandatory before TPT',
    TRUE, 2,
    'Significantly elevated TB risk due to silicosis.'),
('DIALYSIS',    'Persons on Dialysis',
    'TBI testing mandatory before TPT',
    TRUE, 2,
    'Standard dosing of H and R/RFP possible. Pyridoxine mandatory.'),
('PRE-TRANS',   'Candidates for Organ or Hematologic Transplantation',
    'TBI testing mandatory before TPT',
    TRUE, 2,
    'Must rule out active TB before proceeding with transplant.'),
('DRTB-HHC',    'Household Contacts of DR-TB (MDR/RR FQ-sensitive) Index Patients',
    'TPT with 6Lfx after TBI test and ruling out active TB',
    TRUE, 2,
    'Phased roll-out. Refer to Chapter 8 algorithm.'),
('HRTB-HHC',    'Household Contacts of H-resistant R-sensitive TB (Hr-TB) Index Patients',
    'TPT with 4R after TBI test and ruling out active TB',
    TRUE, 2,
    'Phased roll-out. Must confirm H-resistance & R-sensitivity in index patient.');

-- ─── 7.9  Adverse Events Catalogue ───────────────
INSERT INTO adverse_events_catalogue
    (drug, event_name, severity_class, management_action, stop_tpt) VALUES
('Isoniazid', 'Asymptomatic serum liver enzyme elevation',     'Known',  'Monitor; stop if ALT ≥3×ULN with symptoms or ≥5×ULN without', FALSE),
('Isoniazid', 'Drug-induced hepatitis',                        'Known',  'Stop all drugs; wait for resolution; re-challenge once resolved', TRUE),
('Isoniazid', 'Peripheral neuropathy (paraesthesia/numbness)', 'Known',  'Pyridoxine 100-200mg/day; consider stopping H', FALSE),
('Isoniazid', 'Skin rash',                                     'Known',  'Antihistamine for mild rash; corticosteroids for severe', FALSE),
('Isoniazid', 'Sleepiness and lethargy',                       'Known',  'Reassure', FALSE),
('Isoniazid', 'Convulsions',                                   'Rare',   'Withhold H; evaluate; pyridoxine high dose', TRUE),
('Isoniazid', 'Pellagra',                                      'Rare',   'Nicotinamide 300mg/day for 3-4 weeks; discontinue H', TRUE),
('Isoniazid', 'Anaemia',                                       'Rare',   'Investigate; manage as per standard protocol', FALSE),
('Isoniazid', 'Psychosis',                                     'Rare',   'Psychiatric evaluation; antipsychotic; pyridoxine', TRUE),

('Rifampicin', 'Gastrointestinal reactions (nausea/vomiting/abdominal pain)', 'Known', 'Reassure; antiemetics; take with small amount of food if severe', FALSE),
('Rifampicin', 'Hepatitis',                                    'Known',  'Stop drugs; wait for resolution; re-challenge', TRUE),
('Rifampicin', 'Generalised cutaneous reactions',              'Known',  'Antihistamine; steroids if severe', FALSE),
('Rifampicin', 'Discolouration of body fluids (orange/pink)',  'Known',  'Reassure – cosmetic only', FALSE),
('Rifampicin', 'Thrombocytopenic purpura',                     'Known',  'Stop rifampicin; haematology referral', TRUE),
('Rifampicin', 'Flu-like syndrome',                            'Rare',   'Assess severity; switch to daily regimen if recurrent', FALSE),
('Rifampicin', 'Acute renal failure',                          'Rare',   'Stop rifampicin; renal referral', TRUE),
('Rifampicin', 'Haemolytic anaemia',                           'Rare',   'Stop rifampicin; haematology referral', TRUE),

('Rifapentine', 'Gastrointestinal reactions',                  'Known',  'Antiemetics; take with meal to improve tolerability', FALSE),
('Rifapentine', 'Hypersensitivity / flu-like syndrome',        'Known',  'Mild: continue and observe; Moderate-Severe: switch to 6H', FALSE),
('Rifapentine', 'Hepatitis',                                   'Known',  'Stop drugs; wait for resolution', TRUE),
('Rifapentine', 'Discolouration of body fluids',               'Known',  'Reassure', FALSE),
('Rifapentine', 'Decreased WBC/RBC count',                     'Rare',   'Monitor CBC; assess severity', FALSE),
('Rifapentine', 'Hypotension/syncope',                         'Rare',   'Assess; hold dose; medical review', TRUE),

('Levofloxacin','Nausea, diarrhoea, headache, dizziness',      'Known',  'Reassure; manage symptomatically', FALSE),
('Levofloxacin','Joint abnormalities (children)',               'Known',  'Monitor; refer to orthopaedic if progressive', FALSE),
('Levofloxacin','Clostridium difficile diarrhoea',             'Rare',   'Stop Lfx; do not use anti-diarrhoeals or opioids; refer', TRUE),
('Levofloxacin','Tendon rupture (Achilles)',                    'Rare',   'Stop Lfx immediately; orthopaedic referral', TRUE),
('Levofloxacin','QTc prolongation / arrhythmia',               'Rare',   'ECG; cardiology referral; stop Lfx', TRUE);

-- ─── 7.10  Drug-Drug Interactions ─────────────
INSERT INTO drug_interactions
    (tpt_drug, drug_class, interacting_drugs, effect, clinical_note) VALUES
('Isoniazid', 'Anticonvulsants',     'Phenytoin, carbamazepine, primidone, valproic acid', 'Increases', 'Monitor anticonvulsant levels; dose adjustment may be needed'),
('Isoniazid', 'Anticoagulants',      'Warfarin',                                           'Increases', 'Monitor INR closely'),
('Isoniazid', 'Antidepressants',     'Amitriptyline, nortriptyline, some SSRIs',           'Increases', 'Monitor for serotonin syndrome'),
('Isoniazid', 'Methylxanthines',     'Theophylline',                                       'Increases', 'Reduce theophylline dose; monitor levels'),
('Isoniazid', 'Narcotic analgesics', 'Methadone',                                          'Increases', 'Monitor for opioid toxicity'),

('Rifamycin',  'Antiretrovirals',    'Protease inhibitors (PIs)',                          'Decreases', 'Contraindicated with rifampicin/rifapentine. Consider rifabutin.'),
('Rifamycin',  'Antiretrovirals',    'Nevirapine (NVP)',                                   'Decreases', 'Contraindicated with rifampicin/rifapentine. Use 6H instead.'),
('Rifamycin',  'Antiretrovirals',    'Tenofovir alafenamide (TAF)',                        'Decreases', 'Contraindicated with 3HP. TDF is safe alternative.'),
('Rifamycin',  'Antiretrovirals',    'Raltegravir (RAL)',                                  'Decreases', 'Use RAL 800mg twice daily with rifampicin; no adjustment needed with efavirenz'),
('Rifamycin',  'Hormonal contraceptives', 'Ethinyl oestradiol, levonorgestrel',            'Decreases', 'Use barrier contraception or DMPA while on rifamycin-based TPT'),
('Rifamycin',  'Immunosuppressants', 'Cyclosporine, tacrolimus',                           'Decreases', 'Significant reduction in blood levels; dose adjustment critical; monitor trough'),
('Rifamycin',  'Corticosteroids',    'Prednisone',                                         'Decreases', 'May need to double corticosteroid dose'),
('Rifamycin',  'Oral hypoglycaemics','Sulfonylureas',                                      'Decreases', 'Monitor blood sugar; dose adjustment may be needed'),
('Rifamycin',  'Narcotic analgesics','Methadone, buprenorphine (OST)',                     'Decreases', 'Risk of opiate withdrawal. Increase OST dose; closely monitor PWUD'),
('Rifamycin',  'Antifungals',        'Fluconazole, itraconazole, ketoconazole',            'Decreases', 'Reduced antifungal efficacy; consider alternative antifungal'),
('Rifamycin',  'Direct-acting antivirals (HCV)', 'Sofosbuvir, ledipasvir, daclatasvir',   'Decreases', 'Complete HCV treatment before or after rifamycin-based TPT');

-- ─── 7.11  Treatment Outcome Types ──────────────
INSERT INTO treatment_outcome_types (outcome_code, outcome_name, description) VALUES
('COMPLETED',   'Treatment Completed',
    '≥80% doses (6H/6Lfx/4R) or ≥90% doses (3HP) within 133% of planned duration. Person remains well.'),
('FAILED',      'Treatment Failed',
    'Person developed confirmed active TB disease at any time while on TPT course.'),
('DIED',        'Died',
    'Person died for any reason while on the TPT course.'),
('LTFU',        'Lost to Follow-up',
    'TPT interrupted for ≥8 consecutive weeks (6H/6Lfx) or ≥4 consecutive weeks (3HP/4R).'),
('DISC_TOX',    'Discontinued due to Toxicity',
    'TPT permanently discontinued by treating doctor due to adverse events or drug-drug interactions.'),
('NOT_EVAL',    'Not Evaluated',
    'Outcome not assessable (e.g. records lost, transferred without documentation).'),
('REG_CHANGE',  'Regimen Change',
    'TPT regimen changed due to adverse event or other clinical reason.');

-- ─── 7.12  Supply Chain Levels ───────────────
INSERT INTO supply_chain_levels (level_name, buffer_months, replenishment, notes) VALUES
('Treatment Supporter',  0, 'Per beneficiary',   'Full TPT course issued per eligible person to treatment supporter'),
('Health Facility Store',2, 'Monthly from TU',   'Reserve = 2 × total TPT beneficiaries on full course'),
('TU Drug Store',        2, 'Quarterly from DTC', '(Quarterly consumption/3) × 5 minus existing stocks'),
('DTC Drug Store',       3, 'Quarterly from SDS', '(Quarterly consumption/3) × 8 minus existing stocks'),
('State Drug Store (SDS)',3,'From GMSD/CMSS',    '(Quarterly consumption/3) × 11 minus all lower level stocks'),
('GMSD/CMSS',            0, 'Central procurement','Central TB Division / MoHFW source');

-- ─── 7.13  Monitoring Indicators ─────────────
INSERT INTO monitoring_indicators
    (indicator_code, indicator_name, numerator_def, denominator_def, target_pct, reporting_frequency) VALUES
('CONT-INV-COV',
    'Contact Investigation Coverage',
    'Total contacts of pulmonary* TB patients who completed evaluation for TB disease and TB infection',
    'Total contacts of pulmonary* TB patients during the specific period',
    100.0, 'Monthly'),
('TPT-COV',
    'TPT Coverage',
    'Total individuals eligible for TPT who initiated treatment during the period',
    'Total individuals eligible for TPT during the period',
    90.0, 'Monthly'),
('TPT-COMP',
    'TPT Completion Rate',
    'Total individuals who completed a course of TPT',
    'Total individuals initiated on TPT during the period',
    90.0, 'Monthly'),
('TPT-BREAK',
    'Breakdown Rate to Active TB among TPT Beneficiaries',
    'Total beneficiaries on/post TPT diagnosed with active TB during TPT or within 24 months post-completion',
    'Total beneficiaries initiated on TPT during the period',
    NULL, 'Quarterly'),
('PLHIV-TPT-COV',
    'PLHIV TPT Coverage',
    'Newly enrolled PLHIV initiated on TPT after ruling out active TB',
    'Total newly enrolled PLHIV during the period',
    90.0, 'Monthly'),
('U5-TPT-COMP',
    'Under-5 HHC TPT Completion',
    'Children <5 yrs HHC who completed TPT',
    'Children <5 yrs HHC initiated on TPT',
    90.0, 'Monthly'),
('POST-TPT-FU',
    'Post-TPT Follow-up Coverage (6m, 12m, 18m, 24m)',
    'Individuals who completed TPT and received follow-up assessment at scheduled interval',
    'Total individuals who completed TPT',
    90.0, 'Monthly');

-- ─── 7.14  Sample Persons & Clinical Data ─────

-- Two index TB patients
INSERT INTO persons
    (nikshay_id, first_name, last_name, date_of_birth, sex, district_id,
     hiv_status, on_art, registered_at) VALUES
('NK-MH-001234', 'Ramesh',   'Patil',   '1982-04-10', 'Male',   1, 'Negative', NULL, 1),
('NK-DL-009988', 'Sunita',   'Sharma',  '1990-11-22', 'Female', 3, 'Positive', TRUE, 3);

-- Three contacts / high-risk persons
INSERT INTO persons
    (nikshay_id, first_name, last_name, date_of_birth, sex, district_id,
     hiv_status, on_art, registered_at) VALUES
('NK-MH-001235', 'Priya',    'Patil',   '2019-06-05', 'Female', 1, 'Negative', NULL, 1),  -- child <5
('NK-MH-001236', 'Suresh',   'Patil',   '1985-01-30', 'Male',   1, 'Negative', NULL, 1),  -- adult HHC
('NK-DL-009990', 'Anjali',   'Mehra',   '1988-08-14', 'Female', 3, 'Positive', TRUE, 3);  -- PLHIV

-- Index TB Patients
INSERT INTO index_tb_patients
    (person_id, nikshay_patient_id, notification_date, notification_source,
     hf_id, tb_type, bacteriologically_confirmed, is_h_resistant, is_r_resistant) VALUES
(1, 'NK-MH-001234', '2024-01-15', 'Public', 1,
 'Pulmonary-Bacteriologically Confirmed', TRUE, FALSE, FALSE),
(2, 'NK-DL-009988', '2024-02-03', 'Public', 3,
 'Pulmonary-Bacteriologically Confirmed', TRUE, FALSE, FALSE);

-- Contacts
INSERT INTO contacts
    (person_id, index_patient_id, relationship, contact_type, enumeration_date, enumerated_by_hf, home_visit_done) VALUES
(3, 1, 'Child',  'Household', '2024-01-22', 1, TRUE),   -- Priya <5 yrs
(4, 1, 'Spouse', 'Household', '2024-01-22', 1, TRUE),   -- Suresh adult
(5, 2, 'Friend', 'Close',     '2024-02-10', 3, FALSE);  -- Anjali PLHIV

-- TB Screenings
INSERT INTO tb_screenings
    (person_id, hf_id, screening_date, has_cough, has_fever, has_weight_loss, has_night_sweats,
     cxr_done, cxr_result, outcome) VALUES
(3, 1, '2024-01-22', FALSE, FALSE, FALSE, FALSE, FALSE, 'Not Available', 'Eligible for TPT'),
(4, 1, '2024-01-22', FALSE, FALSE, FALSE, FALSE, TRUE,  'Normal',        'Eligible for TBI Test'),
(5, 3, '2024-02-10', FALSE, FALSE, FALSE, FALSE, TRUE,  'Normal',        'Eligible for TPT');

-- TBI Test Results for adult HHC (≥5 yrs)
INSERT INTO tbi_test_results
    (person_id, test_id, hf_id, request_date, test_date, result_date, result, tst_mm) VALUES
(4, 1, 1, '2024-01-22', '2024-01-22', '2024-01-24', 'Positive', 14.0);

-- TPT Eligibility Assessments
INSERT INTO tpt_eligibility_assessments
    (person_id, hf_id, assessment_date, risk_group_id, active_tb_excluded,
     tbi_test_result_id, is_eligible, recommended_regimen, assessed_by) VALUES
(3, 1, '2024-01-23', 3, TRUE, NULL, TRUE, 1, 'Dr Desai (CHO, Dharavi HWC'),    -- HHC <5 → 6H
(4, 1, '2024-01-25', 4, TRUE, 1,    TRUE, 2, 'Dr Desai (CHO, Dharavi HWC'),    -- HHC ≥5, TBI+ → 3HP
(5, 3, '2024-02-11', 1, TRUE, NULL, TRUE, 1, 'Dr Fernandes (Sion ART Centre)'); -- PLHIV → 6H

-- TPT Enrolments
INSERT INTO tpt_enrolments
    (person_id, assessment_id, hf_id, regimen_id, start_date, planned_end_date,
     extended_end_date, weight_kg, pyridoxine_prescribed, pyridoxine_dose_mg,
     treatment_supporter, adherence_method, counselling_done, initiated_by, current_status) VALUES
(3, 1, 1, 1, '2024-01-24', '2024-07-23', '2024-09-19', 14.0,
 TRUE, 10, 'Rekha Patil (mother)', 'Direct Observation', TRUE,
 'Dr Desai (CHO)', 'Active'),

(4, 2, 1, 2, '2024-01-26', '2024-04-25', '2024-06-03', 72.0,
 FALSE, NULL, 'Self (with 99DOTS)', '99DOTS', TRUE,
 'Dr Desai (CHO)', 'Completed'),

(5, 3, 3, 1, '2024-02-12', '2024-08-11', '2024-10-07', 58.0,
 TRUE, 50, 'Anjali self + ART counsellor', 'Tele-Video Call', TRUE,
 'Dr Fernandes', 'Active');

-- Update outcome for Suresh (enrolment_id = 2)
UPDATE tpt_enrolments
SET current_status = 'Completed',
    outcome_id = 1,
    outcome_date = '2024-04-25'
WHERE enrolment_id = 2;

-- Follow-up visits
INSERT INTO followup_visits
    (enrolment_id, visit_date, visit_type, weight_kg, tb_symptoms_present,
     ae_noted, doses_taken_so_far, adherence_pct, visited_by) VALUES
(1, '2024-02-24', 'Monthly Clinical',   14.2, FALSE, FALSE,  30, 96.77, 'ASHA Meena'),
(1, '2024-03-24', 'Monthly Clinical',   14.5, FALSE, FALSE,  62, 98.41, 'ASHA Meena'),
(2, '2024-02-26', 'Monthly Clinical',   71.8, FALSE, FALSE,   4,  33.33,'TBHV Rakesh'),
(2, '2024-03-26', 'Monthly Clinical',   72.0, FALSE, FALSE,   8,  66.67,'TBHV Rakesh'),
(3, '2024-03-12', 'Monthly Clinical',   57.9, FALSE, FALSE,  28, 93.33,'ART Counsellor Priti');

-- Sample Drug Stock
INSERT INTO drug_stock
    (hf_id, regimen_id, level_id, as_of_date, full_courses_in_stock, batch_number, expiry_date) VALUES
(1, 1, 2, '2024-03-01', 25,  'GMSD-6H-2402', '2026-01-31'),
(1, 2, 2, '2024-03-01', 15,  'GMSD-3HP-2403','2025-12-31'),
(3, 1, 2, '2024-03-01', 40,  'GMSD-6H-2402', '2026-01-31'),
(7, 3, 2, '2024-03-01', 10,  'GMSD-LFX-2401','2025-06-30'),
(7, 4, 2, '2024-03-01', 8,   'GMSD-4R-2401', '2025-09-30');

-- Sample Indicator Report
INSERT INTO indicator_reports
    (indicator_id, district_id, hf_id, reporting_period_start, reporting_period_end,
     numerator_value, denominator_value, reported_by) VALUES
(1, 1, 1, '2024-01-01', '2024-03-31', 18, 20, 'STS Ramakrishnan'),   -- Contact investigation 90%
(2, 1, 1, '2024-01-01', '2024-03-31', 16, 18, 'STS Ramakrishnan'),   -- TPT coverage 89%
(3, 1, 1, '2024-01-01', '2024-03-31',  5,  6, 'STS Ramakrishnan'),   -- TPT completion 83%
(1, 3, 3, '2024-01-01', '2024-03-31', 55, 60, 'DTO Delhi Central'),  -- Contact investigation 92%
(2, 3, 3, '2024-01-01', '2024-03-31', 49, 55, 'DTO Delhi Central');  -- TPT coverage 89%

-- =============================================================================
