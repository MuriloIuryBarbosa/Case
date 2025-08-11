import os
import uuid
import random
import string
from datetime import datetime, timedelta, timezone
import pymysql
from dotenv import load_dotenv

load_dotenv()

# ==== Variáveis de conexão (todas vindas do .env) ====
HOST = os.getenv("MYSQL_HOST", "localhost")
PORT = int(os.getenv("MYSQL_PORT", "3306"))
USER = os.getenv("MYSQL_USER", "root")
PASSWORD = os.getenv("MYSQL_PASSWORD", "")
MYSQL_DB = os.getenv("MYSQL_DB", "Case")
MYSQL_TABLE = os.getenv("MYSQL_TABLE", "GA4_GTM")

# ==== Parâmetros do dataset ====
TOTAL = 300
PROBLEMAS_QUALIDADE = 50
ALEATORIO = 42
random.seed(ALEATORIO)

# Domínios de valores saudáveis
EVENTOS_OK = ["page_view", "add_to_cart", "begin_checkout", "purchase"]
CANAIS_OK = [
    "google / cpc", "facebook / cpc", "email / mkt",
    "direct / (none)", "referral / partner"
]
MOEDAS_OK = ["BRL", "USD", "EUR"]
AMBIENTES = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    "Mozilla/5.0 (Linux; Android 13)",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X)"
]

DATA_REFERENCIA = datetime.now(timezone.utc) - timedelta(days=5)  # janela de 5 dias
DATAS_FUTURAS = timedelta(days=3)  # cria eventos futuros

# cria aleatoriamente os eventos ruins a serem registrados
bad_indices = set(random.sample(range(TOTAL), PROBLEMAS_QUALIDADE))

# === Helpers de dados ===
def random_path():
    parts = ["", "home", "plp", "pdp", "checkout", "about", "contact", "search"]
    return "/" + random.choice(parts)

def random_url():
    host = random.choice(["example.com", "shop.local", "site.test"])
    scheme = random.choice(["https", "http"])
    return f"{scheme}://{host}{random_path()}"

# 10 eventos dos 50 serão criados como duplicados
def make_duplicate_ids(k=10):
    return [uuid.uuid4().hex[:16] for _ in range(k)]

DUP_IDS = make_duplicate_ids(k=10)

def pick_event_name(bad=False):
    if not bad:
        return random.choice(EVENTOS_OK)
    return random.choice(["signup", "random_event", "!!!", "purchaseX", "view_page"])

def pick_source_medium(bad=False):
    if bad:
        return None if random.random() < 0.6 else "unknown / ???"
    return random.choice(CANAIS_OK)

def pick_currency(bad=False):
    if bad:
        return random.choice([None, "", "BRLZ", "R$", "###"])
    return random.choice(MOEDAS_OK)

def pick_value(event_name, bad=False):
    if event_name == "purchase":
        if bad:
            return random.choice([None, -10.00, 9999999.99, 0.0])
        return round(random.uniform(10, 2000), 2)
    return None

def pick_transaction_id(event_name, bad=False):
    if event_name == "purchase":
        if bad and random.random() < 0.7:
            return None
        return "tx-" + uuid.uuid4().hex[:10]
    return None

def pick_items(event_name, bad=False):
    if event_name == "purchase":
        if bad and random.random() < 0.5:
            return random.choice([None, -1, 10000])
        return random.randint(1, 7)
    return None

def pick_page_location(bad=False):
    if bad:
        return random.choice([None, "htp:/broken", "://no-scheme", "just-text", ""])
    return random_url()

def pick_session_id(bad=False):
    if bad and random.random() < 0.3:
        return None
    return random.randint(1000, 9999)

def pick_user_pseudo_id():
    return "user_" + "".join(random.choices(string.ascii_lowercase + string.digits, k=6))

def pick_event_ts_and_date(bad=False):
    delta_minutes = random.randint(0, 5 * 24 * 60)
    ts = DATA_REFERENCIA + timedelta(minutes=delta_minutes)
    if bad and random.random() < 0.4:
        ts = datetime.now(timezone.utc) + DATAS_FUTURAS + timedelta(minutes=random.randint(1, 600))
    event_ts = ts.replace(tzinfo=None)  # DATETIME MySQL sem TZ
    return event_ts, event_ts.date()

def pick_event_id(bad=False):
    if bad and random.random() < 0.4:
        return random.choice(DUP_IDS)
    return uuid.uuid4().hex[:16]

def pick_is_mobile():
    return 1 if random.random() < 0.6 else 0

def pick_user_agent():
    return random.choice(AMBIENTES)

def generate_rows():
    rows = []
    for i in range(TOTAL):
        is_bad = i in bad_indices

        event_name = pick_event_name(bad=is_bad)
        source_medium = pick_source_medium(bad=is_bad)
        currency = pick_currency(bad=is_bad)
        event_id = pick_event_id(bad=is_bad)
        event_ts, event_date = pick_event_ts_and_date(bad=is_bad)
        user_pseudo_id = pick_user_pseudo_id()
        session_id = pick_session_id(bad=is_bad)
        page_location = pick_page_location(bad=is_bad)
        is_mobile = pick_is_mobile()
        user_agent = pick_user_agent()
        items = pick_items(event_name, bad=is_bad)
        value = pick_value(event_name, bad=is_bad)
        transaction_id = pick_transaction_id(event_name, bad=is_bad)

        rows.append((
            event_id,
            event_ts.strftime("%Y-%m-%d %H:%M:%S.%f"),
            event_date.strftime("%Y-%m-%d"),
            user_pseudo_id,
            session_id,
            event_name,
            source_medium,
            page_location,
            transaction_id,
            items,
            value,
            currency,
            is_mobile,
            user_agent
        ))
    return rows

INSERT_SQL = f"""
INSERT INTO `{MYSQL_DB}`.`{MYSQL_TABLE}`
(
  event_id, event_ts, event_date, user_pseudo_id, session_id,
  event_name, source_medium, page_location, transaction_id,
  items, value, currency, is_mobile, user_agent
)
VALUES
(
  %s, %s, %s, %s, %s,
  %s, %s, %s, %s,
  %s, %s, %s, %s, %s
)
"""

def main():
    rows = generate_rows()
    conn = pymysql.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD, database=MYSQL_DB,
        charset="utf8mb4", autocommit=False
    )
    try:
        with conn.cursor() as cur:
            # (Opcional) limpar antes:
            # cur.execute(f"TRUNCATE TABLE `{MYSQL_DB}`.`{MYSQL_TABLE}`;")
            cur.executemany(INSERT_SQL, rows)
        conn.commit()
        print(f"✅ Inseridos {len(rows)} registros em `{MYSQL_DB}`.`{MYSQL_TABLE}`")
        print(f"🔎 Desses, {PROBLEMAS_QUALIDADE} possuem problemas de qualidade (nulos, duplicatas, futuros etc.).")
    except Exception as e:
        conn.rollback()
        print("❌ Erro ao inserir registros:", e)
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    main()
