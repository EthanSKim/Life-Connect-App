-- 0. 기존 테이블에 pin_code 컬럼 추가 및 기본값 설정 (이미 테이블이 존재하는 경우)
ALTER TABLE members ADD COLUMN IF NOT EXISTS pin_code VARCHAR(6) DEFAULT '123456';
UPDATE members SET pin_code = '123456' WHERE pin_code IS NULL OR pin_code = '';

-- 1. members 테이블 생성
CREATE TABLE members (
    person_id BIGINT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birthdate DATE,
    gender VARCHAR(10),
    marital_status VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',
    membership_role VARCHAR(50),
    campus_name VARCHAR(100),
    mobile_phone VARCHAR(20),
    email VARCHAR(100),
    address_street VARCHAR(255),
    address_city VARCHAR(100),
    address_state VARCHAR(50),
    address_zip VARCHAR(20),
    household_id BIGINT,
    household_name VARCHAR(100),
    is_primary_contact BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pin_code VARCHAR(6) DEFAULT '123456',
    life_team VARCHAR(100), -- 'Mz's Us 라이프팀' 등
    church_title VARCHAR(50) -- '집사님', '성도' 등
);

-- 출석 테이블 (생성되어 있지 않다면 추가)
CREATE TABLE IF NOT EXISTS attendance (
    attendance_id SERIAL PRIMARY KEY,
    person_id BIGINT REFERENCES members(person_id),
    attendance_date DATE DEFAULT CURRENT_DATE,
    status BOOLEAN DEFAULT TRUE,
    UNIQUE(person_id, attendance_date)
);
-- 2. 테스트용 데이터 2건 삽입 (엑셀 파일 기준)
INSERT INTO members (
    person_id, first_name, last_name, birthdate, gender, marital_status, 
    status, membership_role, campus_name, mobile_phone, email, 
    address_street, address_city, address_state, address_zip, 
    household_id, household_name, is_primary_contact, pin_code
) VALUES 
(132530884, '민우', '박', '1983-05-18', 'Male', 'Married', 'active', 'Member', 'Louisville Woori Church', '(502) 602-7799', 'blissmw@gmail.com', '1846 Washington Blvd', 'Louisville', 'KY', '40242-3443', 18560919, '박민우''s Household', TRUE, '123456'),
(132728606, '수나', '김', '1986-04-20', 'Female', 'Married', 'active', 'Member', 'Louisville Woori Church', '(502) 602-7511', 'eliel0420@gmail.com', '1846 Washington Blvd', 'Louisville', 'KY', '40242-3443', 18560919, '박민우''s Household', FALSE, '123456');

-- 기존 데이터 중 PIN이 비어있는 경우 123456으로 일괄 업데이트
UPDATE members SET pin_code = '123456' WHERE pin_code IS NULL OR pin_code = '';

-- 3. attendance 테이블 생성 (출석 기록용)
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    person_id BIGINT REFERENCES members(person_id),
    attendance_date DATE DEFAULT CURRENT_DATE,
    status BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(person_id, attendance_date)
);

-- 4. 검색 성능 최적화를 위한 인덱스 추가
-- 이름 검색 시 공백을 제거하고 검색하는 로직의 속도를 높입니다.
CREATE INDEX idx_members_full_name_search ON members (REPLACE(last_name || first_name, ' ', ''));

-- 5. notices 테이블 생성 (공지사항용)
CREATE TABLE IF NOT EXISTS notices (
    notice_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 테스트용 공지사항 데이터 삽입
INSERT INTO notices (title, content, created_at) VALUES 
('이번 주 라이프팀 리더 모임 안내', '본당에서 모임이 있습니다.', CURRENT_TIMESTAMP),
('날씨로 인한 예배 변경 사항', '이번 주 주일 예배는 온라인으로 병행됩니다.', CURRENT_TIMESTAMP - INTERVAL '2 days'),
('이은수❤️조은애 베이비 샤워', '축하해주러 오세요!', CURRENT_TIMESTAMP - INTERVAL '10 days'),
('새해 특별 새벽 기도회 안내', '새해를 기도로 시작합시다.', CURRENT_TIMESTAMP - INTERVAL '14 days');

-- 6. facilities 테이블 생성 (예약 가능 장소)
CREATE TABLE IF NOT EXISTS facilities (
    facility_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon_key VARCHAR(50) DEFAULT 'church', -- 'church', 'coffee', 'groups' 등
    description TEXT
);

-- 7. reservations 테이블 생성 (예약 내역)
CREATE TABLE IF NOT EXISTS reservations (
    reservation_id SERIAL PRIMARY KEY,
    facility_id INTEGER REFERENCES facilities(facility_id),
    person_id BIGINT REFERENCES members(person_id),
    reservation_date DATE NOT NULL,
    reservation_time TIME NOT NULL,
    status VARCHAR(20) DEFAULT 'confirmed', -- confirmed, cancelled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 테스트용 장소 데이터 삽입
INSERT INTO facilities (name, icon_key) VALUES 
('본당', 'church'),
('식당', 'coffee'),
('Youth Group', 'groups');

-- 테이블에 필요한 컬럼이 있는지 확인하고 없으면 추가합니다.
ALTER TABLE members ADD COLUMN IF NOT EXISTS membership_role VARCHAR(50);
ALTER TABLE members ADD COLUMN IF NOT EXISTS church_title VARCHAR(50);
ALTER TABLE members ADD COLUMN IF NOT EXISTS life_team VARCHAR(100);

-- 다시 한 번 PIN 번호를 123456으로 초기화 (확실히 하기 위함)
UPDATE members SET pin_code = '123456' WHERE pin_code IS NULL OR pin_code = '';

update members set membership_role='Admin' where first_name='민우'


SELECT * FROM members;


SELECT * FROM attendance;   
SELECT * FROM notices;
SELECT * FROM facilities;
SELECT * FROM reservations;