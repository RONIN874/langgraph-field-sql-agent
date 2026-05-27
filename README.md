# 🏥 PMTPT Clinical AI Assistant

> **An AI-powered natural language interface for querying the Programmatic Management of Tuberculosis Preventive Treatment (PMTPT) database in India.**

Ask clinical questions in plain English and get instant, formatted answers — powered by LangGraph, Groq (Llama 3.3 70B), and a PostgreSQL database modelled on the 2021 PMTPT India guidelines.

---

## ✨ Features

- **Natural Language Querying** — Ask questions about patients, regimens, adverse events, drug interactions, and more in everyday English.
- **Agentic SQL Generation** — A multi-node LangGraph agent translates questions into validated, read-only SQL.
- **Safety-First Design** — Only `SELECT` queries are allowed; blocked keywords (`INSERT`, `DELETE`, `DROP`, etc.) are rejected at validation.
- **Rich Markdown Responses** — Results are formatted into clean clinical tables and bullet points by the LLM.
- **Interactive Chat UI** — A polished, single-page chat interface with typing animations, SQL accordion reveal, and Markdown rendering.
- **Health Check Endpoint** — Built-in `/health` route for monitoring.

---

## 🏗️ Architecture

The system uses a **LangGraph state-machine** with the following node pipeline:

```
┌──────────────────┐
│  receive_question │  ← Validate user input
└────────┬─────────┘
         │
┌────────▼─────────┐
│   fetch_schema    │  ← Pull live table schemas from PostgreSQL
└────────┬─────────┘
         │
┌────────▼─────────┐
│   generate_sql    │  ← LLM generates a SELECT query
└────────┬─────────┘
         │
┌────────▼─────────┐
│   validate_sql    │  ← Ensure read-only, no forbidden keywords
└────────┬─────────┘
         │
    ┌────┴────┐
    │ Router  │
    └─┬─────┬─┘
      │     │
 Safe │     │ Unsafe
      │     │
┌─────▼──┐ ┌▼───────────┐
│execute  │ │handle_error│
│ _query  │ │            │
└────┬────┘ └─────┬──────┘
     │            │
┌────▼────┐       │
│ format  │       │
│_response│       │
└────┬────┘       │
     │            │
     └─────┬──────┘
           │
         [END]
```

---

## 📁 Project Structure

```
langgraph-field-sql-agent/
├── src/                            # Application source code
│   ├── __init__.py
│   ├── app.py                      # FastAPI application & API routes
│   ├── main.py                     # LangGraph agent definition & nodes
│   ├── config.py                   # Database connection configuration
│   └── db_setup.py                 # One-time database schema & seed loader
│
├── static/                         # Frontend assets
│   └── index.html                  # Chat UI (Tailwind CSS + vanilla JS)
│
├── sql/                            # Database scripts
│   ├── pmtpt_schema.sql            # Full database schema (26 tables, 3 views)
│   ├── pmtpt_seed_data.sql         # Seed data based on PMTPT India 2021 guidelines
│   └── privilages.sql              # PostgreSQL role & read-only privileges
│
├── tests/                          # Test scripts
│   └── test.py                     # Standalone test script (LangChain SQL agent)
│
├── notebooks/                      # Jupyter notebooks
│   └── langgraph_visualization.ipynb  # LangGraph workflow visualization
│
├── docs/                           # Documentation & reference
│   └── pmtpt_questions_and_answers.txt  # 100+ reference Q&A pairs
│
├── .env                            # Environment variables (GROQ_API_KEY)
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

| Requirement    | Version       |
|----------------|---------------|
| Python         | 3.10+         |
| PostgreSQL     | 14+           |
| Groq API Key   | [Get one here](https://console.groq.com/) |

### 1. Clone the Repository

```bash
git clone https://github.com/RONIN874/langgraph-field-sql-agent.git
cd langgraph-field-sql-agent
```

### 2. Install Python Dependencies

```bash
pip install fastapi uvicorn python-dotenv psycopg2-binary langgraph langchain-community langchain-groq pydantic sqlalchemy
```

### 3. Set Up PostgreSQL

Create the database and the read-only role:

```sql
CREATE DATABASE tb_db;
```

Then run the privileges script to create the `tb_ai_reader` role:

```bash
psql -U postgres -d tb_db -f sql/privilages.sql
```

### 4. Load Schema & Seed Data

```bash
python -m src.db_setup
```

This will create all 26 tables, 3 views, and populate them with seed data based on the PMTPT India 2021 guidelines.

### 5. Configure Environment Variables

Create a `.env` file in the project root:

```env
GROQ_API_KEY=your_groq_api_key_here

DB_HOST=localhost
DB_PORT=5432
DB_USER=tb_ai_reader
DB_PASSWORD=your_db_password_here
DB_NAME=tb_db
```

### 6. Run the Application

```bash
uvicorn src.app:app --reload
```

Open **http://localhost:8000** in your browser to access the chat interface.

---

## 🔌 API Reference

### `POST /ask`

Send a natural language question and receive a formatted clinical response.

**Request:**
```json
{
  "question": "List all patients currently active on TPT"
}
```

**Response:**
```json
{
  "answer": "| Patient | Regimen | Status |\n|---|---|---|\n| Priya Patil | 6H | Active |",
  "sql": "SELECT p.first_name, r.regimen_code, e.current_status FROM tpt_enrolments e JOIN persons p ON ..."
}
```

### `GET /health`

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "service": "PMTPT Clinical AI Assistant"
}
```

### `GET /`

Serves the chat UI (`static/index.html`) if present, otherwise returns a JSON message.

---

## 🗃️ Database Schema Overview

The database is organized into **6 sections** with **26 tables** and **3 views**:

| Section | Tables | Description |
|---------|--------|-------------|
| **Reference Data** | `states`, `districts`, `tb_units`, `health_facilities`, `tpt_regimens`, `drug_formulations`, `tbi_tests`, `risk_groups`, `adverse_events_catalogue`, `drug_interactions`, `treatment_outcome_types` | Lookup tables for geography, regimens, tests, and risk groups |
| **Persons & Patients** | `persons`, `index_tb_patients`, `contacts` | Patient registry, index TB cases, and contact tracing |
| **Clinical Workflow** | `tb_screenings`, `tbi_test_results`, `tpt_eligibility_assessments`, `tpt_enrolments`, `tpt_dose_records`, `followup_visits`, `adverse_event_reports`, `treatment_interruptions` | Full TPT care cascade from screening to follow-up |
| **Supply Chain** | `supply_chain_levels`, `drug_stock` | Drug inventory and supply chain hierarchy |
| **Monitoring** | `monitoring_indicators`, `indicator_reports` | Programme performance indicators and reports |

**Views:**
- `v_active_tpt_enrolments` — Active enrolments with patient and regimen details
- `v_tpt_cascade_district` — TPT care cascade summary per district
- `v_drug_interactions_summary` — Drug interaction quick-reference lookup

---

## 🛡️ Safety & Security

- **Read-only queries only** — The agent validates every generated SQL statement against a blocklist of dangerous keywords (`INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, `TRUNCATE`, `GRANT`, `REVOKE`).
- **Transaction-level enforcement** — Queries execute with `SET TRANSACTION READ ONLY`.
- **Least-privilege database role** — The `tb_ai_reader` role has `SELECT`-only permissions.
- **No raw SQL exposure** — SQL is hidden behind an expandable accordion in the UI; clinical responses are presented in plain language.

---

## 🧰 Tech Stack

| Layer      | Technology |
|------------|------------|
| **LLM**    | Groq Cloud — Llama 3.3 70B Versatile |
| **Agent**  | LangGraph (StateGraph) |
| **Backend**| FastAPI + Uvicorn |
| **Database**| PostgreSQL + psycopg2 |
| **Frontend**| HTML + Tailwind CSS + Vanilla JavaScript |
| **Schema Introspection** | LangChain `SQLDatabase` |

---

## 📋 Example Questions

Here are some questions you can try in the chat:

| Category | Example Question |
|----------|-----------------|
| Geography | *"How many districts are in Maharashtra?"* |
| Patients | *"List all patients who are currently active on TPT"* |
| Regimens | *"What drugs are used in the 3HP regimen?"* |
| Adverse Events | *"Which adverse events require stopping TPT?"* |
| Drug Interactions | *"Can Rifamycin be used with Nevirapine-based ART?"* |
| Supply Chain | *"Which facility has the most 6H courses in stock?"* |
| Monitoring | *"What was the TPT coverage in Mumbai for Q1 2024?"* |
| Clinical Cascade | *"Trace the care cascade for Priya Patil"* |

> 💡 Over **100 reference Q&A pairs** are available in [`pmtpt_questions_and_answers.txt`](docs/pmtpt_questions_and_answers.txt) for validation and testing.

---

## 📜 Clinical Reference

This project is based on the **Guidelines for Programmatic Management of TB Preventive Treatment in India, 2021**, published by the Ministry of Health & Family Welfare (MoHFW), Government of India, in collaboration with WHO.

---

## ⚠️ Disclaimer

This tool is a **proof-of-concept** for clinical data querying and is **not** intended for production clinical decision-making. AI-generated SQL may not always be accurate — always verify critical queries independently.

---

## 📄 License

This project is for educational and demonstration purposes.
