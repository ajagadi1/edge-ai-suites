#!/bin/bash

# SSL Certificate Generation Script for Nginx Helm Chart
# This script generates self-signed certificates for use in the Helm chart

CERT_DIR="./ssl-certs"
CERT_NAME="server"

# Create certificate directory
mkdir -p "$CERT_DIR"

echo "Generating self-signed SSL certificate for nginx..."

# Generate private key
openssl genrsa -out "$CERT_DIR/$CERT_NAME.key" 2048

# Generate certificate signing request
openssl req -new -key "$CERT_DIR/$CERT_NAME.key" -out "$CERT_DIR/$CERT_NAME.csr" -subj "/C=US/ST=CA/L=San Francisco/O=Intel/OU=Edge AI/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -in "$CERT_DIR/$CERT_NAME.csr" -signkey "$CERT_DIR/$CERT_NAME.key" -out "$CERT_DIR/$CERT_NAME.crt" -days 365

# Encode certificates in base64 for Kubernetes secrets
echo "Encoding certificates for Kubernetes..."
CERT_B64=$(base64 -w 0 "$CERT_DIR/$CERT_NAME.crt")
KEY_B64=$(base64 -w 0 "$CERT_DIR/$CERT_NAME.key")

# Create values override file
cat > "$CERT_DIR/ssl-values.yaml" << EOF
nginx:
  ssl:
    cert: |
      $CERT_B64
    key: |
      $KEY_B64
EOF

echo "✅ SSL certificates generated successfully!"
echo "📁 Certificates location: $CERT_DIR/"
echo "🔧 Use the following values file during helm install:"
echo "   helm install -f $CERT_DIR/ssl-values.yaml ..."

# Cleanup CSR file
rm "$CERT_DIR/$CERT_NAME.csr"

echo ""
echo "📋 Files created:"
echo "   - $CERT_DIR/$CERT_NAME.crt (certificate)"
echo "   - $CERT_DIR/$CERT_NAME.key (private key)"
echo "   - $CERT_DIR/ssl-values.yaml (Helm values override)"