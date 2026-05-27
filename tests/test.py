from pathlib import Path
import os
import sys

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from dotenv import load_dotenv
from src.config import DB_CONFIG

load_dotenv(BASE_DIR / ".env")  # Load .env file into environment
from langchain_community.utilities import SQLDatabase
from langchain_groq import ChatGroq
from langchain_community.agent_toolkits import create_sql_agent

DB_URI = f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}@localhost:5432/{DB_CONFIG['dbname']}"

print("Connecting to Database")

ALLOWED_TABLES = [
    
    "persons",
    "health_facilities",
    "districts",

    "tpt_eligibility_assessments",
    "tpt_enrolments",
    "adverse_event_reports",    

    "tpt_regimens",
    "risk_groups",
    "adverse_events_catalogue",

]
db = SQLDatabase.from_uri(
    DB_URI,
    include_tables=ALLOWED_TABLES,
    sample_rows_in_table_info=3
)
print("Initializing Agent")

llm = ChatGroq(
    api_key = os.getenv("GROQ_API_KEY"),
    model_name="llama-3.3-70b-versatile",
    temperature = 0

)

SYSTEM_PROMPT = """You are an expert Clinical AI Assistant specializing in Tuberculosis Preventive Treatment (TPT) guidelines for India.
Your job is to assist healthcare workers by accurately querying the clinic's patient and treatment database.

STRICT RULES:
1. Read-Only: You may ONLY execute SELECT queries.
2. Allowed Tables: You may ONLY query the specific tables provided to you.
3. No Hallucination: If a query returns no results, politely inform the user that the data is not in the system.
4. Format your final response in clean Markdown.
"""

agent_executor = create_sql_agent(
    llm=llm,
    db=db,
    agent_type="tool-calling",
    prefix=SYSTEM_PROMPT,
    verbose=True  # True for Agent thinking process show.
)

question = "List all the patients who are currently active on a TPT enrolment"

print(f"User Question: {question}\n")

response =  agent_executor.invoke({"input": question})
print("\n Answer")
print(response.get("output"))

