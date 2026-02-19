package com.backgroundlocation.data;

import com.google.android.gms.location.Geofence;
import com.backgroundlocation.util.LogHelper;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Geofence Data Model with Builder Pattern & Polygon Support
 * TSGeofence.java
 */
public class GeofenceModel {
    public static final String FIELD_EXTRAS = "extras";
    public static final String FIELD_IDENTIFIER = "identifier";
    public static final String FIELD_LATITUDE = "latitude";
    public static final String FIELD_LOITERING_DELAY = "loiteringDelay";
    public static final String FIELD_LONGITUDE = "longitude";
    public static final String FIELD_NOTIFY_ON_DWELL = "notifyOnDwell";
    public static final String FIELD_NOTIFY_ON_ENTRY = "notifyOnEntry";
    public static final String FIELD_NOTIFY_ON_EXIT = "notifyOnExit";
    public static final String FIELD_RADIUS = "radius";
    public static final String FIELD_VERTICES = "vertices";
    public static final float MINIMUM_RADIUS = 150.0f;
    
    private static final String TAG = "GeofenceModel";
    private static final String ERROR_LATITUDE_REQUIRED = "Latitude is required";
    private static final String ERROR_LONGITUDE_REQUIRED = "Longitude is required";
    private static final String ERROR_RADIUS_REQUIRED = "Radius is required";
    private static final String ERROR_IDENTIFIER_REQUIRED = "Identifier is required";
    private static final String ERROR_TRANSITION_REQUIRED = "A transition-type is required (notifyOnEntry | notifyOnExit | notifyOnDwell)";
    private static final String ERROR_INVALID_EXTRAS = "Invalid JSON for extras";
    
    // Fields
    public int id;
    private final String identifier;
    private final Double latitude;
    private final Double longitude;
    private final Float radius;
    private final Boolean notifyOnEntry;
    private final Boolean notifyOnExit;
    private final Boolean notifyOnDwell;
    private final Integer loiteringDelay;
    private final Integer notificationResponsiveness;
    private final JSONObject extras;
    private final List<List<Double>> vertices;
    
    private Geofence builtGeofence;
    private IllegalArgumentException buildException;
    
    /**
     * Builder Pattern ()
     */
    public static class Builder {
        private String identifier;
        private Double latitude;
        private Double longitude;
        private Float radius = 200.0f; // Default radius
        private Boolean notifyOnEntry = false;
        private Boolean notifyOnExit = false;
        private Boolean notifyOnDwell = false;
        private Integer loiteringDelay = 0;
        private Integer notificationResponsiveness = null;
        private JSONObject extras = null;
        private List<List<Double>> vertices = new ArrayList<>();
        
        public Builder() {
        }
        
        public Builder setIdentifier(String identifier) {
            this.identifier = identifier;
            return this;
        }
        
        public Builder setLatitude(double latitude) {
            this.latitude = latitude;
            return this;
        }
        
        public Builder setLongitude(double longitude) {
            this.longitude = longitude;
            return this;
        }
        
        public Builder setRadius(float radius) {
            this.radius = radius;
            return this;
        }
        
        public Builder setNotifyOnEntry(boolean notifyOnEntry) {
            this.notifyOnEntry = notifyOnEntry;
            return this;
        }
        
        public Builder setNotifyOnExit(boolean notifyOnExit) {
            this.notifyOnExit = notifyOnExit;
            return this;
        }
        
        public Builder setNotifyOnDwell(boolean notifyOnDwell) {
            this.notifyOnDwell = notifyOnDwell;
            return this;
        }
        
        public Builder setLoiteringDelay(int loiteringDelay) {
            this.loiteringDelay = loiteringDelay;
            return this;
        }
        
        public Builder setNotificationResponsiveness(int notificationResponsiveness) {
            this.notificationResponsiveness = notificationResponsiveness;
            return this;
        }
        
        public Builder setExtras(JSONObject extras) {
            this.extras = extras;
            return this;
        }
        
        public Builder setExtras(String extras) {
            if (extras != null) {
                try {
                    this.extras = new JSONObject(extras);
                } catch (JSONException e) {
                    LogHelper.e(TAG, "Invalid JSON provided to GeofenceModel#setExtras: " + e.getMessage());
                }
            }
            return this;
        }
        
        public Builder setVertices(List<List<Double>> vertices) {
            this.vertices = vertices != null ? vertices : new ArrayList<>();
            return this;
        }
        
        /**
         * Build GeofenceModel
         * build() with validation
         */
        public GeofenceModel build() throws Exception {
            // If vertices provided, calculate minimum enclosing circle
            if (!vertices.isEmpty() && (latitude == null || longitude == null)) {
                double[] circle = calculateMinimumEnclosingCircle(vertices);
                LogHelper.d(TAG, "Minimum Enclosing Circle: " + circle[0] + " / " + circle[1] + ", radius: " + circle[2]);
                this.latitude = circle[0];
                this.longitude = circle[1];
                this.radius = (float) Math.round(circle[2]);
                this.notifyOnEntry = true;
                this.notifyOnExit = true;
            }
            
            // Validation
            if (latitude == null) {
                throw new Exception(ERROR_LATITUDE_REQUIRED);
            }
            if (longitude == null) {
                throw new Exception(ERROR_LONGITUDE_REQUIRED);
            }
            if (radius == null) {
                throw new Exception(ERROR_RADIUS_REQUIRED);
            }
            if (radius < MINIMUM_RADIUS) {
                LogHelper.w(TAG, "Geofence radius: " + radius + ": recommended geofence radius is >= " + MINIMUM_RADIUS + " meters");
            }
            if (identifier == null) {
                throw new Exception(ERROR_IDENTIFIER_REQUIRED);
            }
            if (!notifyOnEntry && !notifyOnExit && !notifyOnDwell) {
                throw new Exception(ERROR_TRANSITION_REQUIRED);
            }
            
            return new GeofenceModel(this);
        }
        
        /**
         * Calculate minimum enclosing circle for polygon vertices
         * Simple implementation (native library olmadan)
         */
        private double[] calculateMinimumEnclosingCircle(List<List<Double>> vertices) {
            if (vertices.isEmpty()) {
                return new double[]{0, 0, MINIMUM_RADIUS};
            }
            
            // Find bounding box
            double minLat = Double.MAX_VALUE;
            double maxLat = -Double.MAX_VALUE;
            double minLng = Double.MAX_VALUE;
            double maxLng = -Double.MAX_VALUE;
            
            for (List<Double> vertex : vertices) {
                double lat = vertex.get(0);
                double lng = vertex.get(1);
                minLat = Math.min(minLat, lat);
                maxLat = Math.max(maxLat, lat);
                minLng = Math.min(minLng, lng);
                maxLng = Math.max(maxLng, lng);
            }
            
            // Center of bounding box
            double centerLat = (minLat + maxLat) / 2.0;
            double centerLng = (minLng + maxLng) / 2.0;
            
            // Calculate maximum distance from center to any vertex
            double maxRadius = 0;
            for (List<Double> vertex : vertices) {
                double lat = vertex.get(0);
                double lng = vertex.get(1);
                double distance = calculateDistance(centerLat, centerLng, lat, lng);
                maxRadius = Math.max(maxRadius, distance);
            }
            
            // Add some buffer
            maxRadius = Math.max(maxRadius, MINIMUM_RADIUS);
            
            return new double[]{centerLat, centerLng, maxRadius};
        }
        
        /**
         * Calculate distance between two points (Haversine formula)
         */
        private double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
            final int R = 6371000; // Earth radius in meters
            double dLat = Math.toRadians(lat2 - lat1);
            double dLng = Math.toRadians(lng2 - lng1);
            double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                    Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                    Math.sin(dLng / 2) * Math.sin(dLng / 2);
            double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
            return R * c;
        }
    }
    
    /**
     * Private constructor (use Builder)
     */
    private GeofenceModel(Builder builder) {
        this.identifier = builder.identifier;
        this.latitude = builder.latitude;
        this.longitude = builder.longitude;
        this.radius = builder.radius;
        this.notifyOnEntry = builder.notifyOnEntry;
        this.notifyOnExit = builder.notifyOnExit;
        this.notifyOnDwell = builder.notifyOnDwell;
        this.loiteringDelay = builder.loiteringDelay;
        this.notificationResponsiveness = builder.notificationResponsiveness;
        this.extras = builder.extras;
        this.vertices = new ArrayList<>(builder.vertices);
    }
    
    /**
     * Build Google Play Services Geofence object
     * build() -> Geofence
     */
    public Geofence buildGeofence() throws IllegalArgumentException {
        int transitionTypes = 0;
        if (notifyOnEntry) {
            transitionTypes |= Geofence.GEOFENCE_TRANSITION_ENTER;
        }
        if (notifyOnExit) {
            transitionTypes |= Geofence.GEOFENCE_TRANSITION_EXIT;
        }
        if (notifyOnDwell && !isPolygon()) {
            transitionTypes |= Geofence.GEOFENCE_TRANSITION_DWELL;
        }
        
        Geofence.Builder geofenceBuilder = new Geofence.Builder()
                .setRequestId(identifier)
                .setCircularRegion(latitude, longitude, radius)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(transitionTypes)
                .setLoiteringDelay(loiteringDelay);
        
        if (notificationResponsiveness != null) {
            geofenceBuilder.setNotificationResponsiveness(notificationResponsiveness);
        }
        
        builtGeofence = geofenceBuilder.build();
        return builtGeofence;
    }
    
    /**
     * Validate geofence
     */
    public boolean validate() {
        try {
            buildGeofence();
            return true;
        } catch (IllegalArgumentException e) {
            buildException = e;
            return false;
        }
    }
    
    /**
     * Get validation error
     */
    public IllegalArgumentException getValidationError() {
        return buildException;
    }
    
    // Getters
    public String getIdentifier() {
        return identifier;
    }
    
    public double getLatitude() {
        return latitude;
    }
    
    public double getLongitude() {
        return longitude;
    }
    
    public float getRadius() {
        return radius;
    }
    
    public boolean getNotifyOnEntry() {
        return notifyOnEntry;
    }
    
    public boolean getNotifyOnExit() {
        return notifyOnExit;
    }
    
    public boolean getNotifyOnDwell() {
        return notifyOnDwell;
    }
    
    public int getLoiteringDelay() {
        return loiteringDelay;
    }
    
    public int getNotificationResponsiveness() {
        return notificationResponsiveness != null ? notificationResponsiveness : 0;
    }
    
    public JSONObject getExtras() {
        return extras;
    }
    
    public List<List<Double>> getVertices() {
        return new ArrayList<>(vertices);
    }
    
    public boolean isPolygon() {
        return !vertices.isEmpty();
    }
    
    /**
     * Convert to JSON
     * toJson()
     */
    public JSONObject toJSON() {
        try {
            JSONObject json = new JSONObject();
            json.put(FIELD_IDENTIFIER, identifier);
            json.put(FIELD_RADIUS, (double) radius);
            json.put(FIELD_LATITUDE, latitude);
            json.put(FIELD_LONGITUDE, longitude);
            json.put(FIELD_NOTIFY_ON_ENTRY, notifyOnEntry);
            json.put(FIELD_NOTIFY_ON_EXIT, notifyOnExit);
            json.put(FIELD_NOTIFY_ON_DWELL, notifyOnDwell);
            json.put(FIELD_LOITERING_DELAY, loiteringDelay);
            
            if (extras != null) {
                json.put(FIELD_EXTRAS, extras);
            }
            
            // Vertices
            if (!vertices.isEmpty()) {
                JSONArray verticesArray = new JSONArray();
                for (List<Double> vertex : vertices) {
                    JSONArray vertexArray = new JSONArray();
                    vertexArray.put(0, vertex.get(0)); // lat
                    vertexArray.put(1, vertex.get(1)); // lng
                    verticesArray.put(vertexArray);
                }
                json.put(FIELD_VERTICES, verticesArray);
            }
            
            return json;
        } catch (Exception e) {
            LogHelper.e(TAG, "Error converting geofence to JSON: " + e.getMessage(), e);
            return new JSONObject();
        }
    }
    
    /**
     * Create from JSON
     * fromJSON()
     */
    public static GeofenceModel fromJSON(JSONObject json) {
        try {
            Builder builder = new Builder();
            
            builder.setIdentifier(json.getString(FIELD_IDENTIFIER));
            builder.setLatitude(json.getDouble(FIELD_LATITUDE));
            builder.setLongitude(json.getDouble(FIELD_LONGITUDE));
            builder.setRadius((float) json.getDouble(FIELD_RADIUS));
            
            if (json.has(FIELD_NOTIFY_ON_ENTRY)) {
                builder.setNotifyOnEntry(json.getBoolean(FIELD_NOTIFY_ON_ENTRY));
            }
            if (json.has(FIELD_NOTIFY_ON_EXIT)) {
                builder.setNotifyOnExit(json.getBoolean(FIELD_NOTIFY_ON_EXIT));
            }
            if (json.has(FIELD_NOTIFY_ON_DWELL)) {
                builder.setNotifyOnDwell(json.getBoolean(FIELD_NOTIFY_ON_DWELL));
            }
            if (json.has(FIELD_LOITERING_DELAY)) {
                builder.setLoiteringDelay(json.getInt(FIELD_LOITERING_DELAY));
            }
            if (json.has(FIELD_EXTRAS)) {
                builder.setExtras(json.getJSONObject(FIELD_EXTRAS));
            }
            
            // Vertices (polygon)
            if (json.has(FIELD_VERTICES)) {
                JSONArray verticesArray = json.getJSONArray(FIELD_VERTICES);
                List<List<Double>> vertices = new ArrayList<>();
                for (int i = 0; i < verticesArray.length(); i++) {
                    JSONArray vertexArray = verticesArray.getJSONArray(i);
                    List<Double> vertex = new ArrayList<>();
                    vertex.add(vertexArray.getDouble(0)); // lat
                    vertex.add(vertexArray.getDouble(1)); // lng
                    vertices.add(vertex);
                }
                builder.setVertices(vertices);
            }
            
            return builder.build();
        } catch (Exception e) {
            LogHelper.e(TAG, "Error creating geofence from JSON: " + e.getMessage(), e);
            return null;
        }
    }
    
    /**
     * Check if location is inside polygon (Java implementation)
     * Ray casting algorithm
     */
    public static boolean isLocationInPolygon(List<List<Double>> vertices, double lat, double lng) {
        if (vertices.isEmpty() || vertices.size() < 3) {
            return false;
        }
        
        boolean inside = false;
        int j = vertices.size() - 1;
        
        for (int i = 0; i < vertices.size(); i++) {
            double lati = vertices.get(i).get(0);
            double lngi = vertices.get(i).get(1);
            double latj = vertices.get(j).get(0);
            double lngj = vertices.get(j).get(1);
            
            if (((lngi > lng) != (lngj > lng)) &&
                (lat < (latj - lati) * (lng - lngi) / (lngj - lngi) + lati)) {
                inside = !inside;
            }
            j = i;
        }
        
        return inside;
    }
}
