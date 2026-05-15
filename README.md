# TELCO — Oracle XE Docker & schema

This repository contains a ready-to-run Oracle XE setup (via Docker Compose) and the SQL needed to create the schema that exactly matches the provided CSV files.

Files added:
- `docker-compose.yml` — spins up Oracle XE and mounts initialization scripts.
- `TABLE_CREATION_SCRIPTS.sql` — drops and creates tables matching the CSV headers and types.
- `SOLUTIONS.sql` — Oracle-compatible queries that answer the functional requirements (each query includes a 3+ sentence explanation).

Quick start
1. Start the database:

```bash
docker-compose up -d
```

2. Wait for the container to finish initializing (the image runs scripts in `./oracle-init` and the mounted `TABLE_CREATION_SCRIPTS.sql`).

Connect with DBeaver
- Host: `localhost`
- Port: `1521`
- Service: `XEPDB1`
- Username: `SYSTEM`
- Password: `Oracle18` (change in `docker-compose.yml` if you set a different password)
- JDBC URL example: `jdbc:oracle:thin:@localhost:1521/XEPDB1`

Using the supplied initialization scripts
- The container runs any `.sql` files placed in `./oracle-init` or the mounted `TABLE_CREATION_SCRIPTS.sql` in `/opt/oracle/scripts/setup` at first startup. The included `TABLE_CREATION_SCRIPTS.sql` will create the three tables.

Importing the CSVs with DBeaver
1. After connecting, right-click the target table (for example `CUSTOMERS`) and choose *Import Data*.
2. Choose the CSV file (for example `i2i datas/CUSTOMERS.csv`).
3. Map columns exactly and for `SIGNUP_DATE` set the format to `dd/MM/yyyy` (the schema uses `DATE` and the scripts set `NLS_DATE_FORMAT = 'DD/MM/YYYY'`).

Running the provided queries
- Open `SOLUTIONS.sql` in DBeaver or your SQL client and run each query. Each query includes an explanation in comments.

Re-running the schema creation
- If you need to re-run the schema creation, stop and remove the container and the `oracle-data` volume, then start again:

```bash
docker-compose down -v
docker-compose up -d
```

Notes
- Change `ORACLE_PASSWORD` in `docker-compose.yml` before first run if you want a different password.
- Service name `XEPDB1` is the default pluggable database used by the image.
# TELCO Project — Oracle XE (Dockerized)

Overview
- This repository contains a Docker Compose configuration that runs Oracle XE and automatically seeds a `I2I` schema with telecom tables and sample data. Use the provided SQL file `SOLUTIONS.sql` to run the requested queries.

Prerequisites
- Docker and Docker Compose installed.

Quick start
1. Start the database:

```bash
docker-compose up -d
```

2. Follow logs until database is ready (first-time initialization runs the SQL in `./oracle-init`):

```bash
docker-compose logs -f oracle-xe
```

Connection details (for DBeaver or other clients)
- Host: `localhost`
- Port: `1521`
- Service / SID: `XE`
- Schema / User: `I2I`
- Password: `I2I_PWD`

SYS / DBA user (if needed)
- Username: `SYS`
- Password: `OraclePwd123`
- Connect as: `SYSDBA`

Notes
- The `docker-compose.yml` mounts `./oracle-init` to `/opt/oracle/scripts/setup` inside the container. Files in that directory are executed automatically when the database starts for the first time.
- The initialization script creates an `I2I` schema, DDL, indexes and inserts sample data so you can run the queries in `SOLUTIONS.sql` right away.

Reinitialize the DB
- To remove data and re-run initialization (this deletes the persisted volume):

```bash
docker-compose down -v
docker-compose up -d
```

Running the solutions
- Open `SOLUTIONS.sql` in DBeaver or run it from a SQL client connected as `I2I`.
- `SOLUTIONS.sql` begins with `ALTER SESSION SET CURRENT_SCHEMA = I2I;` so it runs cleanly against the seeded schema.

Support
- If the container doesn't start, check `docker-compose logs oracle-xe` and ensure ports are free. If re-initializing, remove the `oracle-data` volume first (see above).
