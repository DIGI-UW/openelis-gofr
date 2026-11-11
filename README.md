# OpenELIS Global with the GOFR facility registry

OpenELIS Global 3.3.0 (the [openelis-docker](https://github.com/DIGI-UW/openelis-docker) 3.3.0 stack)
with [GOFR](https://github.com/intrahealth/gofr), the Global Open Facility Registry. One command starts
both, loads four sample facilities into GOFR, and OpenELIS imports them as its organizations.

Guide: [Facility Registry (GOFR / FHIR)](https://uwdigi.atlassian.net/wiki/spaces/oeg/pages/1776975886)

## Start

```bash
docker compose up -d
```

The first start takes a few minutes. Then open:

| Service | URL | User : password |
|---|---|---|
| OpenELIS | <https://localhost> | `admin` : `adminADMIN!` |
| GOFR | <http://localhost:4000> | `root@gofr.org` : `gofr` |

Within about 5 minutes of the first start, the sample facilities (Central Region Health Office, Mulago
Health Centre IV, Kisenyi Health Centre IV, National Reference Laboratory) appear in OpenELIS under
**Admin > Locations & Organizations > Organizations** and as referring sites on **Add Order**.

## What runs

| Service | Image | Purpose |
|---|---|---|
| OpenELIS services | `itechuw/openelis-global-2*:3.3.0` and the rest of openelis-docker 3.3.0 | OpenELIS, its database, FHIR server, proxy, analyser Bridge |
| `gofr` | `intrahealth/gofr:7e892dd6` | GOFR app, UI and FHIR API on port 4000 |
| `gofr-fhir` | `hapiproject/hapi:v5.5.2` | Partitioned HAPI FHIR store behind GOFR (not published) |
| `gofr-hapi-cli` | `intrahealth/hapi-fhir-cli:latest` | One-shot upload of the FHIR definitions GOFR needs |
| `gofr-redis` | `redis:7.2-alpine` | GOFR cache |
| `gofr-seed` | `curlimages/curl:8.11.1` | One-shot load of `seed/organizations` into GOFR |
| `gofr-proxy` (optional) | `nginx:1.27-alpine` | HTTPS in front of GOFR on port 4443 |

## How it is wired

- OpenELIS reads the facility list from GOFR with a GOFR token
  (`configs/properties/common.properties`):

  ```properties
  org.openelisglobal.facilitylist.fhirstore=http://gofr:4000/fhir/DEFAULT
  org.openelisglobal.facilitylist.auth=token
  org.openelisglobal.facilitylist.authurl=http://gofr:4000/auth/token
  org.openelisglobal.facilitylist.username=root@gofr.org
  org.openelisglobal.facilitylist.password=gofr
  facilitylist.schedule.fixedRate=300000
  ```

- OpenELIS imports when it starts and then every `facilitylist.schedule.fixedRate` milliseconds (5
  minutes here). Each import makes the GOFR Organizations OpenELIS organizations, with their types
  (`referring clinic`, `referralLab`) and parents, and stores the GOFR Locations in the OpenELIS FHIR
  server.
- `gofr-seed` waits until GOFR issues a token, PUTs each file in `seed/organizations`, and exits.
  OpenELIS does not wait for it; the next import picks the facilities up.
- To load the sample facilities into another GOFR: `scripts/load-sample-facilities.sh <gofr-url> <user> <password>`.

## For production

- Change the GOFR account password in GOFR (account menu), then set it in `.env` (`GOFR_PASSWORD`) and in
  `org.openelisglobal.facilitylist.password`, and run `docker compose up -d --force-recreate oe.openelis.org`.
- Set `facilitylist.schedule.fixedRate` to the interval you need (the OpenELIS default is 10 days,
  `864000000`).
- Remove or replace the files in `seed/organizations`; with the folder empty, `gofr-seed` loads nothing.
- HTTPS for GOFR: `scripts/make-cert.sh gofr.example.org` (writes `certs/gofr.crt` and `certs/gofr.key`),
  remove the `#` in front of `COMPOSE_PROFILES=https` in `.env`, run `docker compose up -d`, and import
  `certs/gofr.crt` into the OpenELIS truststore (OpenELIS trusts only the certificates in its
  truststore).
- Backups, upgrades and certificates for OpenELIS work as in
  [openelis-docker](https://github.com/DIGI-UW/openelis-docker#readme). Keep the OpenELIS FHIR server
  (`fhir.openelis.org`): the import writes the GOFR Locations to it, and an import that cannot is
  rolled back as a whole.

## Facts checked with GOFR

- `POST /auth/token` with a JSON username and password returns `access_token`, the field OpenELIS reads.
- `GET /fhir/DEFAULT/Organization` and `/fhir/DEFAULT/Location` with `Authorization: Bearer <token>`
  return searchset Bundles, which is what the OpenELIS import job requests.
- GOFR's FHIR API takes one resource per request and only `application/json` bodies; a transaction
  Bundle posted to `/fhir/DEFAULT` returns 404.
- GOFR creates an Organization named `Default` for its partition. OpenELIS imports it like any other
  organization; deactivate it in OpenELIS if you do not want it.
- The GOFR UI manages facilities as Locations. OpenELIS creates organizations only from Organization
  resources, so publish every facility that lab users must select as an Organization.
