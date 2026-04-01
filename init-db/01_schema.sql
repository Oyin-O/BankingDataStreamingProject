CREATE SCHEMA banking;

CREATE TABLE banking.banks (
    bank_id       SERIAL PRIMARY KEY,
    bank_name     VARCHAR(100),
    country       VARCHAR(50),
    swift_code    VARCHAR(20) UNIQUE
);

CREATE TABLE banking.customers (
    customer_id   SERIAL PRIMARY KEY,
    full_name     VARCHAR(100),
    email         VARCHAR(100) UNIQUE,
    phone         VARCHAR(20),
    nationality   VARCHAR(50),
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE banking.accounts (
    account_id    SERIAL PRIMARY KEY,
    customer_id   INTEGER REFERENCES banking.customers(customer_id),
    bank_id       INTEGER REFERENCES banking.banks(bank_id),
    account_type  VARCHAR(20),
    balance       DECIMAL(12,2) DEFAULT 0.00,
    currency      VARCHAR(10) DEFAULT 'GBP',
    account_status VARCHAR(20) DEFAULT 'active',
    opened_at     TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE banking.currencies (
    currency_code   VARCHAR(10) PRIMARY KEY,
    currency_name   VARCHAR(50),
    rate_to_usd     DECIMAL(10,6),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE banking.transactions (
    transaction_id    SERIAL PRIMARY KEY,
    account_id        INTEGER REFERENCES banking.accounts(account_id),
    type              VARCHAR(20),
    amount            DECIMAL(12,2),
    currency          VARCHAR(10),
    exchange_rate     DECIMAL(10,6) DEFAULT 1.000000,
    amount_in_usd     DECIMAL(12,2),
    status            VARCHAR(20) DEFAULT 'pending',
    channel           VARCHAR(20),
    country           VARCHAR(50),
    city              VARCHAR(50),
    description       VARCHAR(255),
    created_at        TIMESTAMP DEFAULT NOW(),
    updated_at        TIMESTAMP DEFAULT NOW()
);

CREATE TABLE banking.transaction_legs (
    leg_id                      SERIAL PRIMARY KEY,
    transaction_id              INTEGER REFERENCES banking.transactions(transaction_id),
    direction                   VARCHAR(10),
    account_id                  INTEGER REFERENCES banking.accounts(account_id),
    bank_id                     INTEGER REFERENCES banking.banks(bank_id),
    external_account_reference  VARCHAR(50),
    external_account_name       VARCHAR(100),
    amount                      DECIMAL(12,2),
    currency                    VARCHAR(10)
);

-- STATIC DATA

INSERT INTO banking.banks (bank_name, country, swift_code) VALUES
('HSBC',          'United Kingdom', 'HBUKGB4B'),
('Chase',         'United States',  'CHASUS33'),
('Barclays',      'United Kingdom', 'BUKBGB22'),
('Deutsche Bank', 'Germany',        'DEUTDEDB'),
('Access Bank',   'Nigeria',        'ABNGNGLA');

INSERT INTO banking.currencies (currency_code, currency_name, rate_to_usd) VALUES
('USD', 'US Dollar',       1.000000),
('GBP', 'British Pound',   1.270000),
('EUR', 'Euro',            1.080000),
('NGN', 'Nigerian Naira',  0.000625),
('CAD', 'Canadian Dollar', 0.740000);


-- PUBLICATION FOR DEBEZIUM CDC

CREATE PUBLICATION debezium_publication FOR TABLE
    banking.customers,
    banking.accounts,
    banking.transactions,
    banking.transaction_legs;
