# Python 3.10 base
FROM python:3.10-slim

# System deps for OpenCV, torch, etc. (no dlib needed now)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libopenblas-dev \
    liblapack-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Workdir
WORKDIR /app

# Copy only backend folder (including model)
COPY backend/ ./backend/

# Move into backend
WORKDIR /app/backend

# Install Python deps
RUN pip install --upgrade pip
RUN pip install -r requirements-docker.txt

# Expose app port
EXPOSE 8000
ENV PORT=8000

# Start with gunicorn
CMD ["gunicorn", "server:app", "--bind", "0.0.0.0:8000", "--workers", "1"]
