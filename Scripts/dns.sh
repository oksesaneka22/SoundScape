#!/bin/bash

# Define variables
API_TOKEN=${API_TOKEN}
ZONE_ID=${ZONE_ID}
DOMAIN="soundscape.co.ua"

# Fetch backend and frontend DNS records from kubectl
BACKEND_DNS=$(sudo kubectl get svc -n todo-app backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
FRONTEND_DNS=$(sudo kubectl get svc -n todo-app frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Check if the DNS records were fetched successfully
if [[ -z "$BACKEND_DNS" ]] || [[ -z "$FRONTEND_DNS" ]]; then
  echo "Error: Could not fetch backend or frontend DNS records."
  exit 1
fi

# Function to delete all DNS records in the zone
delete_all_dns_records() {
  echo "Fetching all DNS records to delete..."
  # Fetch all DNS records
  RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

  # Extract DNS record IDs and delete them
  echo "$RECORDS" | jq -r '.result[].id' | while read -r record_id; do
    echo "Deleting DNS record with ID: $record_id..."
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json"
  done
}

# Delete all existing DNS records in the zone
delete_all_dns_records

# Function to create a CNAME record
create_cname_record() {
  local name=$1
  local content=$2

  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{
      "type": "CNAME",
      "name": "'"$name"'",
      "content": "'"$content"'",
      "ttl": 3600,
      "proxied": true
    }'
}

# Create CNAME record for backend
echo "Creating proxied CNAME record for backend..."
create_cname_record "back.$DOMAIN" "$BACKEND_DNS"

# Create CNAME record for frontend
echo "Creating proxied CNAME record for frontend..."
create_cname_record "$DOMAIN" "$FRONTEND_DNS"

echo "Proxied DNS records created successfully."
