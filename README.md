# Climate-change-twitter-analysis
End-to-end SQL and Power BI analysis of 15.7M climate tweets (2006-2019)
# 🌍 Climate Change Public Discourse Analysis (2006–2019)

> An end-to-end data analytics project analysing **15.7 million climate change tweets** using **PostgreSQL** and **Power BI** — no Python, no shortcuts.


## 🔗 Live Dashboard

[![Power BI Dashboard](https://img.shields.io/badge/Power%20BI-Live%20Dashboard-yellow?style=for-the-badge&logo=powerbi)](https://app.powerbi.com/view?r=eyJrIjoiNjM1NGY5ZjYtZGQ3ZS00YTM5LWIwMTctNDZjYWRhM2U2YzI4IiwidCI6Ijg4MTM1NDc1LTU1NzctNGVjZC04NDAyLWU0NDRiM2FmMDJjNiIsImMiOjZ9)


## 📌 Project Background

This project was completed as part of the **HNG Stage 4 Data Analytics Task**.

As a data analyst contracted by a climate research organisation, I was tasked with preparing insights for a policy briefing. Leadership needed answers to two critical questions:

1. **How has public sentiment and climate stance shifted over 13 years?**
2. **Which topics and regions are driving the most divisive or aggressive discourse?**

The full pipeline was managed independently — from raw data ingestion in PostgreSQL to a published interactive dashboard in Power BI.


## 📂 Repository Contents

```
climate-change-twitter-analysis/
│
├── climate_analysis.sql          # Full SQL pipeline (all sections)
├── Climate_Analysis_Report.pdf   # Structured written report
└── README.md                     # This file
```


## 🛠️ Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| **PostgreSQL** | 18 | Data storage, cleaning, transformation, views |
| **DBeaver** | 26.0 | Database management & CSV import |
| **Power BI Desktop** | Latest | Dashboard development |
| **Power BI Service** | Cloud | Dashboard hosting & publishing |

> ⚠️ **No Python or external programming languages were used.** PostgreSQL only, as per project requirements.


## 📊 Datasets

| Dataset | Rows | Size | Source |
|---------|------|------|--------|
| The Climate Change Twitter Dataset | 15,789,411 | ~2GB | [Kaggle](https://www.kaggle.com/datasets/deffro/the-climate-change-twitter-dataset) |
| Global Natural Disasters Dataset | 4,913 | ~1MB | Supplementary |

### Tweet Dataset Columns

| Column | Type | Description |
|--------|------|-------------|
| `created_at` | TIMESTAMP | Date and time tweet was posted |
| `id` | BIGINT | Unique tweet identifier |
| `lat / lng` | NUMERIC | Geolocation coordinates (66% null) |
| `topic` | TEXT | Climate topic category |
| `sentiment` | NUMERIC | Score from -1.0 (negative) to +1.0 (positive) |
| `stance` | TEXT | believer / denier / neutral |
| `gender` | TEXT | male / female / undefined |
| `temperature_avg` | NUMERIC | Local temperature deviation from baseline |
| `aggressiveness` | TEXT | aggressive / not aggressive |


## 🗄️ Database Architecture

### Raw Tables (source data — never modified)
```
climate_tweets_raw     →  15,789,411 rows
disasters_raw          →  4,913 rows
```

### Clean Tables (transformed and analysis-ready)
```
climate_tweets_clean   →  15,789,411 rows  (with derived columns)
disasters_clean        →  4,913 rows       (standardised dates and nulls)
```

### Analytical Views (Power BI connects directly to these)
```
vw_kpi_summary             →  Single-row KPI summary for dashboard cards
vw_yearly_sentiment        →  Sentiment and stance trends by year
vw_topic_analysis          →  Topic divisiveness and aggression metrics
vw_gender_analysis         →  Gender breakdown by stance and year
vw_temp_vs_sentiment       →  Temperature deviation vs public sentiment
vw_geo_tweets              →  Geotagged tweets for map visualisation
vw_disasters_summary       →  Disasters aggregated by year and type
vw_disasters_vs_tweets     →  Cross-dataset diagnostic join
```


## 📈 Dashboard Pages

| Page | Title | Visuals |
|------|-------|---------|
| **1** | Overview | KPI cards (16M tweets, 28.67% aggression), tweet volume line chart, year & stance slicers |
| **2** | Sentiment & Stance Trends | Avg sentiment by year & stance line chart, stance distribution donut, aggression over time |
| **3** | Topics & Aggression Analysis | Topic volume bar chart, aggression rate ranking, sentiment divisiveness column chart |
| **4** | Gender & Disaster Correlation | Gender/stance clustered bars, sentiment by gender, disaster events vs aggression dual-axis |


## 🔑 Key Findings

### Descriptive
- 📌 **15,789,411 tweets** analysed across **14 years** (2006–2019)
- 📌 **71.52%** of tweets from climate believers — public acceptance dominates
- 📌 Only **7.55%** from deniers — yet they generate disproportionate aggression
- 📌 **28.67%** overall aggression rate — nearly 1 in 3 tweets is aggressive
- 📌 **65.28%** of tweets from male authors — discourse is male-dominated
- 📌 Peak volume in **2018** with 6.25 million tweets

### Diagnostic
- 📌 **Politics** is the most aggressive topic at **43.39%** aggression rate
- 📌 **Donald Trump vs Science** second most aggressive at **40.30%**
- 📌 **Weather Extremes** is the most divisive topic by sentiment spread
- 📌 Denier sentiment is **always negative** across all 14 years — without exception
- 📌 Aggression **declined** from 35% (2008) → 24% (2019) as community grew
- 📌 **2015 Paris Agreement** was the biggest turning point — denier % dropped from 15% to 6%
- 📌 Believers recorded **negative sentiment for the first time in 2019** — possible climate anxiety



## ⚙️ SQL Pipeline Structure

The `climate_analysis.sql` file is structured into 7 sections:

```
Section 0  →  Data Ingestion documentation
Section 1  →  Raw table creation
Section 2  →  Data quality audit
Section 3  →  Data cleaning and preparation
Section 4  →  Analytical views (Power BI connections)
Section 5  →  Descriptive analytics queries
Section 6  →  Diagnostic analytics queries
Section 7  →  Query optimisation (indexes, CTEs, EXPLAIN ANALYZE)
```


## 🚀 How to Reproduce This Project

### Prerequisites
- PostgreSQL 18+
- DBeaver Community Edition
- Power BI Desktop

### Steps

**1. Setup Database**
```sql
-- Create database in pgAdmin or DBeaver
CREATE DATABASE Climate_database;
```

**2. Run SQL Script**
```
Open climate_analysis.sql in DBeaver
Run Section 1 first (table creation)
Then import CSVs using DBeaver Import Wizard
Then run Sections 2 through 7 in order
```

**3. Import Data**
```
Right-click climate_tweets_raw → Import Data → CSV
Select climate_tweets.csv (allow 15-20 mins for 2GB file)

Right-click disasters_raw → Import Data → CSV
Select disasters.csv (completes in under 2 mins)
```

**4. Connect Power BI**
```
Get Data → PostgreSQL
Server:   localhost
Port:     5432
Database: Climate_database
Load all 8 vw_ views
```


## 📋 Recommendations

Based on the analysis, five actionable recommendations were made to organisational leadership:

1. **Target the neutral segment** (20.94%) with tailored messaging — they are persuadable and less aggressive
2. **De-politicise climate messaging** — political topics drive 43% aggression rates
3. **Amplify female voices** — female believers are the least aggressive group in the dataset
4. **Time campaigns around December** — highest engagement month driven by COP summits
5. **Track aggression rate as a KPI** — currently 24.21%, target continued reduction


## 👤 Author

**Awene Dickson Busayo**
- 🏷️ Slack ID: `_dickson`
- 🎓 Program: HNG Stage 4 Data Analytics Task
- 📅 Date: May 2026




*This project was completed independently as part of the HNG Internship Data Analytics Programme, Stage 4.*
