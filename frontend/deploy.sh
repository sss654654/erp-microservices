#!/bin/bash
set -e

BUCKET_NAME="erp-dev-frontend-dev"
DISTRIBUTION_ID="E3HPT0O3YKLR5N"

echo "🔨 Building frontend..."
npm run build

echo "📦 Uploading to S3..."
aws s3 sync dist/ s3://$BUCKET_NAME/ --delete

if [ -n "$DISTRIBUTION_ID" ]; then
  echo "🔄 Invalidating CloudFront cache..."
  aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
fi

echo "✅ Deployment complete!"
echo "🌐 CloudFront URL: https://d95pjcr73gr6g.cloudfront.net"
