import os
import csv
import io
from pathlib import Path

import boto3
import psycopg
from dotenv import load_dotenv


# =============================================================================
# LOAD ENVIRONMENT VARIABLES
# =============================================================================
BASE_DIR = Path(__file__).resolve().parents[1]
ENV_PATH = BASE_DIR / "infra" / "deploy" / ".env"

load_dotenv(ENV_PATH)


# =============================================================================
# S3 CONFIGURATION
# =============================================================================
S3_ENDPOINT_URL = os.getenv("S3_ENDPOINT_URL")
S3_ACCESS_KEY_ID = os.getenv("S3_ACCESS_KEY_ID")
S3_SECRET_ACCESS_KEY = os.getenv("S3_SECRET_ACCESS_KEY")
S3_REGION = os.getenv("S3_REGION", "ru-1")
S3_BUCKET = os.getenv("S3_BUCKET")
S3_PREFIX = os.getenv("S3_PREFIX")


# =============================================================================
# POSTGRES CONFIGURATION
# =============================================================================
PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = int(os.getenv("PG_PORT", "5432"))
PG_DB = os.getenv("PG_DB")
PG_USER = os.getenv("PG_USER")
INGESTION_USER_PASSWORD = os.getenv("INGESTION_USER_PASSWORD")


# =============================================================================
# INGESTION PARAMETERS
# =============================================================================
SOURCE_SYSTEM = os.getenv("SOURCE_SYSTEM", "money_flow_app")
SOURCE_OBJECT = os.getenv("SOURCE_OBJECT", "money_flow")
RAW_TABLE = "raw.money_flow"

CSV_ENCODING = os.getenv("CSV_ENCODING", "utf-8")
CSV_DELIMITER = os.getenv("CSV_DELIMITER", ",")
CSV_QUOTECHAR = os.getenv("CSV_QUOTECHAR", '"')


# =============================================================================
# CSV -> RAW COLUMN MAPPING
# =============================================================================
CSV_TO_RAW_COLUMN_MAP = {
    "Number": "source_number",
    "Date": "transaction_date",
    "Account": "account",
    "Amount": "amount",
    "Currency": "currency",
    "Parent Category": "parent_category",
    "Subcategory": "subcategory",
    "Category": "category",
    "Counterparty": "counterparty",
    "Transfer: Account": "transfer_account",
    "Transfer: Amount": "transfer_amount",
    "Transfer: Currency": "transfer_currency",
    "Tags": "tags",
    "Place": "place",
    "Note": "note",
}


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
def require_env(name: str) -> str:
    """
    Ensure that a required environment variable exists.
    """
    value = os.getenv(name)
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def get_pg_conn_string() -> str:
    """
    Build PostgreSQL connection string.
    """
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


def get_s3_client():
    """
    Create S3 client using configured credentials.
    """
    require_env("S3_ENDPOINT_URL")
    require_env("S3_ACCESS_KEY_ID")
    require_env("S3_SECRET_ACCESS_KEY")
    require_env("S3_BUCKET")
    require_env("S3_PREFIX")

    return boto3.client(
        "s3",
        endpoint_url=S3_ENDPOINT_URL,
        aws_access_key_id=S3_ACCESS_KEY_ID,
        aws_secret_access_key=S3_SECRET_ACCESS_KEY,
        region_name=S3_REGION,
    )


def get_latest_s3_key(s3_client, bucket: str, prefix: str) -> str:
    """
    Find the most recently modified file under the given S3 prefix.
    Returns the object key.
    """
    paginator = s3_client.get_paginator("list_objects_v2")
    latest_object = None

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        contents = page.get("Contents", [])

        for obj in contents:
            key = obj["Key"]

            # Skip directory-like keys if they exist.
            if key.endswith("/"):
                continue

            if latest_object is None or obj["LastModified"] > latest_object["LastModified"]:
                latest_object = obj

    if latest_object is None:
        raise ValueError(
            f"No files found in bucket '{bucket}' with prefix '{prefix}'"
        )

    return latest_object["Key"]


def get_s3_object_metadata(
    s3_client,
    bucket: str,
    key: str,
) -> tuple[int | None, str | None]:
    """
    Retrieve file metadata from S3.
    Returns file size and ETag checksum.
    """
    head = s3_client.head_object(Bucket=bucket, Key=key)

    file_size_bytes = head.get("ContentLength")
    file_checksum = head.get("ETag")

    if file_checksum:
        file_checksum = file_checksum.replace('"', "")

    return file_size_bytes, file_checksum


def download_s3_text(s3_client, bucket: str, key: str) -> str:
    """
    Download file contents from S3 as text.
    """
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read()
    return content.decode(CSV_ENCODING)


def parse_csv_rows(csv_text: str) -> list[dict]:
    """
    Parse CSV text into a list of dictionaries.
    Values are preserved exactly as they come from the source file.
    """
    buffer = io.StringIO(csv_text)
    reader = csv.DictReader(
        buffer,
        delimiter=CSV_DELIMITER,
        quotechar=CSV_QUOTECHAR,
    )

    if reader.fieldnames is None:
        raise ValueError("CSV file is empty or missing header row.")

    rows = []
    for row in reader:
        rows.append(row)

    return rows


def validate_csv_headers(csv_rows: list[dict]) -> None:
    """
    Validate that required CSV columns exist.
    """
    required_headers = set(CSV_TO_RAW_COLUMN_MAP.keys())

    if not csv_rows:
        raise ValueError("CSV file contains header only or has no data rows.")

    headers = set(csv_rows[0].keys())
    missing = required_headers - headers

    if missing:
        missing_str = ", ".join(sorted(missing))
        raise ValueError(f"CSV is missing required columns: {missing_str}")


def transform_row(csv_row: dict, source_file: str, ingestion_id: int) -> tuple:
    """
    Map CSV row to raw.money_flow without business transformations.
    Values are loaded as-is.
    """
    return (
        csv_row.get("Number"),
        csv_row.get("Date"),
        csv_row.get("Account"),
        csv_row.get("Amount"),
        csv_row.get("Currency"),
        csv_row.get("Parent Category"),
        csv_row.get("Subcategory"),
        csv_row.get("Category"),
        csv_row.get("Counterparty"),
        csv_row.get("Transfer: Account"),
        csv_row.get("Transfer: Amount"),
        csv_row.get("Transfer: Currency"),
        csv_row.get("Tags"),
        csv_row.get("Place"),
        csv_row.get("Note"),
        source_file,
        ingestion_id,
    )


# =============================================================================
# REGISTRY FUNCTIONS
# =============================================================================
def get_or_create_registry_record(
    conn,
    source_system: str,
    source_object: str,
    raw_table: str,
    s3_bucket: str,
    s3_key: str,
    file_size_bytes: int | None,
    file_checksum: str | None,
) -> tuple[int, str]:
    """
    Retrieve or create ingestion registry record for the given S3 file.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT ingestion_id, status
            FROM infra.ingestion_file_registry
            WHERE s3_bucket = %s
              AND s3_key = %s
            """,
            (s3_bucket, s3_key),
        )
        existing = cur.fetchone()

        if existing:
            ingestion_id, status = existing
            return ingestion_id, status

        cur.execute(
            """
            INSERT INTO infra.ingestion_file_registry
            (
                source_system,
                source_object,
                raw_table,
                s3_bucket,
                s3_key,
                file_size_bytes,
                file_checksum,
                status
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'pending')
            RETURNING ingestion_id, status
            """,
            (
                source_system,
                source_object,
                raw_table,
                s3_bucket,
                s3_key,
                file_size_bytes,
                file_checksum,
            ),
        )
        created = cur.fetchone()
        return created


def mark_registry_processing(conn, ingestion_id: int) -> None:
    """
    Mark file as processing.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE infra.ingestion_file_registry
            SET status = 'processing',
                started_at = NOW(),
                finished_at = NULL,
                error_message = NULL
            WHERE ingestion_id = %s
            """,
            (ingestion_id,),
        )


def mark_registry_loaded(conn, ingestion_id: int, rows_loaded: int) -> None:
    """
    Mark file as loaded successfully.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE infra.ingestion_file_registry
            SET status = 'loaded',
                rows_loaded = %s,
                finished_at = NOW(),
                error_message = NULL
            WHERE ingestion_id = %s
            """,
            (rows_loaded, ingestion_id),
        )


def mark_registry_failed(conn, ingestion_id: int, error_message: str) -> None:
    """
    Mark file as failed.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE infra.ingestion_file_registry
            SET status = 'failed',
                error_message = LEFT(%s, 4000),
                finished_at = NOW()
            WHERE ingestion_id = %s
            """,
            (error_message, ingestion_id),
        )


# =============================================================================
# RAW LOAD FUNCTION
# =============================================================================
def insert_rows_to_raw_money_flow(conn, rows: list[tuple]) -> int:
    """
    Insert prepared rows into raw.money_flow.
    Returns number of inserted rows.
    """
    if not rows:
        return 0

    insert_sql = """
        INSERT INTO raw.money_flow
        (
            source_number,
            transaction_date,
            account,
            amount,
            currency,
            parent_category,
            subcategory,
            category,
            counterparty,
            transfer_account,
            transfer_amount,
            transfer_currency,
            tags,
            place,
            note,
            source_file,
            ingestion_id
        )
        VALUES
        (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s
        )
    """

    with conn.cursor() as cur:
        cur.executemany(insert_sql, rows)

    return len(rows)


# =============================================================================
# MAIN INGESTION FLOW
# =============================================================================
def load_money_flow_from_s3() -> str:
    """
    Full ingestion flow:
    1. Find latest file in S3 prefix
    2. Register file in ingestion registry
    3. Skip loading if the file has already been loaded
    4. Download CSV
    5. Validate headers
    6. Transform rows without business processing
    7. Insert into raw.money_flow
    8. Update registry status
    9. Return ingestion result: "loaded" or "skipped"
    """
    s3_client = get_s3_client()
    conn_string = get_pg_conn_string()

    s3_key = get_latest_s3_key(s3_client, S3_BUCKET, S3_PREFIX)
    file_size_bytes, file_checksum = get_s3_object_metadata(
        s3_client,
        S3_BUCKET,
        s3_key,
    )

    ingestion_id = None

    try:
        with psycopg.connect(conn_string) as conn:
            conn.autocommit = False

            ingestion_id, current_status = get_or_create_registry_record(
                conn=conn,
                source_system=SOURCE_SYSTEM,
                source_object=SOURCE_OBJECT,
                raw_table=RAW_TABLE,
                s3_bucket=S3_BUCKET,
                s3_key=s3_key,
                file_size_bytes=file_size_bytes,
                file_checksum=file_checksum,
            )
            conn.commit()

            if current_status == "loaded":
                print(
                    f"The latest file has already been loaded: "
                    f"s3://{S3_BUCKET}/{s3_key} "
                    f"(ingestion_id={ingestion_id})"
                )
                return "skipped"

            mark_registry_processing(conn, ingestion_id)
            conn.commit()

            csv_text = download_s3_text(s3_client, S3_BUCKET, s3_key)
            csv_rows = parse_csv_rows(csv_text)

            validate_csv_headers(csv_rows)

            prepared_rows = []
            for csv_row in csv_rows:
                prepared_rows.append(
                    transform_row(csv_row, s3_key, ingestion_id)
                )

            rows_loaded = insert_rows_to_raw_money_flow(conn, prepared_rows)
            mark_registry_loaded(conn, ingestion_id, rows_loaded)
            conn.commit()

            print("Load completed successfully.")
            print(f"ENV file: {ENV_PATH}")
            print(f"ingestion_id: {ingestion_id}")
            print(f"Loaded file: s3://{S3_BUCKET}/{s3_key}")
            print(f"Rows loaded: {rows_loaded}")

            return "loaded"

    except Exception as exc:
        if ingestion_id is not None:
            try:
                with psycopg.connect(conn_string) as conn:
                    mark_registry_failed(conn, ingestion_id, str(exc))
                    conn.commit()
            except Exception as registry_exc:
                print("Failed to write error into ingestion registry.")
                print(f"Original error: {exc}")
                print(f"Registry update error: {registry_exc}")

        raise


if __name__ == "__main__":
    load_money_flow_from_s3()
