-- AIAWA English Star Academy MVP
-- PostgreSQL schema draft. Review and run only in a development database.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_status AS ENUM ('pending_verification','active','suspended','deleted');
CREATE TYPE payment_status AS ENUM ('pending_review','verified','rejected','refunded');
CREATE TYPE reward_status AS ENUM ('pending_review','approved','paid','rejected','reversed');
CREATE TYPE wallet_status AS ENUM ('not_linked','pending_verification','verified','rejected');

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name VARCHAR(120) NOT NULL,
  email VARCHAR(254) UNIQUE NOT NULL,
  phone VARCHAR(30) UNIQUE,
  password_hash TEXT NOT NULL,
  status user_status NOT NULL DEFAULT 'pending_verification',
  email_verified_at TIMESTAMPTZ,
  referral_code VARCHAR(32) UNIQUE NOT NULL,
  referred_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (referred_by IS NULL OR referred_by <> id)
);

CREATE TABLE membership_tiers (
  id SMALLINT PRIMARY KEY,
  code VARCHAR(16) UNIQUE NOT NULL,
  name_th VARCHAR(80) NOT NULL,
  name_en VARCHAR(80) NOT NULL,
  price_minor BIGINT NOT NULL CHECK (price_minor >= 0),
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  billing_period VARCHAR(20) NOT NULL DEFAULT 'monthly',
  sort_order SMALLINT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true
);
INSERT INTO membership_tiers (id,code,name_th,name_en,price_minor,sort_order) VALUES
(1,'STAR1','พื้นฐาน','Beginner',100,1),
(2,'STAR2','ชีวิตประจำวัน','Daily Life',300,2),
(3,'STAR3','ธุรกิจ','Business English',500,3),
(4,'STAR4','ขั้นสูง','Advanced Communication',800,4),
(5,'STAR5','มืออาชีพ','Professional',1200,5);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  tier_id SMALLINT NOT NULL REFERENCES membership_tiers(id),
  status VARCHAR(20) NOT NULL CHECK (status IN ('pending_payment','active','expired','cancelled','refunded')),
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);
CREATE INDEX subscriptions_user_status_idx ON subscriptions(user_id,status);

CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(120) UNIQUE NOT NULL,
  title_th VARCHAR(200) NOT NULL,
  title_en VARCHAR(200) NOT NULL,
  description_th TEXT,
  description_en TEXT,
  required_tier_id SMALLINT NOT NULL REFERENCES membership_tiers(id),
  published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL,
  title_th VARCHAR(200) NOT NULL,
  title_en VARCHAR(200) NOT NULL,
  body_th TEXT,
  body_en TEXT,
  vocabulary JSONB NOT NULL DEFAULT '[]',
  quiz JSONB NOT NULL DEFAULT '{}',
  published BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(course_id,sort_order)
);
CREATE TABLE lesson_progress (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'started' CHECK (status IN ('started','completed')),
  score NUMERIC(5,2) CHECK (score BETWEEN 0 AND 100),
  completed_at TIMESTAMPTZ,
  PRIMARY KEY(user_id,lesson_id)
);

-- Manual payment records: never trust a submitted slip as sole proof of payment.
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  subscription_id UUID REFERENCES subscriptions(id),
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  method VARCHAR(40) NOT NULL DEFAULT 'manual_truemoney',
  provider_reference VARCHAR(120),
  proof_object_key TEXT,
  status payment_status NOT NULL DEFAULT 'pending_review',
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX payments_status_created_idx ON payments(status,created_at DESC);

CREATE TABLE referral_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_user_id UUID NOT NULL REFERENCES users(id),
  referred_user_id UUID NOT NULL UNIQUE REFERENCES users(id),
  qualifying_payment_id UUID REFERENCES payments(id),
  qualified_at TIMESTAMPTZ,
  qualification_status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (qualification_status IN ('pending','qualified','rejected','reversed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (referrer_user_id <> referred_user_id)
);

-- Referral program rule: $5 per qualified referral, total payout/award $80 on reaching 10.
-- Define whether $80 is inclusive of the $5 rewards before production launch.
CREATE TABLE reward_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  referral_event_id UUID REFERENCES referral_events(id),
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  reward_type VARCHAR(30) NOT NULL CHECK (reward_type IN ('referral','milestone_bonus','adjustment')),
  status reward_status NOT NULL DEFAULT 'pending_review',
  idempotency_key VARCHAR(120) UNIQUE NOT NULL,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  payout_reference VARCHAR(120),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE wallet_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id),
  provider VARCHAR(40) NOT NULL DEFAULT 'truemoney',
  account_masked VARCHAR(40),
  provider_token_ref TEXT,
  status wallet_status NOT NULL DEFAULT 'not_linked',
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE admin_audit_logs (
  id BIGSERIAL PRIMARY KEY,
  actor_user_id UUID REFERENCES users(id),
  action VARCHAR(120) NOT NULL,
  entity_type VARCHAR(80) NOT NULL,
  entity_id VARCHAR(120),
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Production TODO:
-- 1. Enforce admin roles separately; do not rely on client-side visibility.
-- 2. Use Argon2id/bcrypt via a vetted auth library; never store plaintext passwords.
-- 3. Restrict DB roles, encrypt backups, configure retention and access logging.
-- 4. Verify payments against recipient-side statements/provider API before activating plans.
-- 5. Calculate milestone rewards transactionally and prevent duplicate payouts.
-- 6. Do not store wallet PIN/OTP/password. Use only provider-approved account linking/payout flows.
