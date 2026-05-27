import os
import re
import psycopg2
from pathlib import Path
from typing import TypedDict, Literal

from dotenv import load_dotenv
from langgraph.graph import StateGraph, START, END
from langchain_community.utilities import SQLDatabase
from langchain_groq import ChatGroq

from src.config import DB_CONFIG

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

DB_URI = (
    f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
    f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']}"
)

llm = ChatGroq(
    api_key=os.getenv("GROQ_API_KEY"),
    model_name="llama-3.3-70b-versatile",
    temperature=0,
)


class AgentState(TypedDict):
    user_question: str
    table_schema: str
    generated_sql: str
    is_read_only: bool
    query_result: str
    formatted_response: str
    error: str


def receive_question(state: AgentState) -> AgentState:
    """Receive and validate the user's natural language question."""
    question = state.get("user_question", "").strip()
    if not question:
        return {**state, "error": "Empty question received. Please ask a question."}
    return {**state, "user_question": question, "error": ""}


def fetch_schema(state: AgentState) -> AgentState:
    """Retrieve table schemas for ALL tables from the database."""
    if state.get("error"):
        return state
    try:
        db = SQLDatabase.from_uri(DB_URI, sample_rows_in_table_info=3)
        schema = db.get_table_info()
        return {**state, "table_schema": schema}
    except Exception as e:
        return {**state, "error": f"Failed to fetch database schema: {e}"}


def generate_sql(state: AgentState) -> AgentState:
    """LLM generates a SQL query from the user question and schema context."""
    if state.get("error"):
        return state

    prompt = f"""You are an expert Clinical AI Assistant for a Tuberculosis Preventive Treatment (TPT) database in India.

Given the database schema below, write a single SQL SELECT query to answer the user's question.

RULES:
1. Output ONLY the raw SQL query — no explanations, no markdown fences, no comments.
2. You may ONLY write SELECT queries. Never write INSERT, UPDATE, DELETE, DROP, or any other DDL/DML.
3. Use proper JOINs when data spans multiple tables.
4. If the question cannot be answered from the schema, respond with exactly: SELECT 'Question cannot be answered from the available data' AS message;

DATABASE SCHEMA:
{state["table_schema"]}

USER QUESTION: {state["user_question"]}

SQL QUERY:"""

    try:
        response = llm.invoke(prompt)
        sql = response.content.strip()
        # Strip markdown code fences if the LLM wraps it
        sql = re.sub(r"^```(?:sql)?\s*", "", sql)
        sql = re.sub(r"\s*```$", "", sql)
        return {**state, "generated_sql": sql.strip()}
    except Exception as e:
        return {**state, "error": f"LLM failed to generate SQL: {e}"}


def validate_sql(state: AgentState) -> AgentState:
    """Check that the generated SQL is a read-only SELECT statement."""
    if state.get("error"):
        return {**state, "is_read_only": False}

    sql = state.get("generated_sql", "").strip().upper()

    if not sql.startswith("SELECT"):
        return {
            **state,
            "is_read_only": False,
            "error": "Generated SQL is not a SELECT query. Only read-only queries are allowed.",
        }

    blocked = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "CREATE", "TRUNCATE", "GRANT", "REVOKE"]
    for keyword in blocked:
        if re.search(rf"\b{keyword}\b", sql):
            return {
                **state,
                "is_read_only": False,
                "error": f"SQL contains forbidden keyword '{keyword}'. Only SELECT queries are allowed.",
            }

    return {**state, "is_read_only": True}


def execute_query(state: AgentState) -> AgentState:
    """Execute the validated SQL query against the PostgreSQL database."""
    if state.get("error"):
        return state

    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        cursor.execute("SET TRANSACTION READ ONLY;")
        cursor.execute(state["generated_sql"])

        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()

        cursor.close()
        conn.close()

        if not rows:
            result_str = "No results found."
        else:
            # Format for readable information.
            header = " | ".join(columns)
            separator = " | ".join(["---"] * len(columns))
            body = "\n".join(" | ".join(str(val) for val in row) for row in rows)
            result_str = f"{header}\n{separator}\n{body}"

        return {**state, "query_result": result_str}

    except Exception as e:
        return {**state, "error": f"Database query failed: {e}", "query_result": ""}


def format_response(state: AgentState) -> AgentState:
    """Format raw query results into a clean Markdown clinical response."""
    if state.get("error"):
        return state

    prompt = f"""You are an expert Clinical AI Assistant for Tuberculosis Preventive Treatment (TPT) in India.

The user asked a question and a SQL query was run against the clinical database. Your job is to present the results as a clear, professional clinical response in Markdown.

RULES:
1. Present data in clean Markdown tables or bullet points as appropriate.
2. If the query returned "No results found", politely inform the user that the data is not in the system.
3. Be concise but clinically accurate.
4. Do NOT reveal the SQL query itself in your response.
5. If the data includes patient information, present it respectfully and professionally.

USER QUESTION: {state["user_question"]}

QUERY RESULTS:
{state["query_result"]}

FORMATTED RESPONSE:"""

    try:
        response = llm.invoke(prompt)
        return {**state, "formatted_response": response.content.strip()}
    except Exception as e:
        return {**state, "formatted_response": f"Results retrieved but formatting failed: {state['query_result']}"}


def handle_error(state: AgentState) -> AgentState:
    """Handle unsafe SQL or execution errors with a safe fallback message."""
    error_msg = state.get("error", "An unknown error occurred.")
    return {
        **state,
        "formatted_response": (
            f"⚠️ **Request could not be processed**\n\n"
            f"{error_msg}\n\n"
            f"Please try rephrasing your question. I can only answer clinical data questions "
            f"using read-only queries against the PMTPT database."
        ),
    }


def route_after_validation(state: AgentState) -> Literal["execute_query", "handle_error"]:
    """Route to execution if SQL is read-only, otherwise to error handler."""
    if state.get("is_read_only", False):
        return "execute_query"
    return "handle_error"


workflow = StateGraph(AgentState)

workflow.add_node("receive_question", receive_question)
workflow.add_node("fetch_schema", fetch_schema)
workflow.add_node("generate_sql", generate_sql)
workflow.add_node("validate_sql", validate_sql)
workflow.add_node("execute_query", execute_query)
workflow.add_node("format_response", format_response)
workflow.add_node("handle_error", handle_error)

workflow.add_edge(START, "receive_question")
workflow.add_edge("receive_question", "fetch_schema")
workflow.add_edge("fetch_schema", "generate_sql")
workflow.add_edge("generate_sql", "validate_sql")
workflow.add_conditional_edges("validate_sql", route_after_validation)
workflow.add_edge("execute_query", "format_response")
workflow.add_edge("format_response", END)
workflow.add_edge("handle_error", END)

graph = workflow.compile()
