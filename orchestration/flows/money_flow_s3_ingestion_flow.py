from pathlib import Path
import subprocess

from prefect import flow, get_run_logger, task

from ingestion.load_exchange_rates import load_exchange_rates
from ingestion.load_money_flow_from_s3 import load_money_flow_from_s3


PROJECT_ROOT = Path("/opt/finance_analytics")
VALID_INGESTION_RESULTS = {"loaded", "skipped"}


@task(name="load-money-flow-from-s3", retries=2, retry_delay_seconds=60)
def run_money_flow_ingestion() -> str:
    logger = get_run_logger()

    ingestion_result = load_money_flow_from_s3()

    logger.info("Money Flow ingestion result: %s", ingestion_result)

    return ingestion_result


@task(name="load-exchange-rates", retries=2, retry_delay_seconds=60)
def run_exchange_rate_ingestion() -> str:
    logger = get_run_logger()

    ingestion_result = load_exchange_rates()

    logger.info("Exchange-rate ingestion result: %s", ingestion_result)

    return ingestion_result


@task(name="run-dbt-build", retries=1, retry_delay_seconds=60)
def run_dbt_build(
    money_flow_result: str,
    exchange_rate_result: str,
) -> None:
    logger = get_run_logger()

    if money_flow_result not in VALID_INGESTION_RESULTS:
        raise ValueError(
            f"Unexpected Money Flow ingestion result: {money_flow_result}"
        )

    if exchange_rate_result not in VALID_INGESTION_RESULTS:
        raise ValueError(
            f"Unexpected exchange-rate ingestion result: {exchange_rate_result}"
        )

    if money_flow_result == "skipped" and exchange_rate_result == "skipped":
        logger.info("No source data changed. Skipping dbt build.")
        return

    logger.info(
        "Starting dbt build. Money Flow: %s; exchange rates: %s",
        money_flow_result,
        exchange_rate_result,
    )

    subprocess.run(
        [
            "dbt",
            "build",
            "--project-dir",
            "dbt",
            "--profiles-dir",
            "/root/.dbt",
        ],
        cwd=PROJECT_ROOT,
        check=True,
    )

    logger.info("dbt build completed successfully.")


@flow(name="money-flow-s3-ingestion-flow")
def money_flow_s3_ingestion_flow() -> None:
    money_flow_result = run_money_flow_ingestion()
    exchange_rate_result = run_exchange_rate_ingestion()

    run_dbt_build(
        money_flow_result=money_flow_result,
        exchange_rate_result=exchange_rate_result,
    )


if __name__ == "__main__":
    money_flow_s3_ingestion_flow()
