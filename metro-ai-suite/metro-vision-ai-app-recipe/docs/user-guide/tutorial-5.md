# Customizing Node-RED Flows for Crowd Analytics Applications

<!--
**Sample Description**: This tutorial demonstrates how to customize Node-RED flows to process vehicle detection data and implement crowd analytics logic, enabling real-time crowd formation detection and proximity analysis.
-->

This tutorial guides you through customizing Node-RED flows to implement crowd analytics logic for vehicle detection data. You'll learn how to connect to MQTT data streams from the crowd analytics pipeline, calculate vehicle proximities using Euclidean distances, detect crowd formations, and create enhanced analytics outputs.

<!--
**What You Can Do**: This guide covers the complete workflow for implementing crowd detection algorithms in Node-RED.
-->

By following this guide, you will learn how to:
- **Access and Launch Node-RED**: Connect to the Node-RED interface for crowd analytics flow development
- **Clear and Reset Flows**: Remove existing flows and start with a clean workspace
- **Connect to Vehicle Detection Data**: Establish connections to receive real-time vehicle detection data from the crowd analytics pipeline
- **Implement Crowd Detection Logic**: Calculate inter-vehicle distances and detect crowd formations using custom algorithms
- **Generate Crowd Analytics**: Create real-time crowd metrics, density calculations, and proximity alerts

## Prerequisites

- Complete [Tutorial 4 - AI Crowd Analytics System](./tutorial-4.md) to have a running crowd analytics application
- Verify that your crowd analytics application is running and producing MQTT vehicle detection data
- Basic understanding of Node-RED flow-based programming concepts
- Familiarity with coordinate geometry and distance calculations
- Understanding of crowd dynamics and proximity thresholds

## Crowd Analytics Flow Architecture Overview

The custom Node-RED flow implements crowd detection algorithms:
- **MQTT Input Node**: Subscribes to vehicle detection data from YOLOv10s pipeline
- **Vehicle Position Extractor**: Parses bounding box coordinates to calculate centroids
- **Distance Calculator**: Computes Euclidean distances between all vehicle pairs
- **Crowd Detector**: Applies proximity thresholds to identify crowd formations
- **Analytics Generator**: Creates crowd metrics, density maps, and alerts
- **MQTT Output Node**: Publishes crowd analytics data to visualization systems

## Set up and First Use

### 1. **Access the Node-RED Interface**

Launch Node-RED in your web browser using your host system's IP address:

```bash
# Find your host IP address if needed
hostname -I | awk '{print $1}'
```

Open your web browser and navigate to the Node-RED interface:
```
https://localhost/nodered/
```

Or using your host IP:
```
http://<HOST_IP>:1880
```

Replace `<HOST_IP>` with your actual system IP address.

<details>
<summary>
Troubleshooting Node-RED Access
</summary>

If you cannot access Node-RED:
1. Verify the crowd analytics application is running:
   ```bash
   docker ps | grep node-red
   ```
2. Check that port 1880 is exposed and accessible
3. Ensure no firewall is blocking the connection
4. Try accessing via localhost if running on the same machine

</details>

### 2. **Clear Existing Node-RED Flows**

Remove any existing flows to start with a clean workspace:

1. **Select All Flows**: Press `Ctrl+A` (or `Cmd+A` on Mac) to select all nodes in the current flow
2. **Delete Selected Nodes**: Press the `Delete` key to remove all selected nodes
3. **Deploy Changes**: Click the red **Deploy** button in the top-right corner to save the changes

### 3. **Create MQTT Input Connection for Vehicle Data**

Set up an MQTT subscriber node to receive vehicle detection data:

1. **Add MQTT Input Node**:
   - Drag an `mqtt in` node from the **network** section in the left palette
   - Double-click the node to configure it

2. **Configure MQTT Broker**:
   - **Server**: `broker:1883` (or your MQTT broker address)
   - **Topic**: `object_detection_1` (crowd analytics data topic)
   - **QoS**: `0`
   - **Output**: `auto-detect (string or buffer)`

3. **Set Node Properties**:
   - **Name**: `Vehicle Detection Input`
   - Click **Done** to save the configuration

### 4. **Add Debug Output for Vehicle Data Monitoring**

Create a debug node to monitor incoming vehicle detection data:

1. **Add Debug Node**:
   - Drag a `debug` node from the **common** section
   - Connect the output of the MQTT input node to the debug node input

2. **Configure Debug Node**:
   - **Output**: `msg.payload`
   - **To**: `debug tab and console`
   - **Name**: `Vehicle Data Monitor`

3. **Deploy and Test**:
   - Click **Deploy**
   - Check the debug panel (bug icon in the right sidebar) for incoming vehicle detection messages

4. **Start the Crowd Analytics Pipeline** (if needed):
   If you don't see data in the debug panel, execute the crowd analytics pipeline:

   ```bash
   curl -k -s https://localhost/api/pipelines/user_defined_pipelines/yolov10_1_cpu -X POST -H 'Content-Type: application/json' -d '
   {
       "source": {
           "uri": "file:///home/pipeline-server/videos/easy1.mp4",
           "type": "uri"
       },
       "destination": {
           "metadata": {
               "type": "mqtt",
               "topic": "object_detection_1",
               "timeout": 1000
           },
           "frame": {
               "type": "webrtc",
               "peer-id": "object_detection_1"
           }
       },
       "parameters": {
           "detection-device": "CPU"
       }
   }'
   ```

### 5. **Implement Vehicle Position Extraction Function**

Add a function node to extract vehicle positions from detection data:

1. **Add Function Node**:
   - Drag a `function` node from the **function** section
   - Position it after the MQTT input node

2. **Configure the Vehicle Position Extractor**:
   - **Name**: `Extract Vehicle Positions`
   - **Function Code**:

```javascript
// Extract vehicle positions from YOLOv10s detection data
// Calculate centroid coordinates for each detected vehicle

// Check if payload exists and has objects array
if (!msg.payload || !msg.payload.objects || !Array.isArray(msg.payload.objects)) {
    return null; // Ignore frames without vehicle data
}

let vehicles = [];
let frameTimestamp = msg.payload.timestamp || Date.now();

// Process each detected object
for (let i = 0; i < msg.payload.objects.length; i++) {
    let obj = msg.payload.objects[i];
    
    // Filter for vehicles only (car, truck, bus, motorcycle)
    let vehicleTypes = ['car', 'truck', 'bus', 'motorcycle', 'vehicle'];
    if (!obj.detection || !obj.detection.label || 
        !vehicleTypes.includes(obj.detection.label.toLowerCase())) {
        continue; // Skip non-vehicle objects
    }
    
    // Extract bounding box coordinates
    let bbox = obj.detection.bounding_box;
    if (!bbox || !bbox.x_min || !bbox.y_min || !bbox.x_max || !bbox.y_max) {
        continue; // Skip objects without valid bounding boxes
    }
    
    // Calculate centroid coordinates
    let centerX = (bbox.x_min + bbox.x_max) / 2;
    let centerY = (bbox.y_min + bbox.y_max) / 2;
    
    // Calculate bounding box area
    let width = bbox.x_max - bbox.x_min;
    let height = bbox.y_max - bbox.y_min;
    let area = width * height;
    
    // Create vehicle object
    let vehicle = {
        id: obj.object_id || `vehicle_${i}`,
        type: obj.detection.label,
        confidence: obj.detection.confidence || 0,
        position: {
            x: centerX,
            y: centerY
        },
        bbox: {
            x_min: bbox.x_min,
            y_min: bbox.y_min,
            x_max: bbox.x_max,
            y_max: bbox.y_max,
            width: width,
            height: height,
            area: area
        },
        timestamp: frameTimestamp
    };
    
    vehicles.push(vehicle);
}

// Only process frames with vehicles
if (vehicles.length === 0) {
    return null;
}

// Create output message with vehicle positions
msg.payload = {
    timestamp: frameTimestamp,
    vehicle_count: vehicles.length,
    vehicles: vehicles
};

return msg;
```

### 6. **Implement Crowd Detection Algorithm**

Add a function node to calculate inter-vehicle distances and detect crowds:

1. **Add Function Node**:
   - Drag another `function` node from the **function** section
   - Connect it after the vehicle position extractor

2. **Configure the Crowd Detection Logic**:
   - **Name**: `Crowd Detection Algorithm`
   - **Function Code**:

```javascript
// Crowd Detection Algorithm
// Calculates Euclidean distances between vehicles and identifies crowd formations

if (!msg.payload || !msg.payload.vehicles || msg.payload.vehicles.length < 2) {
    // Need at least 2 vehicles to form a crowd
    msg.payload = {
        ...msg.payload,
        crowd_status: "insufficient_vehicles",
        crowd_count: 0,
        clusters: []
    };
    return msg;
}

let vehicles = msg.payload.vehicles;

// Configuration parameters
const DISTANCE_THRESHOLD = 300; // pixels - minimum distance for crowd detection
const MIN_CROWD_SIZE = 3; // minimum vehicles to form a crowd
const INTERSECTION_THRESHOLD = 1; // bounding box overlap threshold

// Function to calculate Euclidean distance between two points
function calculateDistance(pos1, pos2) {
    let dx = pos1.x - pos2.x;
    let dy = pos1.y - pos2.y;
    return Math.sqrt(dx * dx + dy * dy);
}

// Function to calculate bounding box intersection over union (IoU)
function calculateBBoxOverlap(bbox1, bbox2) {
    let xLeft = Math.max(bbox1.x_min, bbox2.x_min);
    let yTop = Math.max(bbox1.y_min, bbox2.y_min);
    let xRight = Math.min(bbox1.x_max, bbox2.x_max);
    let yBottom = Math.min(bbox1.y_max, bbox2.y_max);
    
    if (xRight < xLeft || yBottom < yTop) {
        return 0; // No intersection
    }
    
    let intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    let union = bbox1.area + bbox2.area - intersectionArea;
    
    return intersectionArea / union;
}

// Calculate distance matrix between all vehicle pairs
let distanceMatrix = [];
let proximityPairs = [];

for (let i = 0; i < vehicles.length; i++) {
    distanceMatrix[i] = [];
    for (let j = 0; j < vehicles.length; j++) {
        if (i === j) {
            distanceMatrix[i][j] = 0;
        } else {
            let distance = calculateDistance(vehicles[i].position, vehicles[j].position);
            distanceMatrix[i][j] = distance;
            
            // Check if vehicles are within crowd threshold
            if (distance <= DISTANCE_THRESHOLD) {
                let overlap = calculateBBoxOverlap(vehicles[i].bbox, vehicles[j].bbox);
                proximityPairs.push({
                    vehicle1_id: vehicles[i].id,
                    vehicle2_id: vehicles[j].id,
                    distance: distance,
                    overlap: overlap,
                    is_crowd_pair: distance <= DISTANCE_THRESHOLD && overlap < INTERSECTION_THRESHOLD
                });
            }
        }
    }
}

// Cluster vehicles into crowds using simple clustering
let visited = new Array(vehicles.length).fill(false);
let clusters = [];

function findCluster(vehicleIndex, currentCluster) {
    visited[vehicleIndex] = true;
    currentCluster.push(vehicleIndex);
    
    // Find all vehicles within threshold distance
    for (let j = 0; j < vehicles.length; j++) {
        if (!visited[j] && distanceMatrix[vehicleIndex][j] <= DISTANCE_THRESHOLD) {
            findCluster(j, currentCluster);
        }
    }
}

// Find all clusters
for (let i = 0; i < vehicles.length; i++) {
    if (!visited[i]) {
        let cluster = [];
        findCluster(i, cluster);
        
        if (cluster.length >= MIN_CROWD_SIZE) {
            // Calculate cluster metrics
            let clusterVehicles = cluster.map(idx => vehicles[idx]);
            
            // Calculate cluster centroid
            let centroidX = clusterVehicles.reduce((sum, v) => sum + v.position.x, 0) / clusterVehicles.length;
            let centroidY = clusterVehicles.reduce((sum, v) => sum + v.position.y, 0) / clusterVehicles.length;
            
            // Calculate cluster density (vehicles per unit area)
            let distances = [];
            for (let m = 0; m < cluster.length; m++) {
                for (let n = m + 1; n < cluster.length; n++) {
                    distances.push(distanceMatrix[cluster[m]][cluster[n]]);
                }
            }
            
            let avgDistance = distances.reduce((sum, d) => sum + d, 0) / distances.length;
            let maxDistance = Math.max(...distances);
            let density = clusterVehicles.length / (Math.PI * Math.pow(maxDistance / 2, 2));
            
            clusters.push({
                id: `cluster_${clusters.length + 1}`,
                vehicle_count: clusterVehicles.length,
                vehicles: clusterVehicles.map(v => v.id),
                centroid: { x: centroidX, y: centroidY },
                avg_distance: avgDistance,
                max_distance: maxDistance,
                density: density,
                status: "crowd_detected"
            });
        }
    }
}

// Calculate overall crowd metrics
let totalCrowdedVehicles = clusters.reduce((sum, cluster) => sum + cluster.vehicle_count, 0);
let scatteredVehicles = vehicles.length - totalCrowdedVehicles;

// Determine overall crowd status
let crowdStatus;
if (clusters.length === 0) {
    crowdStatus = "scattered";
} else if (totalCrowdedVehicles > scatteredVehicles) {
    crowdStatus = "highly_crowded";
} else {
    crowdStatus = "partially_crowded";
}

// Create enhanced output with crowd analytics
msg.payload = {
    ...msg.payload,
    crowd_analytics: {
        status: crowdStatus,
        total_vehicles: vehicles.length,
        crowded_vehicles: totalCrowdedVehicles,
        scattered_vehicles: scatteredVehicles,
        crowd_count: clusters.length,
        crowd_density: totalCrowdedVehicles / vehicles.length,
        distance_threshold: DISTANCE_THRESHOLD,
        min_crowd_size: MIN_CROWD_SIZE
    },
    clusters: clusters,
    proximity_pairs: proximityPairs.filter(pair => pair.is_crowd_pair),
    distance_matrix: distanceMatrix
};

return msg;
```

### 7. **Add Crowd Analytics Output Processing**

Create a function node to generate crowd analytics summaries and alerts:

1. **Add Function Node**:
   - Drag another `function` node from the **function** section
   - Connect it after the crowd detection algorithm

2. **Configure Analytics Generator**:
   - **Name**: `Generate Crowd Analytics`
   - **Function Code**:

```javascript
// Generate Crowd Analytics Summary and Alerts

if (!msg.payload || !msg.payload.crowd_analytics) {
    return null;
}

let analytics = msg.payload.crowd_analytics;
let clusters = msg.payload.clusters || [];
let timestamp = msg.payload.timestamp;

// Generate alert levels based on crowd metrics
let alertLevel = "normal";
let alerts = [];

// High density alert
if (analytics.crowd_density > 0.7) {
    alertLevel = "high";
    alerts.push({
        type: "high_density",
        message: `High crowd density detected: ${(analytics.crowd_density * 100).toFixed(1)}%`,
        severity: "warning"
    });
}

// Large cluster alert
let largestCluster = clusters.reduce((max, cluster) => 
    cluster.vehicle_count > max ? cluster.vehicle_count : max, 0);

if (largestCluster >= 5) {
    alertLevel = "high";
    alerts.push({
        type: "large_cluster",
        message: `Large vehicle cluster detected: ${largestCluster} vehicles`,
        severity: "warning"
    });
}

// Multiple clusters alert
if (clusters.length >= 3) {
    alerts.push({
        type: "multiple_clusters",
        message: `Multiple crowd formations detected: ${clusters.length} clusters`,
        severity: "info"
    });
}

// Generate summary statistics
let summary = {
    timestamp: timestamp,
    alert_level: alertLevel,
    alerts: alerts,
    metrics: {
        total_vehicles: analytics.total_vehicles,
        crowd_formations: analytics.crowd_count,
        crowd_density_percent: Math.round(analytics.crowd_density * 100),
        largest_cluster_size: largestCluster,
        avg_cluster_size: clusters.length > 0 ? 
            Math.round(analytics.crowded_vehicles / clusters.length) : 0
    },
    clusters_summary: clusters.map(cluster => ({
        id: cluster.id,
        size: cluster.vehicle_count,
        density: cluster.density.toFixed(2),
        centroid: {
            x: Math.round(cluster.centroid.x),
            y: Math.round(cluster.centroid.y)
        }
    }))
};

// Create separate outputs for different consumers
msg.payload = summary;

// Create additional output for real-time dashboard
msg.dashboard = {
    timestamp: timestamp,
    status: analytics.status,
    total_vehicles: analytics.total_vehicles,
    crowd_count: analytics.crowd_count,
    density: Math.round(analytics.crowd_density * 100),
    alert_level: alertLevel,
    alerts_count: alerts.length
};

// Create output for historical logging
msg.history = {
    timestamp: timestamp,
    ...analytics,
    clusters_detail: clusters,
    alert_summary: {
        level: alertLevel,
        count: alerts.length,
        types: alerts.map(a => a.type)
    }
};

return [msg, { payload: msg.dashboard, topic: "crowd/dashboard" }, 
        { payload: msg.history, topic: "crowd/history" }];
```

### 8. **Configure MQTT Outputs for Crowd Analytics**

Set up MQTT publishers for different types of crowd analytics data:

1. **Add Primary MQTT Output Node**:
   - Drag an `mqtt out` node from the **network** section
   - Connect the first output of the analytics generator to this node
   - **Configure**:
     - **Server**: `broker:1883`
     - **Topic**: `crowd_analytics/summary`
     - **Name**: `Crowd Summary Publisher`

2. **Add Dashboard MQTT Output Node**:
   - Add another `mqtt out` node
   - Connect the second output to this node
   - **Configure**:
     - **Server**: `broker:1883`
     - **Topic**: `crowd_analytics/dashboard`
     - **Name**: `Dashboard Data Publisher`

3. **Add Historical MQTT Output Node**:
   - Add a third `mqtt out` node
   - Connect the third output to this node
   - **Configure**:
     - **Server**: `broker:1883`
     - **Topic**: `crowd_analytics/history`
     - **Name**: `Historical Data Publisher`

### 9. **Add Debug Monitoring for Each Stage**

Create debug nodes to monitor the crowd analytics pipeline:

1. **Add Debug Nodes**:
   - Add debug nodes after each function node
   - **Names**: 
     - `Vehicle Positions Debug`
     - `Crowd Detection Debug`
     - `Analytics Summary Debug`

2. **Configure Debug Outputs**:
   - Set each debug node to output `msg.payload`
   - Enable console output for troubleshooting

### 10. **Deploy and Validate the Crowd Analytics Flow**

Test your complete crowd analytics Node-RED flow:

1. **Deploy the Complete Flow**:
   - Click the **Deploy** button in the top-right corner

2. **Monitor Crowd Analytics**:
   - Open the debug panel in Node-RED
   - Start the crowd analytics pipeline using the curl command from step 4
   - Verify that vehicle detection data flows through each stage
   - Check that crowd detection algorithms are working correctly
   - Monitor crowd analytics outputs in real-time

3. **Validate Crowd Detection Logic**:
   - Test with different video sources containing various vehicle densities
   - Verify distance calculations are accurate
   - Check that clusters are properly identified
   - Validate alert generation for different crowd scenarios

## Expected Results

![Crowd Analytics Node-RED Flow](_images/crowd-analytics-node-red-flow.png)

After completing this tutorial, you should have:

1. **Complete Crowd Analytics Flow**: A working Node-RED flow that processes vehicle detection data and implements crowd analytics algorithms
2. **Real-time Crowd Detection**: Live identification of vehicle clusters and crowd formations
3. **Enhanced Analytics Data**: MQTT topics publishing crowd metrics, density calculations, and proximity analysis
4. **Alert System**: Automated alerts for high-density situations and large cluster formations
5. **Multi-output Architecture**: Separate data streams for dashboards, historical logging, and real-time monitoring

## Crowd Analytics Parameters

The system uses configurable parameters for crowd detection:

| **Parameter** | **Default Value** | **Description** |
|---------------|------------------|-----------------|
| `DISTANCE_THRESHOLD` | 400 pixels | Maximum distance between vehicles to be considered part of a crowd |
| `MIN_CROWD_SIZE` | 3 vehicles | Minimum number of vehicles required to form a crowd |
| `INTERSECTION_THRESHOLD` | 0.85 | Maximum bounding box overlap before considering vehicles as overlapping |

These parameters can be adjusted in the crowd detection function based on:
- Camera height and viewing angle
- Parking lot or road layout
- Desired crowd sensitivity
- Vehicle size variations

## Next Steps

After successfully implementing crowd analytics with Node-RED:

[**Integration with Grafana for Crowd Visualization**](./tutorial-3.md)

Consider these enhancements:
- **Real-time Dashboards**: Create Grafana dashboards for crowd visualization
- **Historical Analysis**: Implement time-series analysis of crowd patterns
- **Predictive Analytics**: Add machine learning models to predict crowd formations
- **Alert Integration**: Connect to notification systems for crowd management

## Troubleshooting

### **No Vehicle Detection Data**
- **Problem**: Debug nodes show no incoming vehicle data
- **Solution**: 
  ```bash
  # Verify crowd analytics pipeline is running
  curl -k -s https://localhost/api/pipelines/user_defined_pipelines/yolov10_1_cpu
  # Check MQTT broker connectivity
  docker logs <mqtt-container-name>
  ```

### **Incorrect Distance Calculations**
- **Problem**: Crowd detection not working properly
- **Solution**: 
  - Verify bounding box coordinates are valid
  - Check centroid calculations in vehicle position extractor
  - Adjust `DISTANCE_THRESHOLD` for your specific video resolution

### **No Crowd Clusters Detected**
- **Problem**: Vehicles are present but no crowds detected
- **Solution**: 
  - Lower the `DISTANCE_THRESHOLD` value
  - Reduce `MIN_CROWD_SIZE` to 2 vehicles
  - Check vehicle filtering logic (car, truck, bus types)

### **Function Node Errors**
- **Problem**: JavaScript errors in crowd detection functions
- **Solution**: 
  - Add error handling with try-catch blocks
  - Use `node.warn()` for debugging intermediate values
  - Validate input data structure before processing

## Supporting Resources

- [Node-RED Official Documentation](https://nodered.org/docs/)
- [Euclidean Distance Algorithms](https://en.wikipedia.org/wiki/Euclidean_distance)
- [Crowd Dynamics Theory](https://en.wikipedia.org/wiki/Crowd_dynamics)
- [Intel DLStreamer Documentation](https://dlstreamer.github.io/)
- [Metro AI Solutions](https://github.com/open-edge-platform/edge-ai-suites/tree/main/metro-ai-suite)