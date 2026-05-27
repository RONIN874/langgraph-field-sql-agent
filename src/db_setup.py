#import sys
from pathlib import Path

from src.config import DB_CONFIG
import psycopg2

#sys.path.insert(0,str(Path(__file__).resolve().parent.parent)) [For ache se import in strucured folder]

BASE_DIR = Path(__file__).resolve().parent.parent

def db_setup():
    conn = psycopg2.connect(**DB_CONFIG)
    cursor=conn.cursor()

    conn.autocommit = True

    schema_sql = (BASE_DIR / "sql" / "pmtpt_schema.sql").read_text(encoding = "utf-8")
    print("Creating tables.....")
    cursor.execute(schema_sql)

    seed_sql = (BASE_DIR / "sql" / "pmtpt_seed_data.sql").read_text(encoding = "utf-8")
    print("Data entering")
    cursor.execute(seed_sql)

    cursor.close()
    conn.close()

    print("Database setup complete")

if __name__=="__main__":
    db_setup()
    
    
    

    