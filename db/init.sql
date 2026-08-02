-- Auto-run by the official postgres Docker image on first container start
-- (mounted into /docker-entrypoint-initdb.d/).

-- 1. households table
-- Source of truth for a household's name and its head of household.
-- members.household_id/household_name/is_primary_contact stay denormalized
-- copies for cheap reads (existing screens already read them straight off
-- the member row) - every write to those copies goes through the household
-- routes so they can't drift from this table.
CREATE TABLE IF NOT EXISTS households (
    household_id BIGINT PRIMARY KEY,
    household_name VARCHAR(100) NOT NULL,
    head_of_household_id BIGINT, -- FK added after members exists (circular dependency)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. life_teams table
-- Source of truth for a life team's name and its leader.
-- members.life_team stays a denormalized text copy for cheap reads (existing
-- screens already read it straight off the member row) - every write to
-- that copy goes through the life-team routes so it can't drift from here.
CREATE TABLE IF NOT EXISTS life_teams (
    life_team_id BIGINT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    leader_id BIGINT, -- FK added after members exists (circular dependency)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. members table
CREATE TABLE IF NOT EXISTS members (
    person_id BIGINT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birthdate DATE,
    gender VARCHAR(10),
    marital_status VARCHAR(20),
    anniversary DATE,
    -- True for children (no login/PIN meaningfully used). Distinguishes kids
    -- from adults directly instead of inferring it from marital_status/grade.
    is_child BOOLEAN DEFAULT FALSE,
    -- Raw school-grade encoding as exported from Planning Center: 1-12 = grade,
    -- 0 = kindergarten, negative = pre-K range. Nullable - only meaningful for kids.
    grade SMALLINT,
    status VARCHAR(20) DEFAULT 'active', -- 'active' | 'inactive' (soft-deleted)
    membership_role VARCHAR(50),
    campus_name VARCHAR(100),
    mobile_phone VARCHAR(20),
    email VARCHAR(100),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    address_country_code VARCHAR(5) DEFAULT 'US',
    address_country VARCHAR(100) DEFAULT 'United States',
    household_id BIGINT REFERENCES households(household_id) ON DELETE SET NULL,
    household_name VARCHAR(100),
    is_primary_contact BOOLEAN DEFAULT FALSE,
    -- Free-text relative to the household's head (e.g. '본인', '배우자', '자녀',
    -- '부모', '형제자매', '기타') - not an enum since real families don't always
    -- fit a fixed list, and it's just descriptive/display, not logic-bearing.
    relationship_to_head VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Widened to fit encrypted (AES-256-GCM) values ("iv:authTag:ciphertext"
    -- hex). Legacy plaintext 6-digit values still fit and remain readable -
    -- the backend treats anything not matching the encrypted format as
    -- legacy plaintext (see backend/crypto.js).
    pin_code VARCHAR(255) DEFAULT '123456',
    -- True until the member changes their PIN for the first time; drives
    -- the "please set your own PIN" prompt on first login.
    is_default_pin BOOLEAN DEFAULT TRUE,
    life_team_id BIGINT REFERENCES life_teams(life_team_id) ON DELETE SET NULL,
    life_team VARCHAR(100),
    church_title VARCHAR(50)
);

ALTER TABLE households
    ADD CONSTRAINT fk_household_head FOREIGN KEY (head_of_household_id)
    REFERENCES members(person_id) ON DELETE SET NULL;

ALTER TABLE life_teams
    ADD CONSTRAINT fk_life_team_leader FOREIGN KEY (leader_id)
    REFERENCES members(person_id) ON DELETE SET NULL;

-- 4. attendance table
CREATE TABLE IF NOT EXISTS attendance (
    attendance_id SERIAL PRIMARY KEY,
    person_id BIGINT REFERENCES members(person_id),
    attendance_date DATE DEFAULT CURRENT_DATE,
    status BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(person_id, attendance_date)
);

-- 5. attendance_finalizations table
-- Once an admin taps 완료 for a given day, that day's attendance is locked:
-- no more manual/bulk/QR check-ins are accepted for that date (enforced in
-- the attendance routes, not just hidden in the UI), and this row becomes
-- the durable record of "this day's roll is final" for future reporting.
CREATE TABLE IF NOT EXISTS attendance_finalizations (
    attendance_date DATE PRIMARY KEY,
    finalized_by BIGINT REFERENCES members(person_id),
    finalized_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. notices table
CREATE TABLE IF NOT EXISTS notices (
    notice_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. facilities table
CREATE TABLE IF NOT EXISTS facilities (
    facility_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon_key VARCHAR(50) DEFAULT 'church',
    description TEXT,
    -- 소프트 삭제: reservations가 facility_id를 참조하므로, 예약 이력이 있는
    -- 장소는 그냥 DELETE하면 FK 제약에 걸린다. is_active=false로 표시해서
    -- 성도용 예약 화면에는 더 이상 보이지 않게 하면서 이력은 보존한다.
    is_active BOOLEAN DEFAULT TRUE,
    -- is_active와는 다른 개념: 비활성화된 장소는 삭제된 것과 달리 성도용
    -- 목록에서 계속 보이되 "예약 불가"로 표시된다 (예: 공사 중인 장소를
    -- 완전히 숨기지 않고 이유를 알려주고 싶을 때).
    is_reservable BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. reservations table
-- A reservation is a time RANGE [start_time, end_time) within a single day,
-- 30-minute aligned, so a booking can span multiple slots (e.g. 10:00-11:00).
-- Overlap conflicts are enforced in application logic inside a transaction
-- (backend/routes/reservations.routes.js) rather than a DB constraint, since
-- Postgres has no built-in TIME range/exclusion type without extra
-- extensions - reasonable for this app's scale and concurrency.
CREATE TABLE IF NOT EXISTS reservations (
    reservation_id SERIAL PRIMARY KEY,
    facility_id INTEGER REFERENCES facilities(facility_id),
    person_id BIGINT REFERENCES members(person_id),
    reservation_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status VARCHAR(20) DEFAULT 'confirmed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_reservations_facility_date
    ON reservations (facility_id, reservation_date)
    WHERE status = 'confirmed';

-- 9. facility_availability_overrides table
-- Lets an admin open/close a specific 30-min slot on a specific date for a
-- specific facility, overriding the default Mon-Sat 10:00-18:00 / Sunday-
-- closed schedule. E.g. open a Sunday slot for a special event, or close a
-- normally-open weekday slot for maintenance.
CREATE TABLE IF NOT EXISTS facility_availability_overrides (
    override_id SERIAL PRIMARY KEY,
    facility_id INTEGER REFERENCES facilities(facility_id),
    override_date DATE NOT NULL,
    slot_time TIME NOT NULL,
    is_open BOOLEAN NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (facility_id, override_date, slot_time)
);

-- 10. indexes
CREATE INDEX IF NOT EXISTS idx_members_full_name_search
    ON members (REPLACE(last_name || first_name, ' ', ''));
CREATE INDEX IF NOT EXISTS idx_members_household ON members (household_id);
CREATE INDEX IF NOT EXISTS idx_members_life_team ON members (life_team_id);
CREATE INDEX IF NOT EXISTS idx_members_status ON members (status);

-- 11. seed data
-- Real sample data from the church's Planning Center export (a single
-- household of 4: two parents + two children), used to exercise the
-- household/relationship features end-to-end instead of synthetic data.
INSERT INTO households (household_id, household_name, head_of_household_id)
VALUES (18560919, '박민우''s Household', NULL)
ON CONFLICT (household_id) DO NOTHING;

INSERT INTO members (
    person_id, first_name, last_name, birthdate, gender, marital_status,
    anniversary, is_child, grade,
    status, membership_role, campus_name, mobile_phone, email,
    address_street, address_city, address_state, address_zip,
    address_country_code, address_country,
    household_id, household_name, is_primary_contact, relationship_to_head, pin_code
) VALUES
(132530884, '민우', '박', '1983-05-18', 'Male', 'Married', '2014-10-09', FALSE, NULL,
 'active', 'Admin', 'Louisville Woori Church', '(502) 602-7799', 'blissmw@gmail.com',
 '1846 Washington Blvd', 'Louisville', 'KY', '40242-3443', 'US', 'United States',
 18560919, '박민우''s Household', TRUE, '본인', '123456'),
(132728606, '수나', '김', '1986-04-20', 'Female', 'Married', '2014-10-09', FALSE, NULL,
 'active', 'Member', 'Louisville Woori Church', '(502) 602-7511', 'eliel0420@gmail.com',
 '1846 Washington Blvd', 'Louisville', 'KY', '40242-3443', 'US', 'United States',
 18560919, '박민우''s Household', FALSE, '배우자', '123456'),
(133163580, '예하', '박', '2016-10-08', 'Female', NULL, NULL, TRUE, 1,
 'active', 'Member', '초등부 | Kids', NULL, NULL,
 '1846 Washington Blvd', 'Louisville', 'KY', '40242-3443', 'US', 'United States',
 18560919, '박민우''s Household', FALSE, '자녀', '123456'),
(133165053, '루하', '박', '2019-04-09', 'Female', NULL, NULL, TRUE, -1,
 'active', 'Member', '초등부 | Kids', NULL, NULL,
 '1846 Washington Blvd', 'Louisville', 'KY', '40242-3443', 'US', 'United States',
 18560919, '박민우''s Household', FALSE, '자녀', '123456')
ON CONFLICT (person_id) DO NOTHING;

UPDATE households SET head_of_household_id = 132530884 WHERE household_id = 18560919;

INSERT INTO notices (title, content, created_at) VALUES
('이번 주 라이프팀 리더 모임 안내', '본당에서 모임이 있습니다.', CURRENT_TIMESTAMP),
('날씨로 인한 예배 변경 사항', '이번 주 주일 예배는 온라인으로 병행됩니다.', CURRENT_TIMESTAMP - INTERVAL '2 days'),
('이은수❤️조은애 베이비 샤워', '축하해주러 오세요!', CURRENT_TIMESTAMP - INTERVAL '10 days'),
('새해 특별 새벽 기도회 안내', '새해를 기도로 시작합시다.', CURRENT_TIMESTAMP - INTERVAL '14 days');

INSERT INTO facilities (name, icon_key) VALUES
('본당', 'church'),
('식당', 'coffee'),
('Youth Group', 'groups');
