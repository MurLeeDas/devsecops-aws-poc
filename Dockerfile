FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

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