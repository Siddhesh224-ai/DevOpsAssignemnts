FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY app ./app

RUN useradd --create-home --uid 10001 appuser && chown -R appuser:appuser /app

USER 10001

EXPOSE 5001

CMD ["python", "app/app.py"]
