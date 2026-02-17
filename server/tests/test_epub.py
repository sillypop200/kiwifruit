"""Integration tests for the epub upload and parsing endpoints."""

import io
import os
import time
import shutil
import sqlite3
import tempfile
import uuid

import pytest
from ebooklib import epub as epub_lib

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_epub(title="Test Book", author="Test Author", chapters=None):
    """Build a minimal valid .epub file in memory and return its bytes.

    :param title: Book title metadata.
    :param author: Book author metadata.
    :param chapters: List of (chapter_title, html_body) tuples.
                     Defaults to two simple chapters.
    :returns: Bytes of the .epub file.
    """
    if chapters is None:
        chapters = [
            ("Chapter 1", "<h1>Chapter 1</h1><p>First chapter text.</p>"),
            ("Chapter 2", "<h2>Chapter 2</h2><p>Second chapter text.</p>"),
        ]

    book = epub_lib.EpubBook()
    book.set_identifier(uuid.uuid4().hex)
    book.set_title(title)
    book.set_language('en')
    book.add_author(author)

    spine = ['nav']
    items = []
    for i, (ch_title, html_body) in enumerate(chapters, 1):
        ch = epub_lib.EpubHtml(title=ch_title, file_name=f'ch{i}.xhtml', lang='en')
        ch.content = f'<html><body>{html_body}</body></html>'
        book.add_item(ch)
        items.append(ch)
        spine.append(ch)

    book.toc = items
    book.add_item(epub_lib.EpubNcx())
    book.add_item(epub_lib.EpubNav())
    book.spine = spine

    tmp = tempfile.NamedTemporaryFile(suffix='.epub', delete=False)
    tmp.close()
    epub_lib.write_epub(tmp.name, book)
    with open(tmp.name, 'rb') as f:
        data = f.read()
    os.unlink(tmp.name)
    return data


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def app_client(tmp_path):
    """Create a Flask test client backed by a temporary database and uploads dir."""
    # Import app module and override paths before any request
    import server.app as app_module

    original_db_path = app_module.DB_PATH
    original_upload_folder = app_module.UPLOAD_FOLDER

    db_path = str(tmp_path / 'test.db')
    upload_dir = str(tmp_path / 'uploads')
    os.makedirs(upload_dir, exist_ok=True)

    app_module.DB_PATH = db_path
    app_module.UPLOAD_FOLDER = upload_dir
    app_module.app.config['UPLOAD_FOLDER'] = upload_dir
    app_module.app.config['TESTING'] = True

    # Initialize the database with schema
    with app_module.app.app_context():
        db = sqlite3.connect(db_path)
        db.row_factory = sqlite3.Row
        schema_path = os.path.join(os.path.dirname(app_module.__file__), 'schema.sql')
        with open(schema_path, 'r') as f:
            db.executescript(f.read())

        # Seed a test user and session token
        db.execute(
            "INSERT INTO users (username, fullname, email, filename, password) "
            "VALUES (?, ?, ?, ?, ?)",
            ('testuser', 'Test User', 'test@example.com', 'default.jpg', 'password')
        )
        db.execute(
            "INSERT INTO sessions (token, username) VALUES (?, ?)",
            ('test-token', 'testuser')
        )
        db.commit()
        db.close()

    client = app_module.app.test_client()

    yield client, app_module

    # Restore original paths
    app_module.DB_PATH = original_db_path
    app_module.UPLOAD_FOLDER = original_upload_folder
    app_module.app.config['UPLOAD_FOLDER'] = original_upload_folder


def _auth_header():
    return {'Authorization': 'Bearer test-token'}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestEpubUpload:
    """Tests for POST /api/epub."""

    def test_upload_success(self, app_client):
        client, app_module = app_client
        epub_bytes = _make_epub(title="My Book", author="Jane Doe")

        resp = client.post(
            '/api/epub',
            data={'file': (io.BytesIO(epub_bytes), 'mybook.epub')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )

        assert resp.status_code == 201
        data = resp.get_json()
        assert data['title'] == 'My Book'
        assert data['author'] == 'Jane Doe'
        assert data['status'] == 'LOADING'
        assert data['originalFilename'] == 'mybook.epub'
        assert 'id' in data
        assert 'createdAt' in data

    def test_upload_no_auth(self, app_client):
        client, _ = app_client
        epub_bytes = _make_epub()

        resp = client.post(
            '/api/epub',
            data={'file': (io.BytesIO(epub_bytes), 'book.epub')},
            content_type='multipart/form-data'
        )

        assert resp.status_code == 403

    def test_upload_wrong_extension(self, app_client):
        client, _ = app_client

        resp = client.post(
            '/api/epub',
            data={'file': (io.BytesIO(b'not an epub'), 'book.txt')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )

        assert resp.status_code == 400
        data = resp.get_json()
        assert data['error'] == 'invalid_file_type'

    def test_upload_missing_file(self, app_client):
        client, _ = app_client

        resp = client.post(
            '/api/epub',
            data={},
            content_type='multipart/form-data',
            headers=_auth_header()
        )

        assert resp.status_code == 400

    def test_upload_empty_filename(self, app_client):
        client, _ = app_client

        resp = client.post(
            '/api/epub',
            data={'file': (io.BytesIO(b''), '')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )

        assert resp.status_code == 400


class TestEpubDetail:
    """Tests for GET /api/epub/<epub_id>."""

    def test_get_epub_status(self, app_client):
        client, _ = app_client
        epub_bytes = _make_epub(title="Status Book", author="Author A")

        upload_resp = client.post(
            '/api/epub',
            data={'file': (io.BytesIO(epub_bytes), 'status.epub')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )
        epub_id = upload_resp.get_json()['id']

        resp = client.get(f'/api/epub/{epub_id}', headers=_auth_header())

        assert resp.status_code == 200
        data = resp.get_json()
        assert data['id'] == epub_id
        assert data['title'] == 'Status Book'
        assert data['author'] == 'Author A'
        assert data['status'] in ('LOADING', 'PARSED')
        assert 'chapterCount' in data

    def test_get_epub_not_found(self, app_client):
        client, _ = app_client

        resp = client.get('/api/epub/99999', headers=_auth_header())
        assert resp.status_code == 404

    def test_get_epub_no_auth(self, app_client):
        client, _ = app_client

        resp = client.get('/api/epub/1')
        assert resp.status_code == 403


class TestEpubParsing:
    """Tests for background parsing and chapter retrieval."""

    def _wait_for_parsed(self, client, epub_id, timeout=5):
        """Poll until epub status is no longer LOADING."""
        start = time.time()
        while time.time() - start < timeout:
            resp = client.get(f'/api/epub/{epub_id}', headers=_auth_header())
            data = resp.get_json()
            if data['status'] != 'LOADING':
                return data
            time.sleep(0.1)
        return data

    def test_parsing_completes_and_chapters_available(self, app_client):
        client, app_module = app_client
        epub_bytes = _make_epub(
            title="Parsed Book",
            author="Author B",
            chapters=[
                ("Ch 1", "<h1>Chapter One</h1><p>Hello world.</p>"),
                ("Ch 2", "<h1>Chapter Two</h1><p>Goodbye world.</p>"),
                ("Ch 3", "<h1>Chapter Three</h1><p>Middle content.</p>"),
            ]
        )

        upload_resp = client.post(
            '/api/epub',
            data={'file': (io.BytesIO(epub_bytes), 'parsed.epub')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )
        epub_id = upload_resp.get_json()['id']

        # Wait for parsing to complete
        status_data = self._wait_for_parsed(client, epub_id)
        assert status_data['status'] == 'PARSED'
        assert status_data['chapterCount'] == 3

        # Fetch chapters
        resp = client.get(f'/api/epub/{epub_id}/chapters', headers=_auth_header())
        assert resp.status_code == 200
        chapters = resp.get_json()
        assert len(chapters) == 3
        assert chapters[0]['chapterNumber'] == 1
        assert chapters[0]['title'] == 'Chapter One'
        assert chapters[2]['chapterNumber'] == 3
        assert 'filename' in chapters[0]

        # Verify the .txt file exists on disk
        txt_path = os.path.join(app_module.UPLOAD_FOLDER, chapters[0]['filename'])
        assert os.path.exists(txt_path)
        with open(txt_path, 'r') as f:
            text = f.read()
        assert 'Hello world' in text

    def test_chapters_while_loading_returns_409(self, app_client):
        client, app_module = app_client

        # Insert an epub record directly with LOADING status (no background thread)
        db = sqlite3.connect(app_module.DB_PATH)
        db.execute(
            "INSERT INTO epubs (owner, title, author, original_filename, stored_filename, status) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            ('testuser', 'Loading Book', '', 'loading.epub', 'fake.epub', 'LOADING')
        )
        db.commit()
        epubid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
        db.close()

        resp = client.get(f'/api/epub/{epubid}/chapters', headers=_auth_header())
        assert resp.status_code == 409
        assert resp.get_json()['error'] == 'epub_still_loading'

    def test_chapters_when_failed_returns_409(self, app_client):
        client, app_module = app_client

        db = sqlite3.connect(app_module.DB_PATH)
        db.execute(
            "INSERT INTO epubs (owner, title, author, original_filename, stored_filename, status, error_message) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            ('testuser', 'Failed Book', '', 'failed.epub', 'fake.epub', 'FAILED', 'parse error')
        )
        db.commit()
        epubid = db.execute("SELECT last_insert_rowid()").fetchone()[0]
        db.close()

        resp = client.get(f'/api/epub/{epubid}/chapters', headers=_auth_header())
        assert resp.status_code == 409
        assert resp.get_json()['error'] == 'epub_parse_failed'


class TestEpubList:
    """Tests for GET /api/epubs."""

    def test_list_epubs(self, app_client):
        client, _ = app_client
        epub_bytes1 = _make_epub(title="Book One", author="Author 1")
        epub_bytes2 = _make_epub(title="Book Two", author="Author 2")

        client.post(
            '/api/epub',
            data={'file': (io.BytesIO(epub_bytes1), 'book1.epub')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )
        client.post(
            '/api/epub',
            data={'file': (io.BytesIO(epub_bytes2), 'book2.epub')},
            content_type='multipart/form-data',
            headers=_auth_header()
        )

        resp = client.get('/api/epubs', headers=_auth_header())
        assert resp.status_code == 200
        epubs = resp.get_json()
        assert len(epubs) == 2
        titles = {e['title'] for e in epubs}
        assert 'Book One' in titles
        assert 'Book Two' in titles

    def test_list_epubs_no_auth(self, app_client):
        client, _ = app_client

        resp = client.get('/api/epubs')
        assert resp.status_code == 403

    def test_list_epubs_empty(self, app_client):
        client, _ = app_client

        resp = client.get('/api/epubs', headers=_auth_header())
        assert resp.status_code == 200
        assert resp.get_json() == []
