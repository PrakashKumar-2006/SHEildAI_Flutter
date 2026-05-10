FROM python:3.10-slim

WORKDIR /app

# System dependencies for scikit-learn & scientific modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all resources including the .pkl payload
COPY . .

# Expose API port (Hugging Face Spaces require 7860)
EXPOSE 7860

# Start Uvicorn engine
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port 7860 --workers 1"]
