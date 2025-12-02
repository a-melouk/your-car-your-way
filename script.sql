-- ================================================================
-- YOUR CAR YOUR WAY - SCHÉMA FINAL 3NF (PostgreSQL)
-- Version corrigée : Respect strict de la 3NF
-- Séparation VEHICLE_ACRISS (référentiel) et CAR_MODEL
-- ================================================================

-- Nettoyage optionnel (à décommenter si besoin de reset)
-- DROP SCHEMA public CASCADE;
-- CREATE SCHEMA public;

-- 1. ENUMS & TYPES (Pour une gestion stricte des statuts)
CREATE TYPE user_role AS ENUM ('CLIENT', 'STAFF', 'ADMIN');
CREATE TYPE vehicle_status AS ENUM ('AVAILABLE', 'RENTED', 'MAINTENANCE', 'RETIRED');
CREATE TYPE reservation_status AS ENUM ('PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE invoice_status AS ENUM ('ISSUED', 'PAID', 'REFUNDED');
CREATE TYPE chat_session_status AS ENUM ('OPEN', 'CLOSED', 'ARCHIVED');
CREATE TYPE sender_type AS ENUM ('CLIENT', 'SUPPORT_AGENT', 'SYSTEM');
CREATE TYPE payment_type AS ENUM ('DEPOSIT', 'BALANCE', 'REFUND');

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

-- 4. TABLE VEHICLE_ACRISS (Référentiel des codes ACRISS)
-- Table de référence normalisée selon la norme ACRISS
-- https://www.acriss.org/car-codes/
CREATE TABLE vehicle_acriss (
    code VARCHAR(4) PRIMARY KEY,         -- Ex: 'ECMR', 'LDAR'
    category VARCHAR(20) NOT NULL,       -- Ex: 'Economy', 'Luxury', 'SUV'
    type VARCHAR(50) NOT NULL,           -- Ex: '2-4 Door', '4-5 Door', 'Passenger Van'
    transmission VARCHAR(20) NOT NULL,   -- Ex: 'Manual', 'Automatic'
    fuel_ac VARCHAR(50) NOT NULL,        -- Ex: 'Petrol/AC', 'Diesel/AC', 'Electric/AC'
    description TEXT,                    -- Description standardisée complète du code ACRISS
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. TABLE CAR_MODELS
-- Centralise la marque, le modèle et la référence ACRISS
-- RESPECTE LA 3NF : category n'est PAS dupliqué ici (il vient de vehicle_acriss)
CREATE TABLE car_models (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,          -- Ex: 'Renault', 'BMW', 'Tesla'
    model VARCHAR(50) NOT NULL,          -- Ex: 'Clio', 'X5', 'Model 3'
    description TEXT,                    -- Description commerciale/marketing spécifique à YCYW
    acriss_code VARCHAR(4) NOT NULL REFERENCES vehicle_acriss(code) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Contrainte pour éviter d'avoir deux fois "Renault Clio"
    UNIQUE(brand, model)
);

-- 6. TABLE VEHICLES
CREATE TABLE vehicles (
    id SERIAL PRIMARY KEY,
    vin VARCHAR(17) NOT NULL UNIQUE,     -- Vehicle Identification Number

    -- Lien vers le modèle (qui contient la référence ACRISS)
    model_id INTEGER NOT NULL REFERENCES car_models(id) ON DELETE RESTRICT,

    status vehicle_status NOT NULL DEFAULT 'AVAILABLE',
    agency_id INTEGER NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. TABLE OFFERS
-- L'offre définit le prix et la disponibilité du véhicule pour une période
-- Permet d'avoir des tarifs dynamiques selon les saisons
CREATE TABLE offers (
    id SERIAL PRIMARY KEY,
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    daily_rate DECIMAL(10, 2) NOT NULL CHECK (daily_rate > 0),

    valid_from DATE NOT NULL,
    valid_until DATE NOT NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT check_offer_dates CHECK (valid_until >= valid_from)
);

-- 8. TABLE RESERVATIONS
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE RESTRICT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    status reservation_status NOT NULL DEFAULT 'PENDING',
    -- Prix figé au moment de la réservation (calculé via l'application depuis offers.daily_rate * jours)
    total_price DECIMAL(10, 2) NOT NULL,
    pickup_agency_id INTEGER NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,
    return_agency_id INTEGER NOT NULL REFERENCES agencies(id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Contrainte logique : la fin doit être après le début
    CONSTRAINT check_dates CHECK (end_date > start_date)
);

-- 9. TABLE PAYMENTS
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    stripe_ref VARCHAR(255) NOT NULL UNIQUE, -- Référence transaction Stripe
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,             -- Ex: 'succeeded', 'pending', 'failed'
    payment_type payment_type NOT NULL,      -- 'DEPOSIT', 'BALANCE', 'REFUND'
    reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT check_positive_amount CHECK (amount > 0)
);

-- 10. TABLE INVOICES
CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    pdf_url TEXT,                            -- Nullable pour gérer la génération asynchrone
    status invoice_status NOT NULL DEFAULT 'ISSUED',
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    reservation_id INTEGER NOT NULL UNIQUE REFERENCES reservations(id) ON DELETE RESTRICT
    -- UNIQUE ici car 1 Réservation = 1 Facture finale
);

-- 11. TABLE FAVORITES
-- Permet aux utilisateurs de marquer leurs véhicules ou agences favoris
CREATE TABLE favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),

    -- Contrainte : un favori doit être SOIT un véhicule SOIT une agence, pas les deux
    CONSTRAINT check_target CHECK (
        (vehicle_id IS NOT NULL AND agency_id IS NULL) OR
        (vehicle_id IS NULL AND agency_id IS NOT NULL)
    )
);

-- 12. TABLE CHAT_SESSIONS
CREATE TABLE chat_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status chat_session_status NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. TABLE CHAT_MESSAGES
CREATE TABLE chat_messages (
    id SERIAL PRIMARY KEY,
    chat_session_id INTEGER NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL, -- L'auteur (Client ou Agent)
    content TEXT NOT NULL,
    sender_type sender_type NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour les favoris (empêche les doublons et améliore les recherches)
-- Empêche un utilisateur d'ajouter 2 fois le même véhicule
CREATE UNIQUE INDEX idx_favorites_user_vehicle
ON favorites(user_id, vehicle_id)
WHERE vehicle_id IS NOT NULL;

-- Empêche un utilisateur d'ajouter 2 fois la même agence
CREATE UNIQUE INDEX idx_favorites_user_agency
ON favorites(user_id, agency_id)
WHERE agency_id IS NOT NULL;

-- COMMENTAIRES SUR LES CHOIX D'INDEX
-- Index partiels (UNIQUE WHERE) pour favorites :
--    Évite les doublons tout en permettant les NULL
--    Plus performant qu'une contrainte UNIQUE classique