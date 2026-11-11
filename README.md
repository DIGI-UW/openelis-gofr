# GOFR facility registry for OpenELIS Global

A minimal, tested Docker setup of [GOFR](https://github.com/intrahealth/gofr) (Global Open
Facility Registry) that OpenELIS Global can import its organization list from.

Guide: [Facility Registry (GOFR / FHIR)](https://uwdigi.atlassian.net/wiki/spaces/oeg/pages/1776975886)

## What runs

| Service | Image | Purpose |
|---|---|---|
| `gofr` | `intrahealth/gofr:7e892dd6` | GOFR app, UI and FHIR API on port 4000 |
| `fhir` | `hapiproject/hapi:v5.5.2` | Partitioned HAPI FHIR store behind GOFR (not published) |
| `hapi-cli` | `intrahealth/hapi-fhir-cli:latest` | One-shot upload of the FHIR definitions GOFR needs |
| `redis` | `redis:7.2-alpine` | GOFR cache |
| `proxy` (optional) | `nginx:1.27-alpine` | HTTPS on port 4443 |

## Start

```bash
docker compose up -d
# about a minute later:
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"username":"root@gofr.org","password":"gofr"}' http://localhost:4000/auth/token
```

The token call returns `{"access_token": "..."}`. Log in to the UI at <http://localhost:4000>
with `root@gofr.org` / `gofr` and **change that password** (Account menu).

Optional sample data (four organizations with OpenELIS organization types):

```bash
scripts/load-sample-facilities.sh            # or: scripts/load-sample-facilities.sh <url> <user> <password>
```

## HTTPS

```bash
scripts/make-cert.sh gofr.example.org        # writes certs/gofr.crt and certs/gofr.key
```

Then remove the `#` in front of `COMPOSE_PROFILES=https` in `.env` and run `docker compose up -d`.
GOFR is then also served on `https://<host>:4443`. Import `certs/gofr.crt` into the OpenELIS truststore
(see the Integration Overview page) because OpenELIS trusts only the certificates in its truststore.

## Connect OpenELIS

In the OpenELIS `configs/properties/common.properties` (openelis-docker), then
`docker compose up -d --force-recreate oe.openelis.org`:

```properties
org.openelisglobal.facilitylist.fhirstore=http://<gofr-host>:4000/fhir/DEFAULT
org.openelisglobal.facilitylist.auth=token
org.openelisglobal.facilitylist.authurl=http://<gofr-host>:4000/auth/token
org.openelisglobal.facilitylist.username=<gofr-user-email>
org.openelisglobal.facilitylist.password=<gofr-password>
facilitylist.schedule.fixedRate=86400000
```

## Facts checked with this setup

- `POST /auth/token` with a JSON username and password returns `access_token`, the field OpenELIS reads.
- `GET /fhir/DEFAULT/Organization` and `/fhir/DEFAULT/Location` with `Authorization: Bearer <token>`
  return searchset Bundles, which is what the OpenELIS import job requests.
- GOFR's FHIR API takes one resource per request and only `application/json` bodies; a transaction
  Bundle posted to `/fhir/DEFAULT` returns 404.
- GOFR creates an Organization named `Default` for its partition. OpenELIS imports it like any other
  organization; deactivate it in OpenELIS if you do not want it.
- The GOFR UI manages facilities as Locations. OpenELIS creates organizations only from Organization
  resources, so publish every facility that lab users must select as an Organization.
- The HAPI data is kept in the `hapi-data` volume.
