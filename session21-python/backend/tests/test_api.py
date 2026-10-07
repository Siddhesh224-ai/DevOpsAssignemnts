import os
from pathlib import Path

test_db = Path("/tmp/taskboard-test.db")
test_db.unlink(missing_ok=True)
os.environ["DATABASE_URL"] = f"sqlite:///{test_db}"

from fastapi.testclient import TestClient
from app.main import app
from app.db import Base, engine

Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)

client = TestClient(app)

def test_health():
    assert client.get("/health").json() == {"status": "UP"}

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "TaskBoard API"

def test_create_task_validation():
    response = client.post("/api/tasks", json={"title": "Deploy application", "priority": "HIGH", "assignee": "Student"})
    assert response.status_code == 201
    assert response.json()["title"] == "Deploy application"

def test_list_and_get_task():
    created = client.post("/api/tasks", json={"title": "Observe pipeline"}).json()
    listed = client.get("/api/tasks")
    assert listed.status_code == 200
    assert any(task["id"] == created["id"] for task in listed.json())
    fetched = client.get(f"/api/tasks/{created['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["title"] == "Observe pipeline"

def test_update_task():
    created = client.post("/api/tasks", json={"title": "Ship release"}).json()
    response = client.put(
        f"/api/tasks/{created['id']}",
        json={"status": "DONE", "priority": "HIGH"},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "DONE"
    assert response.json()["priority"] == "HIGH"

def test_task_stats():
    response = client.get("/api/tasks/stats")
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == body["todo"] + body["inProgress"] + body["done"]

def test_delete_task():
    created = client.post("/api/tasks", json={"title": "Temporary task"}).json()
    deleted = client.delete(f"/api/tasks/{created['id']}")
    assert deleted.status_code == 204
    assert client.get(f"/api/tasks/{created['id']}").status_code == 404
