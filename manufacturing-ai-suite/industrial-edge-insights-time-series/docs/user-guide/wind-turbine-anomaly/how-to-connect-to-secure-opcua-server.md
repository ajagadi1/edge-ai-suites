
# Configuration to connect to secure External OPC UA server

This guide explains how to securely connect your application to an external OPC UA server using TLS/SSL encryption for both data ingestion and alert publishing, replacing the default built-in OPC UA server.


## Step 1: Generate TLS Certificates

Follow the below steps to generate the required certificates:

```bash
# Navigate to the application directory
cd edge-ai-suites/manufacturing-ai-suite/industrial-edge-insights-time-series

# Load environment variables
source ./.env

# Create and clean the certificates directory
mkdir -p certs
sudo rm -rf ./certs/*
cd certs

# Set your external OPC UA server hostname/IP
# Replace <YOUR_OPCUA_SERVER_IP> with your actual OPC UA server IP or hostname
EXTERNAL_OPCUA_SERVER_HOST=<YOUR_OPCUA_SERVER_IP>
```

### Generate CA Certificate
```bash
# Generate CA private key (3072-bit for better security)
openssl genrsa -out ca.key 3072

# Generate CA certificate
openssl req -new -x509 -days 365 -key ca.key -out ca_cert.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=OPCUA-CA"

# Create a copy with the expected filename
cp ca_cert.pem ca_certificate.pem
```

### Generate Server Certificate
```bash
# Generate server private key
openssl genrsa -out opcua_server.key 3072

# Generate server certificate signing request
openssl req -new -key opcua_server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$EXTERNAL_OPCUA_SERVER_HOST"

# Create extensions file for Subject Alternative Names
cat > server.ext << EOF
[v3_req]
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $EXTERNAL_OPCUA_SERVER_HOST
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Generate server certificate
openssl x509 -req -in server.csr -CA ca_certificate.pem -CAkey ca.key \
  -CAcreateserial -out opcua_server_certificate.pem -days 365 \
  -extensions v3_req -extfile server.ext

cp opcua_server.key server_key.pem
cp opcua_server_certificate.pem server_certificate.pem
# Set proper ownership
sudo chown $TIMESERIES_UID:$TIMESERIES_UID ca_certificate.pem server_key.pem server_certificate.pem
sudo chmod 664 ca_certificate.pem server_key.pem server_certificate.pem
cd ..
```

## Step 2: Configure Docker Services

Make the below changes to the `edge-ai-suites/manufacturing-ai-suite/industrial-edge-insights-time-series/docker-compose.yml` file.

### Update docker-compose.yml

Add the CA certificate volume mount to the following services in your `docker-compose.yml`:

```yaml
ia-telegraf:
  volumes:
    # ... existing volumes ...
    - ./certs/ca_certificate.pem:/run/secrets/ca_certificate.pem:ro
    - ./certs/server_key.pem:/run/secrets/server_key.pem:ro
    - ./certs/server_certificate.pem:/run/secrets/server_certificate.pem:ro

ia-time-series-analytics-microservice:
  volumes:
    # ... existing volumes ...
    - ./certs/ca_certificate.pem:/run/secrets/ca_certificate.pem:ro
    - ./certs/server_key.pem:/run/secrets/server_key.pem:ro
    - ./certs/server_certificate.pem:/run/secrets/server_certificate.pem:ro

```

### Update Network Configuration

Replace `ia-opcua-server` with your external OPC UA server's hostname/IP in the proxy settings:

```yaml
ia-telegraf:
  environment:
    no_proxy: "ia-influxdb,ia-mqtt-broker,<YOUR_OPCUA_SERVER_IP>,ia-mqtt-broker,ia-time-series-analytics-microservice,${no_proxy}"
    NO_PROXY: "ia-influxdb,ia-mqtt-broker,<YOUR_OPCUA_SERVER_IP>,ia-mqtt-broker,ia-time-series-analytics-microservice,${no_proxy}"

ia-time-series-analytics-microservice:
  environment:
    no_proxy: "ia-influxdb,ia-mqtt-broker,<YOUR_OPCUA_SERVER_IP>,localhost,${no_proxy}"
    NO_PROXY: "ia-influxdb,ia-mqtt-broker,<YOUR_OPCUA_SERVER_IP>,ia-mqtt-broker,localhost,${no_proxy}"
```

### Configure OPC UA server

Replace the `<YOUR_OPCUA_SERVER_URL>` with your external OPC UA server URL in `ia-telegraf`.
Set `OPCUA_SECURE_MODE` to `true` to use TLS/SSL in `ia-time-series-analytics-microservice`.

```yaml
ia-telegraf:
  environment:
    OPCUA_SERVER: <YOUR_OPCUA_SERVER_URL>
    # ... other environment variables ...

ia-time-series-analytics-microservice:
  environment:
    OPCUA_SECURE_MODE: true
    # ... other environment variables ...
```

## Step 3: Configure Application Settings

### 3.1 Update Telegraf Configuration

Edit your Telegraf configuration file:
`edge-ai-suites/manufacturing-ai-suite/industrial-edge-insights-time-series/apps/wind-turbine-anomaly-detection/telegraf-config/Telegraf.conf`

```toml
[[inputs.opcua]]
  ## Metric name
  name = "opcua"
  name_override = "wind-turbine-data"

  ## OPC UA Endpoint URL
  endpoint = "$OPCUA_SERVER"
  log_level = "debug"
  ## Security policy, one of "None", "Basic128Rsa15", "Basic256",
  ## "Basic256Sha256", or "auto"
  security_policy = "Basic256Sha256"

  ## Security mode, one of "None", "Sign", "SignAndEncrypt", or "auto"
  security_mode = "SignAndEncrypt"

  ## Path to cert.pem. Required when security mode or policy isn't "None".
  ## If cert path is not supplied, self-signed cert and key will be generated.
  certificate = "/run/secrets/server_certificate.pem"

  ## Path to private key.pem. Required when security mode or policy isn't "None".
  ## If key path is not supplied, self-signed cert and key will be generated.
  private_key = "/run/secrets/server_key.pem"

  ## Authentication Method, one of "Certificate", "UserName", or "Anonymous".  To
  ## authenticate using a specific ID, select 'Certificate' or 'UserName'
  auth_method = "UserName"

  ## Username and password required for auth_method = "UserName"
  username = "<USERNAME>"
  password = "<PASSWORD>"


  [[inputs.opcua.nodes]]
    name = "grid_active_power"
    namespace = "<NAMESPACE>"
    identifier_type = "i"
    identifier = "<IDENTIFIER>"
    default_tags = { source="opcua_merge" }
    # default_tags = { tag1 = "value1", tag2 = "value2" }
  [[inputs.opcua.nodes]]
    name = "wind_speed"
    namespace = "<NAMESPACE>"
    identifier_type = "i"
    identifier = "<IDENTIFIER>"
    default_tags = { source="opcua_merge" }

```

**Replace:**
- `YOUR_OPCUA_SERVER_IP` with your OPC UA server's IP or hostname
- `NAMESPACE` with your OPC UA server namespace
- `IDENTIFIER` with your OPC UA server node identifier
- `USERNAME` and `PASSWORD` with your OPC UA server credentials

> **Note:**  
> Make sure your OPC UA server exposes nodes for both `wind_speed` and `grid_active_power`. These nodes must be available for data collection.

### 3.3 Update Wind Turbine Anomaly Detection Sample app configuration

Edit your sample app config file if you want to send alerts to OPC UA server:
`edge-ai-suites/manufacturing-ai-suite/industrial-edge-insights-time-series/apps/wind-turbine-anomaly-detection/time-series-analytics-config/config.json`

```
{
  "alerts": {
    "opcua": {
            "opcua_server": "YOUR_OPCUA_SERVER",
            "namespace": <NAMESPACE>,
            "node_id": <NODE_ID>
        }
  }
}
```

**Replace:**
- `YOUR_OPCUA_SERVER` with your OPC UA server's endpoint URL
- `NAMESPACE` with your OPC UA server namespace
- `NODE_ID` with your OPC UA server node identifier

## Step 4: Configure Your External OPC UA Server

For OPC UA servers, ensure the following configuration:

1. **Security Policy**: Set to `Basic256Sha256` or higher
2. **Security Mode**: Set to `SignAndEncrypt`  
3. **Authentication**: Configure username/password authentication
4. **Certificates**: Install the generated CA certificate as trusted
5. **Server Certificate**: Use the generated server certificate
6. **Endpoint URL**: Configure as `opc.tcp://<YOUR_OPCUA_SERVER_IP>:4840/`

## Step 5: Deploy and Verify

Deploy the sample application following the steps as mentioned [here](./get-started.md#deploy-with-docker-compose)
