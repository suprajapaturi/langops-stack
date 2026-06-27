import os
import base64
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
import requests

# ── OpenTelemetry → Langfuse ──────────────────────────────────────
LANGFUSE_HOST = os.getenv("LANGFUSE_HOST", "http://langfuse-web.langfuse.svc.cluster.local:3000")
LANGFUSE_PUBLIC_KEY = os.getenv("LANGFUSE_PUBLIC_KEY", "")
LANGFUSE_SECRET_KEY = os.getenv("LANGFUSE_SECRET_KEY", "")

auth = base64.b64encode(f"{LANGFUSE_PUBLIC_KEY}:{LANGFUSE_SECRET_KEY}".encode()).decode()

tracer_provider = TracerProvider()
otlp_exporter = OTLPSpanExporter(
    endpoint=f"{LANGFUSE_HOST}/api/public/otel/v1/traces",
    headers={"Authorization": f"Basic {auth}"},
)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))

app = FastAPI(title="LangOps RAG App")
FastAPIInstrumentor.instrument_app(app, tracer_provider=tracer_provider)
RequestsInstrumentor().instrument()

tracer = tracer_provider.get_tracer(__name__)

# ── Config ────────────────────────────────────────────────────────
LITELLM_URL = os.getenv("LITELLM_URL", "http://litellm.litellm.svc.cluster.local:4000")
LITELLM_API_KEY = os.getenv("LITELLM_API_KEY", "")

class QueryRequest(BaseModel):
    question: str
    model: str = "free"

class QueryResponse(BaseModel):
    question: str
    answer: str
    model: str

@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}

@app.post("/ask", response_model=QueryResponse)
async def ask(request: QueryRequest):
    with tracer.start_as_current_span(f"rag_query_{request.model}") as span:
        span.set_attribute("question", request.question)
        span.set_attribute("model", request.model)

        try:
            headers = {
                "Authorization": f"Bearer {LITELLM_API_KEY}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": request.model,
                "messages": [
                    {"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": request.question}
                ],
                "temperature": 0.7,
                "max_tokens": 500
            }

            response = requests.post(
                f"{LITELLM_URL}/chat/completions",
                json=payload,
                headers=headers,
                timeout=120
            )
            response.raise_for_status()

            data = response.json()
            answer = data["choices"][0]["message"]["content"]

            span.set_attribute("answer", answer)
            span.set_attribute("status", "success")

            return QueryResponse(
                question=request.question,
                answer=answer,
                model=request.model
            )

        except Exception as e:
            span.set_attribute("error", str(e))
            span.set_attribute("status", "error")
            raise HTTPException(status_code=500, detail=str(e))

@app.get("/models")
async def list_models():
    try:
        response = requests.get(
            f"{LITELLM_URL}/models",
            headers={"Authorization": f"Bearer {LITELLM_API_KEY}"},
            timeout=10
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)