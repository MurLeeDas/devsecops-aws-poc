# ── Stage 1: Build ──────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# Install dependencies in isolated layer
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ── Stage 2: Runtime (minimal attack surface) ────────────
FROM python:3.11-slim AS runtime

# Security: run as non-root user
RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup appuser

WORKDIR /app

# Copy only installed packages from builder
COPY --from=builder /root/.local /home/appuser/.local
COPY app/ .

# Security: non-root ownership
RUN chown -R appuser:appgroup /app
USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH
ENV ENV=production
ENV APP_VERSION=1.0.0

EXPOSE 5000

# Health check built into container
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]