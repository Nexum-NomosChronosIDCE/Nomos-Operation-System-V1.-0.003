# Nomos DaaS - Google Cloud Production Deployment

## Quick Start

### 1. Run Setup Script
```bash
chmod +x deployment/production-setup.sh
./deployment/production-setup.sh YOUR_GCP_PROJECT_ID us-central1
```

### 2. Add GitHub Secrets
Add to Settings → Secrets and variables → Actions:
- `GCP_PROJECT_ID`
- `PRODUCTION_SERVICE_ACCOUNT`
- `STAGING_SERVICE_ACCOUNT`
- `WIF_PROVIDER`
- `WIF_SERVICE_ACCOUNT`

### 3. Deploy
```bash
git checkout main
git merge gcp-deployment
git push origin main
```

## Deployment Pipeline

**Automatic on push to main:**
1. Build Docker image
2. Push to Container Registry
3. Deploy to Cloud Run
4. Health checks
5. Production service online

## Verify Deployment

```bash
gcloud run services describe nomos-daas-engine --platform managed --region us-central1

SERVICE_URL=$(gcloud run services describe nomos-daas-engine --platform managed --region us-central1 --format='value(status.url)')
curl $SERVICE_URL/
```

## Monitoring

```bash
# Real-time logs
gcloud logging tail 'resource.type=cloud_run_revision' -f

# Check metrics
https://console.cloud.google.com/monitoring
```

## Rollback

```bash
PREV=$(gcloud run revisions list --service=nomos-daas-engine --platform managed --region us-central1 --format='value(name)' --limit=2 | tail -1)
gcloud run services update-traffic nomos-daas-engine --to-revisions=$PREV=100 --platform managed --region us-central1
```

## Production Ready ✅