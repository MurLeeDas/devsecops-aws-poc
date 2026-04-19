from flask import Flask, jsonify
import os
import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "service": "DevSecOps POC — Murali Doss",
        "status": "healthy",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "environment": os.getenv("ENV", "production")
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200

@app.route("/pipeline-info")
def pipeline_info():
    return jsonify({
        "pipeline": "GitHub Actions → CodePipeline → ECS Fargate",
        "security_gates": ["SAST (Bandit)", "Image Scan (Trivy)", "Secrets Manager"],
        "observability": ["CloudWatch Metrics", "CloudWatch Dashboard", "SNS Alerts"],
        "built_by": "Murali Doss — DevSecOps Consultant"
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)      # nosec B104