-- Read-only account of Grafana, for the statistics of the shop (dashboard "Medusa shop").
-- Only what the dashboard needs is readable : no personal data of the customers, no credentials, no API keys.
--
-- The tables are created by the migrations of the backend : run it once the backend has started, and again after an
-- update of Medusa if a panel reports a missing permission. It can be run any number of times :
--
--   sudo docker exec -i medusa-db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v password="${GRAFANA_READER_PASSWORD:?}"' < grafana-reader.sql

SELECT 'CREATE ROLE grafana_reader'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana_reader') \gexec

ALTER ROLE grafana_reader WITH LOGIN PASSWORD :'password';

-- Belt and braces : read-only transactions only, and no query long enough to slow the shop down
ALTER ROLE grafana_reader SET default_transaction_read_only = on;
ALTER ROLE grafana_reader SET statement_timeout = '10s';

GRANT CONNECT ON DATABASE :"DBNAME" TO grafana_reader;
GRANT USAGE ON SCHEMA public TO grafana_reader;

-- Orders, their totals and their items, and the carts (conversion)
GRANT SELECT ON "order", order_summary, order_item, order_line_item, cart TO grafana_reader;

-- Column by column : the country of the orders and the creation date of the accounts, but no name, e-mail or address
GRANT SELECT (id, country_code) ON order_address TO grafana_reader;
GRANT SELECT (id, has_account, created_at, deleted_at) ON customer TO grafana_reader;
