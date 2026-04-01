import psycopg2
import random
import time
from faker import Faker
import os
from dotenv import load_dotenv

load_dotenv()
fake = Faker('en_GB')


conn = psycopg2.connect(
    host=os.getenv("POSTGRES_HOST"),
    port=os.getenv("POSTGRES_PORT"),
    database=os.getenv("POSTGRES_DB"),
    user=os.getenv("POSTGRES_USER"),
    password=os.getenv("POSTGRES_PASSWORD")
)

conn.autocommit = True
cur = conn.cursor()

NATIONALITIES = [
    'British', 'Nigerian', 'Indian', 'Polish', 'Ghanaian',
    'Pakistani', 'Bangladeshi', 'Chinese', 'Romanian', 'Jamaican'
]

ACCOUNT_TYPES = ['current', 'savings']
CHANNELS = ['online', 'mobile', 'atm', 'branch', 'card']
TRANSACTION_TYPES = ['deposit', 'withdrawal', 'transfer']
STATUSES = ['pending', 'completed', 'failed']
ACCOUNT_STATUSES = ['active', 'active', 'active', 'frozen', 'dormant']


def create_customer():
    cur.execute("""
        INSERT INTO banking.customers (full_name, email, phone, nationality)
        VALUES (%s, %s, %s, %s)
        RETURNING customer_id
    """, (
        fake.name(),
        fake.unique.email(),
        fake.phone_number(),
        random.choice(NATIONALITIES)
    ))
    return cur.fetchone()[0]


def create_account(customer_id):
    cur.execute("""
        INSERT INTO banking.accounts (customer_id, bank_id, account_type, balance, currency, account_status)
        VALUES (%s, 1, %s, %s, 'GBP', %s)
        RETURNING account_id
    """, (
        customer_id,
        random.choice(ACCOUNT_TYPES),
        round(random.uniform(100, 10000), 2),
        random.choice(ACCOUNT_STATUSES)
    ))
    return cur.fetchone()[0]


def create_transaction(account_id):
    amount = round(random.uniform(5, 2000), 2)
    txn_type = random.choice(TRANSACTION_TYPES)
    status = random.choices(STATUSES, weights=[20, 70, 10])[0]

    cur.execute("""
        INSERT INTO banking.transactions
        (account_id, type, amount, currency, exchange_rate, amount_in_usd,
         status, channel, country, city, description)
        VALUES (%s, %s, %s, 'GBP', 1.27, %s, %s, %s, 'United Kingdom', %s, %s)
        RETURNING transaction_id
    """, (
        account_id,
        txn_type,
        amount,
        round(amount * 1.27, 2),
        status,
        random.choice(CHANNELS),
        fake.city(),
        fake.bs()
    ))
    return cur.fetchone()[0], amount


def create_transaction_legs(transaction_id, account_id, amount):
    # Debit leg — our customer
    cur.execute("""
        INSERT INTO banking.transaction_legs
        (transaction_id, direction, account_id, bank_id, amount, currency)
        VALUES (%s, 'debit', %s, 1, %s, 'GBP')
    """, (transaction_id, account_id, amount))

    # Credit leg — external bank
    external_bank_id = random.choice([2, 3, 4, 5])
    cur.execute("""
        INSERT INTO banking.transaction_legs
        (transaction_id, direction, account_id, bank_id,
         external_account_reference, external_account_name, amount, currency)
        VALUES (%s, 'credit', NULL, %s, %s, %s, %s, 'GBP')
    """, (
        transaction_id,
        external_bank_id,
        fake.iban(),
        fake.name(),
        amount
    ))


def update_account_status():
    """Simulate account status changes."""
    cur.execute("""
        SELECT account_id, account_status 
        FROM banking.accounts 
        ORDER BY RANDOM() LIMIT 1
    """)
    row = cur.fetchone()
    if not row:
        return
    account_id, current_status = row
    new_status = random.choice(['active', 'frozen', 'dormant', 'closed'])
    cur.execute("""
        UPDATE banking.accounts 
        SET account_status = %s, updated_at = NOW()
        WHERE account_id = %s
    """, (new_status, account_id))

# ─────────────────────────────
# Seed initial customers
# ─────────────────────────────
print("Creating initial customers and accounts...")
account_ids = []
for _ in range(20):
    cid = create_customer()
    aid = create_account(cid)
    account_ids.append(aid)
    print(f"  Created customer {cid} → account {aid}")

print(f"{len(account_ids)} accounts ready")
print("Starting transaction stream...\n")

# ─────────────────────────────
# Continuous transaction stream
# ─────────────────────────────
count = 0
while True:
    try:
        account_id = random.choice(account_ids)
        txn_id, amount = create_transaction(account_id)
        create_transaction_legs(txn_id, account_id, amount)
        count += 1
        print(f"[{count}] Transaction {txn_id} → account {account_id}")
        time.sleep(random.uniform(0.5, 2))
    except KeyboardInterrupt:
        print("\nStopped.")
        break
    except Exception as e:
        print(f"Error: {e}")
        time.sleep(2)
