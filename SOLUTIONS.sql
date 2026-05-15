-- SOLUTIONS.sql
-- Oracle-compatible queries strictly based on the CSV-derived schema: TARIFFS, CUSTOMERS, MONTHLY_STATS.
-- Each query below is documented with a multi-sentence explanation (>= 3 sentences) as required.

/*
Approach: List customers subscribed to the 'Kobiye Destek' tariff.
We join `CUSTOMERS` to `TARIFFS` on `TARIFF_ID` to associate each customer with its tariff metadata.
We filter by the exact tariff name 'Kobiye Destek' so results reflect the requested product audience.
Returned columns include the signup date formatted with `TO_CHAR` for easy reading.
*/
SELECT c.CUSTOMER_ID,
       c.NAME    AS CUSTOMER_NAME,
       c.CITY,
       TO_CHAR(c.SIGNUP_DATE, 'DD/MM/YYYY') AS SIGNUP_DATE,
       t.NAME    AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek';

/*
Approach: Find the newest customer who subscribed to the 'Kobiye Destek' tariff.
We restrict to customers on that tariff and order by `SIGNUP_DATE` descending to surface the most recent signup.
Using `FETCH FIRST 1 ROWS ONLY` returns a single newest subscriber in an Oracle-compatible way.
The signup date is formatted for readability.
*/
SELECT c.CUSTOMER_ID,
       c.NAME,
       c.CITY,
       TO_CHAR(c.SIGNUP_DATE, 'DD/MM/YYYY') AS SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.SIGNUP_DATE DESC
FETCH FIRST 1 ROWS ONLY;

/*
Approach: Find the distribution of tariffs among customers (count per tariff).
We LEFT JOIN `TARIFFS` to `CUSTOMERS` so tariffs with zero customers are still reported.
Group by tariff id and name to compute counts and order by count descending to highlight popular tariffs.
*/
SELECT t.TARIFF_ID,
       t.NAME AS TARIFF_NAME,
       COUNT(c.CUSTOMER_ID) AS CUSTOMER_COUNT
FROM TARIFFS t
LEFT JOIN CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
GROUP BY t.TARIFF_ID, t.NAME
ORDER BY CUSTOMER_COUNT DESC;

/*
Approach: Identify the earliest customers to sign up (by signup date).
We use `MIN(SIGNUP_DATE)` to get the earliest date and then return all customers who match that date to handle ties.
Dates are formatted with `TO_CHAR` so the output is human friendly.
*/
SELECT CUSTOMER_ID, NAME, CITY, TO_CHAR(SIGNUP_DATE, 'DD/MM/YYYY') AS SIGNUP_DATE
FROM CUSTOMERS
WHERE SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS);

/*
Approach: Find the distribution of the earliest customers across cities.
We reuse the earliest-signup definition and then GROUP BY `CITY` to count how many earliest adopters are in each city.
Ordering by count descending highlights cities with larger shares of early signups.
*/
SELECT CITY, COUNT(*) AS EARLIEST_CUSTOMER_COUNT
FROM CUSTOMERS
WHERE SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
GROUP BY CITY
ORDER BY EARLIEST_CUSTOMER_COUNT DESC;

/*
Approach: Identify customers missing `MONTHLY_STATS` records.
We LEFT JOIN `CUSTOMERS` to `MONTHLY_STATS` on `CUSTOMER_ID` and select rows where the right side is NULL.
This returns customers who have no monthly record at all in `MONTHLY_STATS` (IDs and names), which fits the described insertion error.
*/
SELECT c.CUSTOMER_ID, c.NAME
FROM CUSTOMERS c
LEFT JOIN MONTHLY_STATS m ON c.CUSTOMER_ID = m.CUSTOMER_ID
WHERE m.CUSTOMER_ID IS NULL;

/*
Approach: Find the distribution of missing monthly records across cities.
Using the same LEFT JOIN pattern, we GROUP BY `CITY` and count customers with no monthly record.
This helps identify whether missing inserts are concentrated by location.
*/
SELECT c.CITY, COUNT(*) AS MISSING_MONTHLY_COUNT
FROM CUSTOMERS c
LEFT JOIN MONTHLY_STATS m ON c.CUSTOMER_ID = m.CUSTOMER_ID
WHERE m.CUSTOMER_ID IS NULL
GROUP BY c.CITY
ORDER BY MISSING_MONTHLY_COUNT DESC;

/*
Approach: Find customers who have used at least 75% of their data limit.
We join `MONTHLY_STATS` to `CUSTOMERS` to `TARIFFS` and compare `DATA_USAGE` vs `DATA_LIMIT` from the tariff.
Tariffs with `DATA_LIMIT` <= 0 are excluded because a zero limit indicates no cap; we compute percent used with `ROUND(...,2)` for readability.
*/
SELECT c.CUSTOMER_ID,
       c.NAME,
       t.NAME AS TARIFF_NAME,
       m.DATA_USAGE,
       t.DATA_LIMIT,
       ROUND(m.DATA_USAGE / NULLIF(t.DATA_LIMIT,0) * 100, 2) AS PERCENT_OF_LIMIT
FROM MONTHLY_STATS m
JOIN CUSTOMERS c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.DATA_LIMIT > 0
  AND m.DATA_USAGE >= 0.75 * t.DATA_LIMIT
ORDER BY PERCENT_OF_LIMIT DESC;

/*
Approach: Identify customers who have exhausted data, minutes, and SMS limits.
We require each tariff limit to be greater than zero and compare usage columns to the corresponding tariff limits.
Customers meeting all three >= conditions are returned for follow-up (e.g., upsell or warnings).
*/
SELECT c.CUSTOMER_ID,
       c.NAME,
       t.NAME AS TARIFF_NAME,
       m.DATA_USAGE, t.DATA_LIMIT,
       m.MINUTE_USAGE, t.MINUTE_LIMIT,
       m.SMS_USAGE, t.SMS_LIMIT
FROM MONTHLY_STATS m
JOIN CUSTOMERS c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.DATA_LIMIT > 0
  AND t.MINUTE_LIMIT > 0
  AND t.SMS_LIMIT > 0
  AND m.DATA_USAGE >= t.DATA_LIMIT
  AND m.MINUTE_USAGE >= t.MINUTE_LIMIT
  AND m.SMS_USAGE >= t.SMS_LIMIT;

/*
Approach: Find customers who have unpaid fees (PAYMENT_STATUS not 'PAID').
We treat any `PAYMENT_STATUS` value other than 'PAID' as outstanding and use `NVL`/`UPPER` to be robust against NULLs or case differences.
Distinct customer rows are returned so billing teams can prioritize follow-up.
*/
SELECT DISTINCT c.CUSTOMER_ID, c.NAME, m.PAYMENT_STATUS
FROM MONTHLY_STATS m
JOIN CUSTOMERS c ON m.CUSTOMER_ID = c.CUSTOMER_ID
WHERE NVL(UPPER(m.PAYMENT_STATUS), '') <> 'PAID';

/*
Approach: Distribution of payment statuses across tariffs.
We LEFT JOIN `TARIFFS` -> `CUSTOMERS` -> `MONTHLY_STATS` so each tariff appears even if it has no records.
Grouping by tariff and `PAYMENT_STATUS` (treating NULL as 'NO_RECORD') yields counts for each status per tariff.
*/
SELECT t.TARIFF_ID,
       t.NAME AS TARIFF_NAME,
       NVL(m.PAYMENT_STATUS, 'NO_RECORD') AS PAYMENT_STATUS,
       COUNT(m.ID) AS STATUS_COUNT
FROM TARIFFS t
LEFT JOIN CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
LEFT JOIN MONTHLY_STATS m ON m.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY t.TARIFF_ID, t.NAME, NVL(m.PAYMENT_STATUS, 'NO_RECORD')
ORDER BY t.TARIFF_ID, PAYMENT_STATUS;
