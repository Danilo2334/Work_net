FROM python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements-production.txt /app/requirements-production.txt
RUN pip install --require-hashes -r requirements-production.txt \
    && useradd --uid 10001 --create-home worknet
COPY --chown=worknet:worknet . /app
RUN mkdir -p /app/staticfiles && chown worknet:worknet /app/staticfiles
USER worknet
ENV DJANGO_SETTINGS_MODULE=config.production
EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "2", "--timeout", "90", "--graceful-timeout", "30", "--error-logfile", "-"]
