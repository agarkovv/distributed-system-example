import json
import logging
import os
import socket
from datetime import datetime

import flask
from flask import request
from kubernetes import client, config

POD_NAME = socket.gethostname()

app = flask.Flask(__name__)

try:
    config.load_incluster_config()
    v1 = client.CoreV1Api()
    config_map = v1.read_namespaced_config_map(name="app-config", namespace="default")

    app.config["LOG_LEVEL"] = config_map.data.get("log_level", "INFO")
    app.config["PORT"] = int(config_map.data.get("port", 5000))
    app.config["GREETING_HEADER"] = config_map.data.get(
        "greeting_header", "Welcome to the custom app"
    )
    app.config["LOG_FILE"] = config_map.data.get("log_file", "/app/logs/app.log")
except Exception as e:
    print(f"Using default configuration: {str(e)}")
    app.config["LOG_LEVEL"] = os.environ.get("LOG_LEVEL", "INFO")
    app.config["PORT"] = int(os.environ.get("PORT", 5000))
    app.config["GREETING_HEADER"] = os.environ.get(
        "GREETING_HEADER", "Welcome to the custom app"
    )
    app.config["LOG_FILE"] = os.environ.get("LOG_FILE", "/app/logs/app.log")

log_dir = os.path.dirname(app.config["LOG_FILE"])
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    level=getattr(logging, app.config["LOG_LEVEL"]),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler(app.config["LOG_FILE"]), logging.StreamHandler()],
)
logger = logging.getLogger(__name__)


@app.route("/")
def index():
    return f"{app.config['GREETING_HEADER']} from pod: {POD_NAME}"


@app.route("/status")
def status():
    return flask.jsonify({"status": "ok", "pod": POD_NAME})


@app.route("/log", methods=["POST"])
def log_message():
    try:
        data = request.get_json()
        if not data or "message" not in data:
            return (
                flask.jsonify({"error": "Missing message parameter", "pod": POD_NAME}),
                400,
            )

        message = data["message"]
        timestamp = datetime.now().isoformat()
        log_entry = f"[{timestamp}] {message} (logged by {POD_NAME})\n"

        with open(app.config["LOG_FILE"], "a") as log_file:
            log_file.write(log_entry)

        logger.info(f"Log entry added: {message}")
        return flask.jsonify({"success": True, "pod": POD_NAME}), 201
    except Exception as e:
        logger.error(f"Error logging message: {str(e)}")
        return flask.jsonify({"error": str(e), "pod": POD_NAME}), 500


@app.route("/logs", methods=["GET"])
def get_logs():
    try:
        if not os.path.exists(app.config["LOG_FILE"]):
            return flask.jsonify({"logs": "", "pod": POD_NAME}), 200

        with open(app.config["LOG_FILE"], "r") as log_file:
            logs = log_file.read()

        return flask.jsonify({"logs": logs, "pod": POD_NAME}), 200
    except Exception as e:
        logger.error(f"Error reading logs: {str(e)}")
        return flask.jsonify({"error": str(e), "pod": POD_NAME}), 500


if __name__ == "__main__":
    logger.info(
        f"Starting application on pod {POD_NAME} with port {app.config['PORT']}"
    )
    app.run(debug=True, host="0.0.0.0", port=app.config["PORT"])
