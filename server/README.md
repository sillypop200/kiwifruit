This folder contains a minimal Flask example server for local development.

Setup
- Create a virtualenv and install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

- Initialize the SQLite database and start the server:

```bash
python app.py
```

Notes
- Database schema is in `schema.sql`. On first run the server will create `kiwifruit.db`.
- Uploaded images are saved to `uploads/` and served at `/uploads/<filename>`.

Important: if you have an existing `kiwifruit.db` from a previous schema version, remove it so the server can recreate the database from `schema.sql`:

```bash
rm kiwifruit.db
python app.py
```
