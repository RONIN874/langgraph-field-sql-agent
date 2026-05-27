import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from src.main import graph

app = FastAPI(
    title="PMTPT Clinical AI Assistant"
)
# Cross origin share
#app.add_middleware(
#    CORSMiddleware,
#    allow_origins=["*"],
#    allow_methods=["*"],
#    allow_headers=["*"],
#)


class Question(BaseModel):
    question: str


@app.post("/ask")
def ask(q: Question):
    """Invoke the LangGraph agent with a natural language question."""
    result = graph.invoke({"user_question": q.question})
    return {
        "answer": result.get("formatted_response", ""),
        "sql": result.get("generated_sql", ""),
    }


@app.get("/health")
def health():
    """Health check endpoint."""
    return {"status": "ok", "service": "PMTPT Clinical AI Assistant"}


@app.get("/")
def root():
    """Serve the frontend UI (index.html)."""
    index_path = BASE_DIR / "static" / "index.html"
    if index_path.exists():
        return FileResponse(str(index_path))
    return {"message": "PMTPT Clinical AI Assistant API is running. POST to /ask with {\"question\": \"...\"}"}
