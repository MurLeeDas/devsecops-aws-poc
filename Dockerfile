FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /app

# Fix CVE-2026-28390 — update OpenSSL via apt
# Fix CVE-2026-23949 and CVE-2026-24049 — update pip packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Fix Python CVEs — upgrade wheel and setuptools to patched versions
RUN pip install --no-cache-dir --upgrade \
    pip \
    "wheel>=0.46.2" \
    "setuptools>=80.0.0" && \
    pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup appuser
RUN chown -R appuser:appgroup /app
USER appuser

ENV ENV=production
ENV APP_VERSION=1.0.0

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
