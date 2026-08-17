import os
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import psycopg
from dotenv import load_dotenv


# =============================================================================
# LOAD ENVIRONMENT VARIABLES
# =============================================================================
BASE_DIR = Path(__file__).resolve().parents[1]
ENV_PATH = BASE_DIR / "infra" / "deploy" / ".env"

load_dotenv(ENV_PATH)

# =============================================================================
# POSTGRES CONFIGURATION
# =============================================================================
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = int(os.getenv("PG_PORT", "5432"))
PG_DB = os.getenv("PG_DB")
PG_USER = os.getenv("PG_USER")
INGESTION_USER_PASSWORD = os.getenv("INGESTION_USER_PASSWORD")

# =============================================================================
# FX CONFIGURATION
# =============================================================================
FX_SOURCE = os.getenv("FX_SOURCE", "cbr").strip().lower()
FX_CURRENCIES = tuple(
    dict.fromkeys(
        currency.strip().upper()
        for currency in os.getenv("FX_CURRENCIES", "USD,KGS").split(",")
        if currency.strip()
    )
)
FX_REFRESH_INTERVAL_MINUTES = int(os.getenv("FX_REFRESH_INTERVAL_MINUTES", "360"))
FX_INITIAL_LOOKBACK_DAYS = int(os.getenv("FX_INITIAL_LOOKBACK_DAYS", "14"))
FX_RELOAD_LOOKBACK_DAYS = int(os.getenv("FX_RELOAD_LOOKBACK_DAYS", "7"))
FX_HTTP_TIMEOUT_SECONDS = int(os.getenv("FX_HTTP_TIMEOUT_SECONDS", "30"))

RAW_TABLE = "raw.exchange_rate"
STATE_TABLE = "infra.fx_ingestion_state"

CBR_CATALOG_URL = "https://www.cbr.ru/scripts/XML_daily.asp"
CBR_DYNAMIC_URL = "https://www.cbr.ru/scripts/XML_dynamic.asp"

SOURCE_REFERENCE_CURRENCY = {
    "cbr": "RUB",
}


@dataclass(frozen=True)
class ExchangeRateRow:
    source: str
    source_rate_key: str
    rate_date_text: str
    rate_date: date
    base_currency: str
    base_amount: str
    quote_currency: str
    quote_amount: str


@dataclass(frozen=True)
class FxState:
    last_checked_at: datetime | None
    last_requested_through: date | None
    last_rate_date: date | None


# =============================================================================
# COMMON HELPERS
# =============================================================================
def require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def get_pg_conn_string() -> str:
    require_env("PG_DB")
    require_env("PG_USER")
    require_env("INGESTION_USER_PASSWORD")

    return (
        f"host={PG_HOST} "
        f"port={PG_PORT} "
        f"dbname={PG_DB} "
        f"user={PG_USER} "
        f"password={INGESTION_USER_PASSWORD}"
    )


def validate_configuration() -> None:
    if FX_SOURCE not in SOURCE_REFERENCE_CURRENCY:
        supported = ", ".join(sorted(SOURCE_REFERENCE_CURRENCY))
        raise ValueError(
            f"Unsupported FX_SOURCE='{FX_SOURCE}'. Supported sources: {supported}"
        )

    if not FX_CURRENCIES:
        raise ValueError("FX_CURRENCIES must contain at least one currency code.")

    if FX_REFRESH_INTERVAL_MINUTES < 1:
        raise ValueError("FX_REFRESH_INTERVAL_MINUTES must be greater than 0.")

    if FX_INITIAL_LOOKBACK_DAYS < 0:
        raise ValueError("FX_INITIAL_LOOKBACK_DAYS cannot be negative.")

    if FX_RELOAD_LOOKBACK_DAYS < 0:
        raise ValueError("FX_RELOAD_LOOKBACK_DAYS cannot be negative.")

    if FX_HTTP_TIMEOUT_SECONDS < 1:
        raise ValueError("FX_HTTP_TIMEOUT_SECONDS must be greater than 0.")


def download_bytes(url: str) -> bytes:
    request = Request(
        url,
        headers={"User-Agent": "finance-analytics/1.0"},
    )

    with urlopen(request, timeout=FX_HTTP_TIMEOUT_SECONDS) as response:
        return response.read()


def get_initial_start_date(conn) -> date:
    """
    Start the first FX history load shortly before the first Money Flow transaction.
    The lookback ensures that a previous official rate exists for weekends/holidays.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT MIN(
                TO_TIMESTAMP(transaction_date, 'YYYY-MM-DD HH24:MI:SS')::DATE
            )
            FROM raw.money_flow
            WHERE NULLIF(BTRIM(transaction_date), '') IS NOT NULL
            """
        )
        first_transaction_date = cur.fetchone()[0]

    if first_transaction_date is None:
        return date.today() - timedelta(days=FX_INITIAL_LOOKBACK_DAYS)

    return first_transaction_date - timedelta(days=FX_INITIAL_LOOKBACK_DAYS)


# =============================================================================
# INGESTION STATE
# =============================================================================
def get_fx_state(conn, source: str, currency_code: str) -> FxState:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT
                last_checked_at,
                last_requested_through,
                last_rate_date
            FROM {STATE_TABLE}
            WHERE source = %s
              AND currency_code = %s
            """,
            (source, currency_code),
        )
        row = cur.fetchone()

    if row is None:
        return FxState(
            last_checked_at=None,
            last_requested_through=None,
            last_rate_date=None,
        )

    return FxState(
        last_checked_at=row[0],
        last_requested_through=row[1],
        last_rate_date=row[2],
    )


def refresh_is_due(state: FxState) -> bool:
    if state.last_checked_at is None:
        return True

    now = datetime.now(timezone.utc)
    last_checked_at = state.last_checked_at

    if last_checked_at.tzinfo is None:
        last_checked_at = last_checked_at.replace(tzinfo=timezone.utc)

    return now - last_checked_at >= timedelta(minutes=FX_REFRESH_INTERVAL_MINUTES)


def get_request_start_date(state: FxState, initial_start_date: date) -> date:
    if state.last_requested_through is None:
        return initial_start_date

    return state.last_requested_through - timedelta(days=FX_RELOAD_LOOKBACK_DAYS)


def update_fx_state(
    conn,
    source: str,
    currency_code: str,
    requested_through: date,
    last_rate_date: date | None,
    rows_affected: int,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            INSERT INTO {STATE_TABLE}
            (
                source,
                currency_code,
                last_checked_at,
                last_requested_through,
                last_rate_date,
                last_rows_affected,
                updated_at
            )
            VALUES (%s, %s, NOW(), %s, %s, %s, NOW())
            ON CONFLICT (source, currency_code)
            DO UPDATE SET
                last_checked_at = EXCLUDED.last_checked_at,
                last_requested_through = EXCLUDED.last_requested_through,
                last_rate_date = EXCLUDED.last_rate_date,
                last_rows_affected = EXCLUDED.last_rows_affected,
                updated_at = EXCLUDED.updated_at
            """,
            (
                source,
                currency_code,
                requested_through,
                last_rate_date,
                rows_affected,
            ),
        )


# =============================================================================
# CBR PROVIDER
# =============================================================================
def fetch_cbr_currency_catalog() -> dict[str, str]:
    """
    Return a mapping such as {"USD": "R01235", "KGS": "R01370"}.
    The mapping is read from the current official CBR daily XML document.
    """
    xml_data = download_bytes(CBR_CATALOG_URL)
    root = ET.fromstring(xml_data)

    catalog: dict[str, str] = {}

    for valute in root.findall("Valute"):
        currency_code = (valute.findtext("CharCode") or "").strip().upper()
        currency_id = (valute.attrib.get("ID") or "").strip()

        if currency_code and currency_id:
            catalog[currency_code] = currency_id

    return catalog


def fetch_cbr_rates(
    currency_code: str,
    start_date: date,
    end_date: date,
    catalog: dict[str, str],
) -> list[ExchangeRateRow]:
    currency_id = catalog.get(currency_code)

    if currency_id is None:
        raise ValueError(
            f"Currency '{currency_code}' is not available in the current CBR catalog."
        )

    params = urlencode(
        {
            "date_req1": start_date.strftime("%d/%m/%Y"),
            "date_req2": end_date.strftime("%d/%m/%Y"),
            "VAL_NM_RQ": currency_id,
        }
    )
    xml_data = download_bytes(f"{CBR_DYNAMIC_URL}?{params}")
    root = ET.fromstring(xml_data)

    rows: list[ExchangeRateRow] = []

    for record in root.findall("Record"):
        rate_date_text = record.attrib["Date"].strip()
        nominal = (record.findtext("Nominal") or "").strip()
        value = (record.findtext("Value") or "").strip()

        if not nominal or not value:
            continue

        rows.append(
            ExchangeRateRow(
                source="cbr",
                source_rate_key=currency_id,
                rate_date_text=rate_date_text,
                rate_date=datetime.strptime(rate_date_text, "%d.%m.%Y").date(),
                base_currency=currency_code,
                base_amount=nominal,
                quote_currency="RUB",
                quote_amount=value,
            )
        )

    return rows


# =============================================================================
# RAW LOAD
# =============================================================================
def upsert_exchange_rates(conn, rows: list[ExchangeRateRow]) -> int:
    if not rows:
        return 0

    sql = f"""
        INSERT INTO {RAW_TABLE} AS target
        (
            source,
            source_rate_key,
            rate_date,
            base_currency,
            base_amount,
            quote_currency,
            quote_amount
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT
        (
            source,
            rate_date,
            base_currency,
            quote_currency
        )
        DO UPDATE SET
            source_rate_key = EXCLUDED.source_rate_key,
            base_amount = EXCLUDED.base_amount,
            quote_amount = EXCLUDED.quote_amount,
            ingested_at = NOW(),
            ingested_by = CURRENT_USER
        WHERE
            target.source_rate_key IS DISTINCT FROM EXCLUDED.source_rate_key
            OR target.base_amount IS DISTINCT FROM EXCLUDED.base_amount
            OR target.quote_amount IS DISTINCT FROM EXCLUDED.quote_amount
    """

    prepared_rows = [
        (
            row.source,
            row.source_rate_key,
            row.rate_date_text,
            row.base_currency,
            row.base_amount,
            row.quote_currency,
            row.quote_amount,
        )
        for row in rows
    ]

    with conn.cursor() as cur:
        cur.executemany(sql, prepared_rows)
        return cur.rowcount


# =============================================================================
# MAIN INGESTION FLOW
# =============================================================================
def load_exchange_rates() -> str:
    """
    Incrementally load official exchange rates into raw.exchange_rate.

    Returns:
        "loaded"  - at least one raw rate row was inserted or changed
        "skipped" - refresh interval has not elapsed or source data did not change
    """
    validate_configuration()

    conn_string = get_pg_conn_string()
    reference_currency = SOURCE_REFERENCE_CURRENCY[FX_SOURCE]
    requested_currencies = tuple(
        currency for currency in FX_CURRENCIES if currency != reference_currency
    )

    if not requested_currencies:
        print(
            f"No FX API requests are required: all configured currencies are "
            f"equal to the {FX_SOURCE.upper()} reference currency "
            f"({reference_currency})."
        )
        return "skipped"

    end_date = date.today()
    total_rows_affected = 0

    with psycopg.connect(conn_string) as conn:
        conn.autocommit = False

        initial_start_date = get_initial_start_date(conn)

        states = {
            currency: get_fx_state(conn, FX_SOURCE, currency)
            for currency in requested_currencies
        }

        due_currencies = [
            currency
            for currency, state in states.items()
            if refresh_is_due(state)
        ]

        if not due_currencies:
            print(
                "Exchange-rate refresh is not due yet. "
                f"Source: {FX_SOURCE}; currencies: {', '.join(requested_currencies)}"
            )
            return "skipped"

        cbr_catalog = fetch_cbr_currency_catalog() if FX_SOURCE == "cbr" else None

        for currency_code in due_currencies:
            state = states[currency_code]
            start_date = get_request_start_date(state, initial_start_date)

            if start_date > end_date:
                start_date = end_date

            if FX_SOURCE == "cbr":
                rows = fetch_cbr_rates(
                    currency_code=currency_code,
                    start_date=start_date,
                    end_date=end_date,
                    catalog=cbr_catalog,
                )
            else:
                raise ValueError(f"Unsupported FX source: {FX_SOURCE}")

            if not rows and state.last_requested_through is None:
                raise ValueError(
                    f"{FX_SOURCE.upper()} returned no exchange rates for "
                    f"{currency_code} in {start_date}..{end_date}. "
                    "The currency may not be supported by this source."
                )

            rows_affected = upsert_exchange_rates(conn, rows)
            total_rows_affected += rows_affected

            fetched_last_rate_date = max(
                (row.rate_date for row in rows),
                default=None,
            )

            if state.last_rate_date is None:
                last_rate_date = fetched_last_rate_date
            elif fetched_last_rate_date is None:
                last_rate_date = state.last_rate_date
            else:
                last_rate_date = max(state.last_rate_date, fetched_last_rate_date)

            update_fx_state(
                conn=conn,
                source=FX_SOURCE,
                currency_code=currency_code,
                requested_through=end_date,
                last_rate_date=last_rate_date,
                rows_affected=rows_affected,
            )

        conn.commit()

    if total_rows_affected == 0:
        print(
            "Exchange-rate source checked successfully; no raw rates changed. "
            f"Source: {FX_SOURCE}"
        )
        return "skipped"

    print(
        "Exchange-rate ingestion completed successfully. "
        f"Source: {FX_SOURCE}; rows inserted/updated: {total_rows_affected}"
    )
    return "loaded"


if __name__ == "__main__":
    load_exchange_rates()
