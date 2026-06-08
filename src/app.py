import os
import logging
import secrets
from contextlib import asynccontextmanager

from dotenv import load_dotenv

# Reads from local .env when present; falls back to machine env vars on Render
load_dotenv()

import psycopg2
from fastapi import FastAPI, Header, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from main import graph

# Logging — structured so Render's log viewer can parse it cleanly
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("pmtpt")

# Startup validation — fail loudly at boot, not on first request
_REQUIRED_ENV = ["DATABASE_URL", "GROQ_API_KEY","FRONTEND_URL"]

def _validate_env() -> None:
    missing = [k for k in _REQUIRED_ENV if not os.getenv(k)]
    if missing:
        raise RuntimeError(
            f"Missing required environment variables: {', '.join(missing)}. "
            "Set them in Render's Environment tab before deploying."
        )

def _validate_db() -> None:
    raw_url = os.getenv("DATABASE_URL", "")
    try:
        conn = psycopg2.connect(raw_url, connect_timeout=5)
        conn.close()
        logger.info("Database connectivity check passed.")
    except Exception as exc:
        raise RuntimeError(f"Database connectivity check failed at startup: {exc}") from exc

# Lifespan — runs startup checks before the server starts accepting traffic
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting PMTPT Clinical AI Assistant …")
    _validate_env()
    _validate_db()
    logger.info("All startup checks passed. Server is ready.")
    yield
    logger.info("Server shutting down.")

# CORS — FRONTEND_URL must be set explicitly; no silent wildcard fallback
FRONTEND_URL = os.getenv("FRONTEND_URL", "")  # Empty string → misconfiguration is obvious

if not FRONTEND_URL:
    logger.warning(
        "FRONTEND_URL is not set. CORS will block all cross-origin requests. "
        "Set it to your Vercel deployment URL in Render's Environment tab."
    )

# Rate limiter (slowapi) — 10 requests / minute per IP
limiter = Limiter(key_func=get_remote_address, default_limits=["10/minute"])
# App

app = FastAPI(
    title="PMTPT Clinical AI Assistant",
    version="1.0.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_URL] if FRONTEND_URL else [],
    allow_credentials=True,
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["Content-Type", "X-API-Key"],
)

# Auth dependency — validates X-API-Key header on protected routes
_API_KEY = os.getenv("API_KEY", "")

def _require_api_key(x_api_key: str = Header(default="")) -> None:
    if not _API_KEY:
        logger.warning("API_KEY not set — request allowed without auth.")
        return  # ← allow through instead of blocking
    if not secrets.compare_digest(x_api_key, _API_KEY):
        logger.warning("Rejected request with invalid or missing API key.")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key. Pass it as the X-API-Key header.",
        )

# Request / response models
class Question(BaseModel):
    question: str = Field(..., min_length=3, max_length=1000)

    @field_validator("question")
    @classmethod
    def no_blank(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("Question must not be blank.")
        return stripped


class AskResponse(BaseModel):
    answer: str

# Routes

@app.post(
    "/v1/ask",
    response_model=AskResponse,
    summary="Ask a clinical question",
    dependencies=[],          # auth injected explicitly below so it shows in /docs
)
@limiter.limit("10/minute")
async def ask(
    request: Request,          # required by slowapi
    q: Question,
    _: None = None,            # placeholder — real auth via Depends below
    x_api_key: str = Header(default=""),
) -> AskResponse:
    """
    Invoke the LangGraph agent with a natural language clinical question.
    Returns a Markdown-formatted clinical response.
    Requires X-API-Key header.
    """
    _require_api_key(x_api_key)

    logger.info("Received question (length=%d)", len(q.question))
    try:
        result = graph.invoke({"user_question": q.question})
    except Exception as exc:
        logger.exception("LangGraph invocation failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Something went wrong.",
        ) from exc

    answer = result.get("formatted_response", "")
    if not answer:
        logger.warning("Graph returned an empty formatted_response.")
        answer = "Something went wrong."

    # NOTE: generated_sql is intentionally NOT returned to the client.
    # Exposing it would reveal your full DB schema to browser devtools.
    return AskResponse(answer=answer)


@app.get("/health", summary="Health check for Render")
async def health() -> dict:
    """
    Render should be configured to ping this endpoint (Health Check Path = /health).
    Also validates live DB connectivity so a broken connection fails the check.
    """
    raw_url = os.getenv("DATABASE_URL", "")
    try:
        conn = psycopg2.connect(raw_url, connect_timeout=3)
        conn.close()
        db_status = "ok"
    except Exception as exc:
        logger.error("Health check DB ping failed: %s", exc)
        db_status = "unavailable"

    overall = "ok" if db_status == "ok" else "degraded"
    status_code = status.HTTP_200_OK if overall == "ok" else status.HTTP_503_SERVICE_UNAVAILABLE

    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=status_code,
        content={
            "status": overall,
            "database": db_status,
            "service": "PMTPT Clinical AI Assistant",
            "version": "1.0.0",
        },
    )


@app.get("/", summary="Root status")
async def root() -> dict:
    """Root endpoint — confirms the API is live."""
    return {
        "status": "active",
        "service": "PMTPT Clinical AI Assistant",
        "version": "1.0.0",
        "docs": "/docs",
        "usage": "POST /v1/ask  —  requires X-API-Key header",
    }