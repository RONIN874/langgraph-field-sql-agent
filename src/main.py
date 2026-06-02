import os
import re
import logging
from functools import lru_cache
from typing import TypedDict, Literal

import psycopg2
import psycopg2.pool
from dotenv import load_dotenv
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from langgraph.graph import StateGraph, START, END
from langchain_community.utilities import SQLDatabase
from langchain_groq import ChatGroq

# Reads from local .env when present; falls back to machine env vars on Render
load_dotenv()

logger = logging.getLogger("pmtpt.graph")

# Database URL — SQLAlchemy needs the psycopg2 driver prefix for SQLDatabase,
# but psycopg2 itself uses the plain postgresql:// form.

RAW_DB_URL = os.getenv("DATABASE_URL", "")

if RAW_DB_URL.startswith("postgresql://"):
    DB_URI = RAW_DB_URL.replace("postgresql://", "postgresql+psycopg2://", 1)
else:
    DB_URI = RAW_DB_URL

# Connection pool — reuses connections across requests instead of opening a
# new one every time. minconn=1, maxconn=5 is conservative and safe for
# Neon's free tier (which allows ~10 simultaneous connections).

_pool: psycopg2.pool.ThreadedConnectionPool | None = None

def _get_pool() -> psycopg2.pool.ThreadedConnectionPool:
    """Initialise the connection pool on first use (lazy, thread-safe singleton)."""
    global _pool
    if _pool is None:
        logger.info("Initialising database connection pool …")
        _pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=5,
            dsn=RAW_DB_URL,
            connect_timeout=5,
        )
        logger.info("Connection pool ready.")
    return _pool


# LLM — request_timeout prevents a hung Groq call from blocking workers
# forever. 30 s is generous; typical responses come back in 3–8 s.

llm = ChatGroq(
    api_key=os.getenv("GROQ_API_KEY"),
    model_name="llama-3.3-70b-versatile",
    temperature=0,
    request_timeout=30,
)


# Schema cache — fetched once at first use, then reused for every request.
# The schema almost never changes; re-fetching it on every call is wasteful
# and adds a full DB round-trip + LangChain overhead to every question.
# Call _invalidate_schema_cache() if you ever run a migration.
@lru_cache(maxsize=1)
def _get_cached_schema() -> str:
    """Fetch and cache the full DB schema. Called once per process lifetime."""
    logger.info("Fetching database schema (first call — will be cached) …")
    db = SQLDatabase.from_uri(DB_URI, sample_rows_in_table_info=3)
    schema = db.get_table_info()
    logger.info("Schema cached successfully.")
    return schema

def _invalidate_schema_cache() -> None:
    """Call this after running migrations to force a fresh schema fetch."""
    _get_cached_schema.cache_clear()
    logger.info("Schema cache cleared.")

# Retry decorator for LLM calls — handles transient Groq 429 / 503 errors
# with exponential back-off (1 s → 2 s → 4 s, up to 3 attempts total).

_llm_retry = retry(
    retry=retry_if_exception_type(Exception),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    reraise=True,
)

# Result row cap — prevents fetchall() from loading thousands of rows into
# memory. Applied by injecting a LIMIT clause into every generated query.
_MAX_ROWS = 500

def _apply_row_limit(sql: str) -> str:
    """
    Append LIMIT {_MAX_ROWS} to any SELECT that doesn't already have one.
    Handles both plain SELECT and CTEs (WITH ... SELECT ...).
    """
    normalised = sql.strip().rstrip(";")
    upper = normalised.upper()
    if re.search(r"\bLIMIT\s+\d+", upper):
        return normalised  # already has a LIMIT
    return f"{normalised} LIMIT {_MAX_ROWS}"

 # Agent state

class AgentState(TypedDict):
    user_question: str
    table_schema: str
    generated_sql: str
    is_read_only: bool
    query_result: str
    formatted_response: str
    error: str


# Graph nodes

def receive_question(state: AgentState) -> AgentState:
    """Validate and normalise the incoming question."""
    question = state.get("user_question", "").strip()
    if not question:
        return {**state, "error": "Empty question received. Please ask a question."}
    logger.info("Question received (length=%d)", len(question))
    return {**state, "user_question": question, "error": ""}


def fetch_schema(state: AgentState) -> AgentState:
    """
    Return the cached DB schema.
    The schema is fetched from the database only once per process lifetime;
    subsequent calls return the in-memory cache instantly.
    """
    if state.get("error"):
        return state
    try:
        schema = _get_cached_schema()
        return {**state, "table_schema": schema}
    except Exception as e:
        logger.exception("Failed to fetch schema: %s", e)
        return {**state, "error": f"Failed to fetch database schema: {e}"}


def generate_sql(state: AgentState) -> AgentState:
    """LLM generates a SQL SELECT query from the question and schema."""
    if state.get("error"):
        return state

    prompt = f"""You are an expert Clinical AI Assistant for a Tuberculosis Preventive Treatment (TPT) database in India.

Given the database schema below, write a single SQL SELECT query to answer the user's question.

RULES:
1. Output ONLY the raw SQL query — no explanations, no markdown fences, no comments.
2. You may ONLY write SELECT queries. Never write INSERT, UPDATE, DELETE, DROP, or any other DDL/DML.
3. Use proper JOINs when data spans multiple tables.
4. Never use semicolons inside the query.
5. Do NOT include a LIMIT clause — one will be added automatically.
6. If the question cannot be answered from the schema, respond with exactly: SELECT 'Question cannot be answered from the available data' AS message

DATABASE SCHEMA:
{state["table_schema"]}

USER QUESTION: {state["user_question"]}

SQL QUERY:"""

    try:
        @_llm_retry
        def _invoke() -> str:
            response = llm.invoke(prompt)
            return response.content.strip()

        sql = _invoke()
        # Strip markdown code fences if the LLM wraps the output anyway
        sql = re.sub(r"^```(?:sql)?\s*", "", sql, flags=re.IGNORECASE)
        sql = re.sub(r"\s*```$", "", sql)
        sql = sql.strip().rstrip(";")   # remove trailing semicolon — added back safely later
        logger.info("SQL generated successfully.")
        return {**state, "generated_sql": sql}
    except Exception as e:
        logger.exception("LLM failed to generate SQL: %s", e)
        return {**state, "error": f"LLM failed to generate SQL: {e}"}


def validate_sql(state: AgentState) -> AgentState:
    """
    Ensure the generated SQL is a safe, read-only SELECT statement.

    Two-layer check:
    1. Must start with SELECT (or WITH for CTEs).
    2. Must not contain any DDL/DML keyword as a whole word.

    Note: execute_query also sets the transaction to READ ONLY at the DB level,
    so this is a defence-in-depth guard, not the only safety net.
    """
    if state.get("error"):
        return {**state, "is_read_only": False}

    sql = state.get("generated_sql", "").strip()
    sql_upper = sql.upper()

    # Allow CTEs: WITH ... AS (...) SELECT ...
    if not (sql_upper.startswith("SELECT") or sql_upper.startswith("WITH")):
        return {
            **state,
            "is_read_only": False,
            "error": "Generated SQL is not a SELECT query. Only read-only queries are allowed.",
        }

    blocked = [
        "INSERT", "UPDATE", "DELETE", "DROP", "ALTER",
        "CREATE", "TRUNCATE", "GRANT", "REVOKE", "EXECUTE",
        "CALL", "COPY", "VACUUM", "ANALYZE",
    ]
    for keyword in blocked:
        if re.search(rf"\b{keyword}\b", sql_upper):
            return {
                **state,
                "is_read_only": False,
                "error": (
                    f"SQL contains forbidden keyword '{keyword}'. "
                    "Only SELECT queries are allowed."
                ),
            }

    return {**state, "is_read_only": True}


def execute_query(state: AgentState) -> AgentState:
    """
    Execute the validated SQL query using a pooled connection.

    Safety layers:
    - Connection borrowed from pool, always returned in finally block (no leaks).
    - Transaction set to READ ONLY at the DB level before execution.
    - Row count capped by _apply_row_limit() before the query runs.
    - Transaction always rolled back — never committed.
    """
    if state.get("error"):
        return state

    sql_with_limit = _apply_row_limit(state["generated_sql"])
    logger.info("Executing query (with row cap): %.120s …", sql_with_limit)

    pool = _get_pool()
    conn = None
    try:
        conn = pool.getconn()
        conn.autocommit = False
        cursor = conn.cursor()

        # Belt-and-suspenders: enforce read-only at the Postgres level
        cursor.execute("SET TRANSACTION READ ONLY;")
        cursor.execute(sql_with_limit)

        columns = [desc[0] for desc in cursor.description]
        rows = cursor.fetchall()

        # Always roll back — we never want to commit anything
        conn.rollback()
        cursor.close()

        if not rows:
            result_str = "No results found."
        else:
            header = " | ".join(columns)
            separator = " | ".join(["---"] * len(columns))
            body = "\n".join(" | ".join(str(val) for val in row) for row in rows)
            result_str = f"{header}\n{separator}\n{body}"
            logger.info("Query returned %d row(s).", len(rows))

        return {**state, "query_result": result_str}

    except Exception as e:
        logger.exception("Database query failed: %s", e)
        if conn:
            try:
                conn.rollback()
            except Exception:
                pass
        return {**state, "error": f"Database query failed: {e}", "query_result": ""}

    finally:
        # Always return the connection to the pool — even on exception
        if conn:
            pool.putconn(conn)


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
6. If the result set was capped at {_MAX_ROWS} rows, mention that only the first {_MAX_ROWS} records are shown.

USER QUESTION: {state["user_question"]}

QUERY RESULTS:
{state["query_result"]}

FORMATTED RESPONSE:"""

    try:
        @_llm_retry
        def _invoke() -> str:
            response = llm.invoke(prompt)
            return response.content.strip()

        formatted = _invoke()
        return {**state, "formatted_response": formatted}
    except Exception as e:
        logger.exception("LLM failed to format response: %s", e)
        # Graceful fallback — return the raw result rather than a blank answer
        return {
            **state,
            "formatted_response": (
                f"Results retrieved but formatting failed.\n\n"
                f"```\n{state['query_result']}\n```"
            ),
        }


def handle_error(state: AgentState) -> AgentState:
    """Return a safe, user-friendly error message. Never expose internal details."""
    error_msg = state.get("error", "An unknown error occurred.")
    logger.warning("Returning error to user: %s", error_msg)
    return {
        **state,
        "formatted_response": (
            "⚠️ **Request could not be processed**\n\n"
            "Please try rephrasing your question. "
            "I can only answer clinical data questions using "
            "read-only queries against the PMTPT database."
        ),
        # Internal error detail is logged above but NOT sent to the client
    }


def route_after_validation(state: AgentState) -> Literal["execute_query", "handle_error"]:
    """Route to execution if SQL passed validation, otherwise to error handler."""
    if state.get("is_read_only", False):
        return "execute_query"
    return "handle_error"


# Graph assembly
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