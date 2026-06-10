#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="${1:-}"
REGION="${2:-us-central1}"
SERVICE_NAME="nomos-daas-engine"

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: PROJECT_ID required${NC}"
    echo "Usage: $0 <PROJECT_ID> [REGION]"
    exit 1
fi

echo -e "${BLUE}Nomos DaaS - Production GCP Setup${NC}"
echo -e "Project: ${GREEN}$PROJECT_ID${NC}"
echo -e "Region: ${GREEN}$REGION${NC}" 
echo ""

echo -e "${YELLOW}[1/6] Configuring GCP project...${NC}"
gcloud config set project $PROJECT_ID

echo -e "${YELLOW}[2/6] Enabling APIs...${NC}"
for api in run.googleapis.com build.googleapis.com containerregistry.googleapis.com secretmanager.googleapis.com logging.googleapis.com monitoring.googleapis.com iam.googleapis.com; do
    gcloud services enable $api --quiet 2>/dev/null || true
done
echo -e "${GREEN}✓ APIs enabled${NC}"

echo -e "${YELLOW}[3/6] Creating service accounts...${NC}"
for env in production staging; do
    SA_NAME="$SERVICE_NAME-$env"
    gcloud iam service-accounts create $SA_NAME --display-name="Nomos DaaS $env" --quiet 2>/dev/null || echo -e "${GREEN}✓ $SA_NAME exists${NC}"
done

echo -e "${YELLOW}[4/6] Configuring IAM roles...${NC}"
for env in production staging; do
    SA_EMAIL="${SERVICE_NAME}-${env}@${PROJECT_ID}.iam.gserviceaccount.com"
    for role in roles/run.admin roles/secretmanager.secretAccessor roles/logging.logWriter roles/monitoring.metricWriter; do
        gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${SA_EMAIL} --role=$role --quiet 2>/dev/null || true
    done
done
echo -e "${GREEN}✓ IAM configured${NC}"

echo -e "${YELLOW}[5/6] Creating secrets...${NC}"
read -sp "Enter Stripe Production Key: " STRIPE_KEY
echo ""

if [ -z "$STRIPE_KEY" ]; then
    echo -e "${RED}Stripe key required${NC}"
    exit 1
fi

echo -n "$STRIPE_KEY" | gcloud secrets create stripe-secret-key-production --data-file=- --quiet 2>/dev/null || echo -n "$STRIPE_KEY" | gcloud secrets versions add stripe-secret-key-production --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create system-salt-production --data-file=- --quiet 2>/dev/null || echo -n "$(openssl rand -hex 32)" | gcloud secrets versions add system-salt-production --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create ledger-signing-secret-production --data-file=- --quiet 2>/dev/null || echo -n "$(openssl rand -hex 32)" | gcloud secrets versions add ledger-signing-secret-production --data-file=-
echo -e "${GREEN}✓ Secrets created${NC}"

echo -e "${YELLOW}[6/6] Final setup...${NC}"
echo -e "${BLUE}Add these secrets to GitHub:${NC}"
echo "  GCP_PROJECT_ID: $PROJECT_ID"
echo "  PRODUCTION_SERVICE_ACCOUNT: ${SERVICE_NAME}-production@${PROJECT_ID}.iam.gserviceaccount.com"
echo "  STAGING_SERVICE_ACCOUNT: ${SERVICE_NAME}-staging@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo "Next: Push to main branch to trigger deployment"