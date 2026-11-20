-- PhonePe Pulse project: SQLite-compatible analysis queries
-- Import the cleaned CSVs into SQLite using these table names:
-- map_transaction, map_user, aggregated_transaction, aggregated_user,
-- top_transaction, top_user.
-- Amount is kept in source units; do not label it INR unless separately verified.

-- 1. Quarterly transaction trend (all districts)
SELECT year, quarter,
       SUM(trans_counts) AS total_transactions,
       SUM(amount) AS total_amount
FROM map_transaction
GROUP BY year, quarter
ORDER BY year, quarter;

-- 2. Top 10 states in the latest quarter in the supplied data (2022 Q4)
SELECT states, SUM(trans_counts) AS total_transactions,
       SUM(amount) AS total_amount
FROM map_transaction
WHERE year = 2022 AND quarter = 4
GROUP BY states
ORDER BY total_transactions DESC
LIMIT 10;

-- 3. Transaction category mix across the full available period
SELECT trans_type, SUM(trans_counts) AS total_transactions,
       SUM(amount) AS total_amount,
       100.0 * SUM(trans_counts) /
         (SELECT SUM(trans_counts) FROM aggregated_transaction) AS count_share_pct,
       100.0 * SUM(amount) /
         (SELECT SUM(amount) FROM aggregated_transaction) AS amount_share_pct
FROM aggregated_transaction
GROUP BY trans_type
ORDER BY total_transactions DESC;

-- 4. Top districts by transaction count for 2022 Q4
SELECT states, district, SUM(trans_counts) AS total_transactions,
       SUM(amount) AS total_amount
FROM top_transaction
WHERE year = 2022 AND quarter = 4
GROUP BY states, district
ORDER BY total_transactions DESC
LIMIT 10;

-- 5. Latest-quarter registered users by state (2022 Q4 snapshot)
SELECT states, SUM(registered_user_counts) AS registered_users_snapshot
FROM map_user
WHERE year = 2022 AND quarter = 4
GROUP BY states
ORDER BY registered_users_snapshot DESC
LIMIT 10;

-- 6. Brand distribution for the latest available brand quarter (2022 Q1)
-- aggregated_user.csv has no rows for 2022 Q2-Q4.
SELECT brand, SUM(user_counts) AS user_count,
       100.0 * SUM(user_counts) /
         (SELECT SUM(user_counts) FROM aggregated_user
          WHERE year = 2022 AND quarter = 1) AS share_pct
FROM aggregated_user
WHERE year = 2022 AND quarter = 1
GROUP BY brand
ORDER BY user_count DESC;

-- 7. Coverage check for aggregated_user (expected 36 states x 20 quarters)
SELECT year, quarter, COUNT(DISTINCT states) AS states_present,
       COUNT(*) AS brand_rows
FROM aggregated_user
GROUP BY year, quarter
ORDER BY year, quarter;

-- 8. Compare transaction counts by state-year-quarter across map and category tables
SELECT m.states, m.year, m.quarter,
       m.total_map_transactions, a.total_category_transactions,
       m.total_map_transactions - a.total_category_transactions AS difference
FROM (
    SELECT states, year, quarter, SUM(trans_counts) AS total_map_transactions
    FROM map_transaction GROUP BY states, year, quarter
) AS m
JOIN (
    SELECT states, year, quarter, SUM(trans_counts) AS total_category_transactions
    FROM aggregated_transaction GROUP BY states, year, quarter
) AS a
USING (states, year, quarter)
ORDER BY ABS(difference) DESC;

-- 9. Check for missing values in imported tables (example for map_transaction)
SELECT
  SUM(CASE WHEN states IS NULL THEN 1 ELSE 0 END) AS null_states,
  SUM(CASE WHEN year IS NULL THEN 1 ELSE 0 END) AS null_year,
  SUM(CASE WHEN quarter IS NULL THEN 1 ELSE 0 END) AS null_quarter,
  SUM(CASE WHEN trans_counts IS NULL THEN 1 ELSE 0 END) AS null_counts,
  SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount
FROM map_transaction;

-- 10. Year-over-year growth for Q4 transaction counts
WITH q4 AS (
  SELECT year, SUM(trans_counts) AS transactions
  FROM map_transaction
  WHERE quarter = 4
  GROUP BY year
)
SELECT curr.year, curr.transactions,
       prev.transactions AS previous_year_transactions,
       100.0 * (curr.transactions - prev.transactions) /
         NULLIF(prev.transactions, 0) AS yoy_growth_pct
FROM q4 curr
LEFT JOIN q4 prev ON prev.year = curr.year - 1
ORDER BY curr.year;
