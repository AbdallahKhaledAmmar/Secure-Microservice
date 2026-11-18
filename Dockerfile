# ---- First Stage : The builder ----
FROM python:3.13-alpine AS builder
WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip setuptools wheel

# ---- Second Stage : The minimal runtime ----
FROM python:3.13-alpine AS runtime
RUN apk upgrade --no-cache \
 && rm -rf /usr/local/lib/python3.13/site-packages/pip* \
           /usr/local/lib/python3.13/site-packages/setuptools* \
           /usr/local/lib/python3.13/site-packages/wheel* \
           /usr/local/lib/python3.13/site-packages/_distutils_hack* \
           /usr/local/lib/python3.13/site-packages/pkg_resources* \
 && addgroup -S app && adduser -S -G app -H -s /sbin/nologin appuser
COPY --from=builder --chown=appuser:app /opt/venv /opt/venv
WORKDIR /app
COPY --chown=appuser:app app.py .
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
