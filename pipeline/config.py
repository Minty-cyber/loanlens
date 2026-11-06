"""Shared paths and settings for the LoanLens pipeline."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

RAW_CSV = ROOT / "data" / "raw" / "lending_club_loan_two.csv"
DB_PATH = ROOT / "data" / "warehouse" / "loanlens.duckdb"
EXPORT_DIR = ROOT / "data" / "exports"
SQL_DIR = ROOT / "sql"
DOCS_DIR = ROOT / "docs"


SQL_FILES = [
    "01_raw.sql",
    "02_staging.sql",
    "03_dimensions.sql",
    "04_fact.sql",
]

# Data Marts that will be loaded into the PowerBI model 
MART_TABLES = [
    "fact_loans",
    "dim_date",
    "dim_grade",
    "dim_purpose",
    "dim_term",
    "dim_home_ownership",
    "dim_verification",
    "dim_dti_band",
    "dim_income_band",
    "data_quality_results",
]