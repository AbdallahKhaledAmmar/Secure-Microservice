# Secure Multi-Tier Microservice

A containerized Flask API backed by Redis. The project focuses on small images, privilege separation, network isolation, and vulnerability scanning before deployment.

## Architecture

```
Host :8000 ──► [ app (Flask + Gunicorn) ] ──► [ redis ]
                 frontend + backend nets        backend net only
                                                (internal, no published ports)
```

- **app**: Flask API served by Gunicorn, runs as a non-root user.
- **redis**: password-protected, data persisted in a named volume, reachable only from the `app` container.

## Security highlights

| Control | Implementation |
|---|---|
| Multi-stage build | Build tooling stays in the builder stage; only the virtualenv is copied into the runtime image |
| Minimal base | `python:3.13-alpine` |
| Non-root execution | `appuser` is created and set with `USER` before `CMD`; files are owned via `--chown` |
| No baked-in secrets | Password comes from `.env` at runtime; `.env` is git-ignored and excluded by `.dockerignore` |
| Database isolation | Redis publishes no ports and sits on an `internal: true` network |
| Image scanning | Trivy scan with `--exit-code 1 --severity CRITICAL,HIGH` returns 0 vulnerabilities |
| Healthchecks | Both services report `healthy`; `depends_on` waits for Redis to be healthy |

## Project structure

```
.
├── app.py
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .gitignore
├── .env.example
├── screenshots/
└── README.md
```

## Getting started

```bash
git clone https://github.com/AbdallahKhaledAmmar/secure-microservice.git
cd secure-microservice

cp .env.example .env
# edit .env and set a strong REDIS_PASSWORD
# (e.g. openssl rand -hex 16)

docker compose up -d --build
docker compose ps
curl localhost:8000
```

Each request increments a hit counter stored in Redis:

```json
{"hits": 2, "message": "Secure API is up"}
```

## Verification

```bash
# Container runs as non-root
docker compose exec app id

# Redis is not reachable from the host (should fail)
nc -zv localhost 6379

# Data persists across container recreation
docker compose down && docker compose up -d
curl localhost:8000        # counter continues, does not reset

# Vulnerability scan (expect: 0 findings, exit code 0)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --exit-code 1 --severity CRITICAL,HIGH secure-api:1.0
```

## Security scan: what I found and fixed

The first Trivy scan reported 5 HIGH findings in Python packages (`msgpack`, `setuptools`, `urllib3`), even though the OS layer was clean. I fixed this by upgrading the packaging tools in the builder stage, removing leftover system `pip`/`setuptools` metadata from the runtime stage, and rebuilding with `--no-cache`. The re-scan reported zero High/Critical vulnerabilities.

## Evidence

| Requirement | Screenshot |
|---|---|
| Multi-stage Dockerfile, non-root user | ![Dockerfile](screenshots/01-dockerfile.png) |
| `docker compose ps`, both healthy, and API response | ![Compose](screenshots/02-compose-ps.png) |
| Non-root `id`, Redis not exposed, image size | ![Security](screenshots/03-security.png) |
| Trivy: zero High/Critical | ![Trivy](screenshots/04-trivy.png) |

## Cleanup

```bash
docker compose down -v
docker system prune -a --volumes
```

## Tech stack

Docker, Docker Compose, Python 3.13 (Flask, Gunicorn), Redis 7, Alpine Linux, Trivy.
