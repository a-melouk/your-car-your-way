-- Nettoyage optionnel (à décommenter si besoin de reset)
-- DROP SCHEMA public CASCADE;
-- CREATE SCHEMA public;

-- 1. ENUMS (Pour une gestion stricte des statuts)
CREATE TYPE user_role AS ENUM ('CLIENT', 'STAFF', 'ADMIN');
CREATE TYPE vehicle_status AS ENUM ('AVAILABLE', 'RENTED', 'MAINTENANCE', 'RETIRED');
CREATE TYPE reservation_status AS ENUM ('PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE chat_session_status AS ENUM ('OPEN', 'CLOSED', 'ARCHIVED');
CREATE TYPE sender_type AS ENUM ('CLIENT', 'SUPPORT_AGENT', 'SYSTEM');
CREATE TYPE invoice_status AS ENUM ('ISSUED', 'PAID', 'REFUNDED');

-- 2. TABLE USERS
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- Stocker le hash BCrypt ici
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    mfa_secret VARCHAR(255),             -- Clé secrète pour 2FA
    language_pref VARCHAR(10) DEFAULT 'en',
    role user_role NOT NULL DEFAULT 'CLIENT',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABLE AGENCIES
CREATE TABLE agencies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    city_code VARCHAR(50) NOT NULL,      -- Ex: 'PAR', 'LON'
    geo_location VARCHAR(100),           -- Ex: '48.8566,2.3522'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABLE VEHICLES
CREATE TABLE vehicles (
    id SERIAL PRIMARY KEY,
    vin VARCHAR(17) NOT NULL UNIQUE,     -- Code VIN standard (17 chars)
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    acriss_code VARCHAR(4) NOT NULL,     -- Standard de classification
    status vehicle_status NOT NULL DEFAULT 'AVAILABLE',
    agency_id INTEGER NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. TABLE RESERVATIONS
-- Le cœur du système
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    status reservation_status NOT NULL DEFAULT 'PENDING',
    total_price DECIMAL(10, 2) NOT NULL CHECK (total_price >= 0),

    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,

    -- Support de l'aller simple (Agences différentes)
    pickup_agency_id INTEGER NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,
    return_agency_id INTEGER NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Contrainte logique : la fin doit être après le début
    CONSTRAINT check_dates CHECK (end_date > start_date)
);

-- 6. TABLE PAYMENTS
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    stripe_ref VARCHAR(255) NOT NULL UNIQUE, -- Référence transaction Stripe
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,             -- Ex: 'succeeded', 'pending'
    reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. TABLE INVOICES
CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    pdf_url TEXT NOT NULL,
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    reservation_id INTEGER NOT NULL UNIQUE REFERENCES reservations(id) ON DELETE RESTRICT
    -- UNIQUE ici car 1 Réservation = 1 Facture finale
);

-- 8. TABLE FAVORITES
-- Gestion polymorphique simple via contrainte CHECK
CREATE TABLE favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),

    -- On doit liker SOIT un véhicule, SOIT une agence, pas les deux, ni aucun
    CONSTRAINT check_target CHECK (
        (vehicle_id IS NOT NULL AND agency_id IS NULL) OR
        (vehicle_id IS NULL AND agency_id IS NOT NULL)
    )
);

-- 9. TABLE CHAT_SESSIONS
CREATE TABLE chat_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status chat_session_status NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. TABLE CHAT_MESSAGES
CREATE TABLE chat_messages (
    id SERIAL PRIMARY KEY,
    chat_session_id INTEGER NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL, -- L'auteur (Client ou Agent)
    content TEXT NOT NULL,
    sender_type sender_type NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- INDEXES (Pour la performance en production)
-- PostgreSQL n'indexe pas automatiquement les FKs
-- ================================================================

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_vehicles_agency ON vehicles(agency_id);
CREATE INDEX idx_vehicles_status ON vehicles(status);
CREATE INDEX idx_reservations_user ON reservations(user_id);
CREATE INDEX idx_reservations_dates ON reservations(start_date, end_date);
CREATE INDEX idx_payments_reservation ON payments(reservation_id);
CREATE INDEX idx_chat_messages_session ON chat_messages(chat_session_id);