-- =====================================================
-- CLIMATE CHANGE TWITTER ANALYSIS
-- Author: Awene Dickson Busayo
-- Date : May,2026
-- =====================================================


--======================================================
-- 1.DATA CLEANING
-- Creates climate_tweets_clean from raw source
-- Raw table is preserved untouched
--======================================================

CREATE TABLE climate_tweets_clean AS
SELECT
    -- Parse timestamp and extract date parts
    TO_TIMESTAMP(created_at, 'YYYY-MM-DD HH24:MI:SS')              AS created_at,
    EXTRACT(YEAR FROM TO_TIMESTAMP(created_at, 'YYYY-MM-DD HH24:MI:SS'))::INT    AS tweet_year,
    EXTRACT(MONTH FROM TO_TIMESTAMP(created_at, 'YYYY-MM-DD HH24:MI:SS'))::INT   AS tweet_month,
    EXTRACT(QUARTER FROM TO_TIMESTAMP(created_at, 'YYYY-MM-DD HH24:MI:SS'))::INT AS tweet_quarter,

    id,
    lat,
    lng,

    -- Flag missing coordinates
    CASE WHEN lat IS NULL OR lng IS NULL THEN TRUE ELSE FALSE END   AS missing_coords,

    TRIM(topic) AS topic,

    -- Remove out of range sentiment values
    CASE
        WHEN sentiment BETWEEN -1 AND 1 THEN ROUND(sentiment::NUMERIC, 4)
        ELSE NULL
    END AS sentiment,

    -- Sentiment bucket for categorical analysis
    CASE
        WHEN sentiment >=  0.3 THEN 'positive'
        WHEN sentiment <= -0.3 THEN 'negative'
        ELSE 'neutral'
    END AS sentiment_bucket,

    -- Standardise stance
    CASE
        WHEN LOWER(TRIM(stance)) IN ('believer','denier','neutral')
            THEN LOWER(TRIM(stance))
        ELSE 'unclassified'
    END AS stance,

    -- Standardise gender
    CASE
        WHEN LOWER(TRIM(gender)) = 'male'   THEN 'male'
        WHEN LOWER(TRIM(gender)) = 'female' THEN 'female'
        ELSE 'unspecified'
    END AS gender,

    temperature_avg,

    -- Boolean flag for aggressiveness
    CASE
        WHEN LOWER(TRIM(aggressiveness)) = 'aggressive' THEN TRUE
        ELSE FALSE
    END AS is_aggressive

FROM climate_tweets_raw
WHERE id IS NOT NULL
  AND created_at IS NOT NULL;

-- Verify clean table row count
SELECT COUNT(*) FROM climate_tweets_clean;

-- Create clean disasters table
-- Handles empty strings in numeric columns before casting
CREATE TABLE disasters_clean AS
SELECT
    TRIM("Disaster Type")     AS disaster_type,
    TRIM("Disaster Subtype")  AS disaster_subtype,
    TRIM("Disaster Group")    AS disaster_group,
    TRIM("Disaster Subgroup") AS disaster_subgroup,
    TRIM("Event Name")        AS event_name,
    TRIM(origin)              AS origin,
    TRIM(country)             AS country,
    TRIM(location)            AS location,
    latitude,
    longitude,
    start_date,
    end_date,
    -- Extract year for joining with tweets table
    EXTRACT(YEAR FROM TO_DATE(start_date, 'MM/DD/YYYY'))::INT        AS disaster_year,
    -- NULLIF converts empty strings to NULL before COALESCE fills with 0
    COALESCE("Total Deaths", 0)                                       AS total_deaths,
    COALESCE("No Affected", 0)                                        AS no_affected,
    COALESCE(NULLIF(TRIM("Reconstruction Costs ('000 US$)"), '')::NUMERIC, 0) AS reconstruction_costs,
    COALESCE(NULLIF(TRIM("Total Damages ('000 US$)"), '')::NUMERIC, 0)        AS total_damages,
    cpi
FROM disasters_raw
WHERE country IS NOT NULL
  AND start_date IS NOT NULL;

-- Verify clean disasters table
SELECT COUNT(*) FROM disasters_clean;

-- Create indexes on high-frequency filter columns
-- Reduces query execution time significantly on large tables
CREATE INDEX idx_tweets_year   ON climate_tweets_clean (tweet_year);
CREATE INDEX idx_tweets_stance ON climate_tweets_clean (stance);
CREATE INDEX idx_tweets_topic  ON climate_tweets_clean (topic);

-- Verify all derived columns were created correctly
SELECT 
    created_at,
    tweet_year,
    tweet_month,
    tweet_quarter,
    sentiment,
    sentiment_bucket,
    stance,
    gender,
    is_aggressive,
    missing_coords
FROM climate_tweets_clean
LIMIT 5;

-- Check distinct values are clean
SELECT DISTINCT stance        FROM climate_tweets_clean ORDER BY stance;
SELECT DISTINCT gender        FROM climate_tweets_clean ORDER BY gender;
SELECT DISTINCT sentiment_bucket FROM climate_tweets_clean ORDER BY sentiment_bucket;
-- Should return 0
SELECT COUNT(*) AS bad_sentiment
FROM climate_tweets_clean
WHERE sentiment NOT BETWEEN -1 AND 1;



-- =========================
--2. ANALYTICAL VIEWS
-- =========================


-- ANALYTICAL VIEWS SCRIPT
-- Purpose: Pre-aggregated views for Power BI dashboard
-- These views summarise 15.7M rows at the database level
-- to ensure fast loading and efficient BI performance


-- VIEW 1: KPI Summary
-- Single row summary of key metrics
-- Powers the KPI cards on the Power BI overview page
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT
    COUNT(*)                                                    AS total_tweets,
    COUNT(DISTINCT tweet_year)                                  AS years_covered,
    ROUND(AVG(sentiment), 4)                                    AS overall_avg_sentiment,
    ROUND(STDDEV(sentiment), 4)                                 AS sentiment_stddev,
    SUM(CASE WHEN stance = 'believer' THEN 1 ELSE 0 END)       AS total_believers,
    SUM(CASE WHEN stance = 'denier'   THEN 1 ELSE 0 END)       AS total_deniers,
    SUM(CASE WHEN stance = 'neutral'  THEN 1 ELSE 0 END)       AS total_neutral,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS overall_aggression_pct,
    COUNT(*) FILTER (WHERE lat IS NOT NULL AND lng IS NOT NULL) AS geotagged_tweets
FROM climate_tweets_clean;

-- VIEW 2: Yearly Sentiment and Stance Trends
-- Aggregates tweet volume, average sentiment and aggression
-- by year and stance to show how public opinion shifted
-- over the 13 year period (2008-2022)
-- Powers the trend line charts on the dashboard
CREATE OR REPLACE VIEW vw_yearly_sentiment AS
SELECT
    tweet_year,
    stance,
    COUNT(*)                                                    AS tweet_count,
    ROUND(AVG(sentiment), 4)                                    AS avg_sentiment,
    ROUND(STDDEV(sentiment), 4)                                 AS sentiment_stddev,
    SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)             AS aggressive_count,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS aggression_pct
FROM climate_tweets_clean
GROUP BY tweet_year, stance
ORDER BY tweet_year;

-- VIEW 3: Topic Level Divisiveness Analysis
-- Aggregates sentiment and aggression by topic
-- High sentiment standard deviation indicates
-- polarised and divisive public discourse on that topic
-- Powers the topic bar charts on the dashboard
CREATE OR REPLACE VIEW vw_topic_analysis AS
SELECT
    topic,
    COUNT(*)                                                    AS tweet_count,
    ROUND(AVG(sentiment), 4)                                    AS avg_sentiment,
    ROUND(STDDEV(sentiment), 4)                                 AS sentiment_stddev,
    SUM(CASE WHEN stance = 'believer' THEN 1 ELSE 0 END)       AS believer_count,
    SUM(CASE WHEN stance = 'denier'   THEN 1 ELSE 0 END)       AS denier_count,
    SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)             AS aggressive_count,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS aggression_pct
FROM climate_tweets_clean
WHERE topic IS NOT NULL
GROUP BY topic
ORDER BY aggression_pct DESC;

-- VIEW 4: Gender Analysis by Stance and Year
-- Segments tweet volume, sentiment and aggression
-- by gender and climate stance across all years
-- Powers the gender breakdown charts on the dashboard
CREATE OR REPLACE VIEW vw_gender_analysis AS
SELECT
    tweet_year,
    gender,
    stance,
    COUNT(*)                                                    AS tweet_count,
    ROUND(AVG(sentiment), 4)                                    AS avg_sentiment,
    SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)             AS aggressive_count,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS aggression_pct
FROM climate_tweets_clean
WHERE gender != 'unspecified'
GROUP BY tweet_year, gender, stance
ORDER BY tweet_year;

-- VIEW 5: Temperature Deviation vs Public Sentiment
-- Compares average temperature deviation against
-- average sentiment and aggression rate per year
-- Used to test whether rising temperatures correlate
-- with shifts in public discourse intensity
-- Powers the dual axis line chart on the dashboard
CREATE OR REPLACE VIEW vw_temp_vs_sentiment AS
SELECT
    tweet_year,
    ROUND(AVG(temperature_avg), 3)                              AS avg_temp_deviation,
    ROUND(AVG(sentiment), 4)                                    AS avg_sentiment,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS aggression_pct,
    COUNT(*)                                                    AS tweet_count
FROM climate_tweets_clean
WHERE temperature_avg IS NOT NULL
GROUP BY tweet_year
ORDER BY tweet_year;

-- VIEW 6: Geolocation Data for Map Visual
-- Filters to geotagged tweets only (lat/lng not null)
-- Aggregates by location, year, stance and sentiment
-- Powers the bubble map visual on the dashboard
CREATE OR REPLACE VIEW vw_geo_tweets AS
SELECT
    tweet_year,
    lat,
    lng,
    stance,
    sentiment_bucket,
    is_aggressive,
    COUNT(*)                                                    AS tweet_count,
    ROUND(AVG(sentiment), 4)                                    AS avg_sentiment
FROM climate_tweets_clean
WHERE lat IS NOT NULL
  AND lng IS NOT NULL
GROUP BY tweet_year, lat, lng, stance, sentiment_bucket, is_aggressive;

-- VIEW 7: Disasters Summary by Year and Type
-- Aggregates disaster events, deaths and damages
-- by year and disaster type from the clean disasters table
-- Powers the disasters reference table on the dashboard
CREATE OR REPLACE VIEW vw_disasters_summary AS
SELECT
    disaster_year,
    disaster_type,
    country,
    COUNT(*)                                                    AS event_count,
    SUM(total_deaths)                                           AS total_deaths,
    SUM(no_affected)                                            AS total_affected,
    SUM(total_damages)                                          AS total_damages_usd
FROM disasters_clean
GROUP BY disaster_year, disaster_type, country
ORDER BY disaster_year;

-- VIEW 8: Cross Dataset Join — Disasters vs Tweet Discourse
-- Joins climate tweets with disasters data on year
-- Tests whether years with more severe disaster events
-- produced more aggressive or polarised climate discourse
-- Key diagnostic view for the policy briefing insights
CREATE OR REPLACE VIEW vw_disasters_vs_tweets AS
SELECT
    t.tweet_year                                                AS year,
    COUNT(DISTINCT t.id)                                        AS tweet_count,
    ROUND(AVG(t.sentiment), 4)                                  AS avg_tweet_sentiment,
    ROUND(
        SUM(CASE WHEN t.is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS tweet_aggression_pct,
    COALESCE(d.disaster_count, 0)                               AS disaster_events,
    COALESCE(d.total_deaths, 0)                                 AS disaster_deaths,
    COALESCE(d.total_damages, 0)                                AS disaster_damages_usd
FROM climate_tweets_clean t
LEFT JOIN (
    -- Pre-aggregate disasters to avoid row multiplication in join
    SELECT
        disaster_year,
        COUNT(*)            AS disaster_count,
        SUM(total_deaths)   AS total_deaths,
        SUM(total_damages)  AS total_damages
    FROM disasters_clean
    GROUP BY disaster_year
) d ON t.tweet_year = d.disaster_year
GROUP BY t.tweet_year, d.disaster_count, d.total_deaths, d.total_damages
ORDER BY year;

-- =========================
-- 3. DESCRIPTIVE ANALYSIS
-- =========================


-- DESCRIPTIVE ANALYTICS SCRIPT
-- Purpose: Summarise the dataset to understand its key
-- characteristics including distributions, trends and patterns


-- 1. Overall dataset KPIs
-- Single row summary of the entire dataset
SELECT * FROM vw_kpi_summary;

-- 2. Tweet volume and average sentiment by year
-- Shows growth in climate discourse over 13 years
SELECT
    tweet_year,
    COUNT(*)                 AS tweet_count,
    ROUND(AVG(sentiment), 4) AS avg_sentiment
FROM climate_tweets_clean
GROUP BY tweet_year
ORDER BY tweet_year;

-- 3. Stance distribution with percentage share
-- Shows proportion of believers, deniers and neutral authors
SELECT
    stance,
    COUNT(*) AS count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM climate_tweets_clean
GROUP BY stance
ORDER BY count DESC;

-- 4. Sentiment bucket distribution
-- Shows overall positive vs negative vs neutral tone
SELECT
    sentiment_bucket,
    COUNT(*) AS count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM climate_tweets_clean
GROUP BY sentiment_bucket
ORDER BY count DESC;

-- 5. Gender distribution
SELECT
    gender,
    COUNT(*) AS count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM climate_tweets_clean
GROUP BY gender
ORDER BY count DESC;

-- 6. Topic volume ranking
-- Identifies most discussed climate topics
SELECT
    topic,
    COUNT(*) AS tweet_count
FROM climate_tweets_clean
WHERE topic IS NOT NULL
GROUP BY topic
ORDER BY tweet_count DESC;

-- 7. Monthly tweet distribution
-- Checks for seasonal patterns in climate discourse
SELECT
    tweet_month,
    COUNT(*)                 AS tweet_count,
    ROUND(AVG(sentiment), 4) AS avg_sentiment
FROM climate_tweets_clean
GROUP BY tweet_month
ORDER BY tweet_month;


-- =========================
-- 4. DIAGNOSTIC ANALYSIS
-- =========================


-- DIAGNOSTIC ANALYTICS SCRIPT
-- Purpose: Investigate relationships and patterns to explain
-- why certain trends and outcomes occur in the dataset


-- 1. Sentiment Polarisation Over Time
-- Measures the sentiment gap between believers and deniers
-- each year. A widening gap indicates increasing polarisation
SELECT
    tweet_year,
    ROUND(AVG(CASE WHEN stance = 'believer' THEN sentiment END), 4) AS believer_avg_sentiment,
    ROUND(AVG(CASE WHEN stance = 'denier'   THEN sentiment END), 4) AS denier_avg_sentiment,
    ROUND(AVG(CASE WHEN stance = 'neutral'  THEN sentiment END), 4) AS neutral_avg_sentiment,
    ROUND(
        ABS(
            AVG(CASE WHEN stance = 'believer' THEN sentiment END) -
            AVG(CASE WHEN stance = 'denier'   THEN sentiment END)
        ), 4
    ) AS polarisation_gap
FROM climate_tweets_clean
GROUP BY tweet_year
ORDER BY tweet_year;

-- 2. Most Divisive Topics by Sentiment Standard Deviation
-- High standard deviation means opinions are widely spread
-- indicating the most polarising and divisive topics
SELECT
    topic,
    COUNT(*)                    AS tweet_count,
    ROUND(STDDEV(sentiment), 4) AS sentiment_stddev,
    ROUND(AVG(sentiment), 4)    AS avg_sentiment,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                           AS aggression_pct
FROM climate_tweets_clean
WHERE topic IS NOT NULL
GROUP BY topic
HAVING COUNT(*) > 1000
ORDER BY sentiment_stddev DESC;

-- 3. Aggression Trend Over Time
-- Tracks whether public discourse has become
-- more hostile over the 13 year period
SELECT
    tweet_year,
    COUNT(*)                    AS tweet_count,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                           AS aggression_pct,
    ROUND(AVG(sentiment), 4)    AS avg_sentiment
FROM climate_tweets_clean
GROUP BY tweet_year
ORDER BY tweet_year;

-- 4. Gender vs Stance Cross Segmentation
-- Examines whether climate stance and aggression
-- differ significantly between male and female authors
SELECT
    gender,
    stance,
    COUNT(*)                    AS tweet_count,
    ROUND(AVG(sentiment), 4)    AS avg_sentiment,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                           AS aggression_pct
FROM climate_tweets_clean
WHERE gender != 'unspecified'
GROUP BY gender, stance
ORDER BY gender, stance;

-- 5. Temperature Deviation vs Discourse Intensity
-- Tests whether higher temperature anomalies drive
-- more aggressive discourse and increased climate denial
SELECT
    tweet_year,
    ROUND(AVG(temperature_avg), 3) AS avg_temp_deviation,
    ROUND(AVG(sentiment), 4)       AS avg_sentiment,
    ROUND(
        SUM(CASE WHEN is_aggressive THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                              AS aggression_pct,
    ROUND(
        SUM(CASE WHEN stance = 'denier' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                              AS denier_pct
FROM climate_tweets_clean
WHERE temperature_avg IS NOT NULL
GROUP BY tweet_year
ORDER BY tweet_year;