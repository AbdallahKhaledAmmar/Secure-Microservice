import os
from flask import Flask, jsonify
import redis

app = Flask(__name__)
r = redis.Redis(
    host=os.environ.get("REDIS_HOST", "redis"),
    port=6379,
    password=os.environ["REDIS_PASSWORD"],
    decode_responses=True,
)

@app.route("/")
def index():
    return jsonify(message="Secure API is up", hits=r.incr("hits"))

@app.route("/health")
def health():
    r.ping()
    return jsonify(status="ok")
