# Senior DevOps Lab API — non-root, minimal, reproducible.
#
# WHY python:3.13-slim: current stable CPython on a small Debian base.
# WHY not alpine: musl vs glibc wheel issues cost more than the MBs saved.
# WHY digest pinning is deferred: introduced in Week 6 (supply chain) with
# proper tooling; for Week 1 we pin the tag.

FROM python:3.13-slim

# Never run as root. Fixed high UID avoids clashing with host users and
# satisfies Kubernetes runAsNonRoot checks without guessing usernames.
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Friendly to read-only root filesystems: no .pyc writes, unbuffered logs.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Copy requirements first so dependency layers cache independently of code.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

USER 10001:10001

EXPOSE 8000

# Single worker is intentional for the lab: horizontal scaling is
# Kubernetes' job (replicas), not the process manager's.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
