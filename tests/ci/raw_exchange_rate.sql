BEGIN;

INSERT INTO raw.exchange_rate (
    source,
    source_rate_key,
    rate_date,
    base_currency,
    base_amount,
    quote_currency,
    quote_amount
)
VALUES
    ('cbr', 'R01235', '31.07.2026', 'USD', '1', 'RUB', '90,5000'),
    ('cbr', 'R01235', '01.08.2026', 'USD', '1', 'RUB', '90,6000'),
    ('cbr', 'R01235', '04.08.2026', 'USD', '1', 'RUB', '91,1000'),
    ('cbr', 'R01235', TO_CHAR(CURRENT_DATE, 'DD.MM.YYYY'), 'USD', '1', 'RUB', '92,0000'),
    ('cbr', 'R01370', '31.07.2026', 'KGS', '10', 'RUB', '10,3500'),
    ('cbr', 'R01370', TO_CHAR(CURRENT_DATE, 'DD.MM.YYYY'), 'KGS', '10', 'RUB', '10,5000');

COMMIT;
