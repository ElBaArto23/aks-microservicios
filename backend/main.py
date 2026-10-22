import os
import socket

import redis
from fastapi import FastAPI, HTTPException

app = FastAPI(title="API de visitas")

cache = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    socket_connect_timeout=2,
    decode_responses=True,
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/visitas")
def visitas():
    try:
        total = cache.incr("visitas")
    except redis.RedisError:
        raise HTTPException(status_code=503, detail="Redis no disponible")
    return {"visitas": total, "pod": socket.gethostname()}
