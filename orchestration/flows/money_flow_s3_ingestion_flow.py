from pathlib import Path
import subprocess

from prefect import flow, get_run_logger, task

from ingestion.load_money_flow_from_s3 import load_money_flow_from_s3


PROJECT_ROOT = Path("/opt/finance_analytics")


@task(name="load-money-flow-from-s3", retries=2, retry_delay_seconds=60)
def run_money_flow_ingestion() -> str:
    logger = get_run_logger()

    ingestion_result = load_money_flow_from_s3()

    logger.info("Ingestion result: %s", ingestion_result)

    return ingestion_result


@task(name="run-dbt-build", retries=1, retry_delay_seconds=60)
def run_dbt_build(ingestion_result: str) -> None:
    logger = get_run_logger()

    if ingestion_result == "skipped":
        logger.info("No new files loaded. Skipping dbt build.")
        return

    if ingestion_result != "loaded":
        raise ValueError(f"Unexpected ingestion result: {ingestion_result}")

    logger.info("Starting dbt build.")

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
    ingestion_result = run_money_flow_ingestion()
    run_dbt_build(ingestion_result)


if __name__ == "__main__":
    money_flow_s3_ingestion_flow()
