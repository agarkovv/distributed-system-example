FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip freeze

COPY run.py .

RUN mkdir -p /app/logs

EXPOSE 5000

CMD ["python", "run.py"]
