# Operations, hardening & maintenance (§12)

The SOC VLAN is your crown jewels — a compromised SIEM is worse than no SIEM.

## Rotate the default credentials (do this before anything is reachable)

**Wazuh indexer (`admin`) + dashboard (`kibanaserver`)** — these are bcrypt-coupled to
`internal_users.yml`, so you can't just edit `.env`. Use Wazuh's tool:

```bash
# generate a new hash
docker compose exec wazuh.indexer bash -c \
  '/usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "NewStrongPass"'
# put the hash into config/wazuh_indexer/internal_users.yml (admin: hash),
# put the plaintext into .env (INDEXER_PASSWORD), then re-run securityadmin:
docker compose exec wazuh.indexer bash -c '
  export INSTALLATION_DIR=/usr/share/wazuh-indexer
  $INSTALLATION_DIR/plugins/opensearch-security/tools/securityadmin.sh \
    -cd $INSTALLATION_DIR/opensearch-security/ -nhnv \
    -cacert $INSTALLATION_DIR/certs/root-ca.pem \
    -cert $INSTALLATION_DIR/certs/admin.pem \
    -key $INSTALLATION_DIR/certs/admin-key.pem'
docker compose restart wazuh.manager wazuh.dashboard
```

**Wazuh manager API (`wazuh-wui`)** — set `API_PASSWORD` in `.env` AND the matching
`password` in `config/wazuh_dashboard/wazuh.yml`, then `docker compose up -d`.

**Everything else** — TheHive (`admin@thehive.local`/`secret`), MISP
(`admin@admin.test`/`admin`), Cortex/Shuffle first-run admins, and the `play.http.secret.key`
values in the TheHive/Cortex `application.conf` (regenerate: `openssl rand -base64 64`).
Change all of them.

## Access control
- Strong creds, least privilege, MFA on the tooling where supported.
- Do not expose any of these ports beyond the SOC VLAN. Shuffle's OpenSearch runs with
  security disabled for the lab — that's only safe on an isolated management network.

## Backups & snapshots
- Snapshot VMs before each detonation.
- Back up: SIEM config, this Sigma repo (git), TheHive/MISP databases (Cassandra/Elastic,
  MariaDB), and the `.env`/certs (store secrets separately, encrypted).

## Patch discipline
- Treat updates as change management: bump the pin in `.env`, update in a snapshot you can
  roll back, verify ingestion + rules still fire, then keep.

## NTP everywhere
Non-negotiable for correlation. Point every host at the firewall or DC.

## Retention vs disk
Tune Wazuh index lifecycle (ISM/ILM) so ingest doesn't outrun storage — hot for recent,
then roll/delete. The indexer loves IOPS; put it on the fastest disk you have.

## Documentation
Keep the architecture doc, the asset inventory (`asset-inventory.md`), and the rule
catalogue (`../detections/`) in git. A SOC that isn't documented isn't reproducible.
