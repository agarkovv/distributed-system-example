Flask REST API Application
A simple Flask application with REST API endpoints and ConfigMap integration for Kubernetes.

## Features
- GET / - Returns a welcome message (configurable via ConfigMap)
- GET /status - Returns JSON {"status": "ok"}
- POST /log - Accepts JSON {"message": "some log"} and writes it to the log file
- GET /logs - Returns the contents of the log file

## Quick Start

### Install dependencies
pip install -r requirements.txt

### Run locally
python run.py

## Deploy to Kubernetes (all components)
./deploy.sh
