FROM prefecthq/prefect:3-python3.12

WORKDIR /opt/finance_analytics

COPY requirements.txt /opt/finance_analytics/requirements.txt

RUN pip install --no-cache-dir -r requirements.txt
