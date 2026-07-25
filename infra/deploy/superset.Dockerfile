# Tested with the current apache/superset:latest image (Superset 6.0.1)
FROM apache/superset:latest

USER root

RUN /app/.venv/bin/python -m ensurepip --upgrade \
 && /app/.venv/bin/python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
 && /app/.venv/bin/python -m pip install --no-cache-dir psycopg2-binary prophet \
 && /app/.venv/bin/python -c "import psycopg2; print(psycopg2.__version__)" \
 && /app/.venv/bin/python -c "from prophet import Prophet; print('prophet installed')"

COPY superset_config.py /app/pythonpath/superset_config.py

ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py

RUN chown superset:superset /app/pythonpath/superset_config.py

USER superset
