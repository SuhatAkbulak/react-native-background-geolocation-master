package com.backgroundlocation.data;

import org.json.JSONObject;
import java.util.UUID;

/**
 * Location Data Model with LOCKING support
 * Locking mekanizması ile
 * RAW SQLite (No Room annotations)
 */
public class LocationModel {
    public int id;
    public String uuid;
    
    public double latitude;
    public double longitude;
    public float accuracy;
    public float speed;
    public float heading;
    public double altitude;
    public float altitudeAccuracy;
    public long timestamp;
    
    public String activityType;
    public int activityConfidence;
    
    public float batteryLevel;
    public boolean batteryIsCharging;
    
    public boolean isMoving;
    public float odometer;
    
    public String extras;
    
    // LOCKING mekanizması için
    public boolean locked = false;
    
    // Senkronizasyon durumu
    public boolean synced = false;

    public LocationModel() {
        this.uuid = UUID.randomUUID().toString();
        this.timestamp = System.currentTimeMillis();
        this.locked = false;
        this.synced = false;
    }

    /**
     * Convert to JSON
     */
    public JSONObject toJSON() {
        try {
            JSONObject json = new JSONObject();
            json.put("uuid", uuid);
            json.put("timestamp", timestamp);
            json.put("is_moving", isMoving);
            json.put("odometer", odometer);
            
            // Coordinates
            JSONObject coords = new JSONObject();
            coords.put("latitude", latitude);
            coords.put("longitude", longitude);
            coords.put("accuracy", accuracy);
            coords.put("speed", speed);
            coords.put("heading", heading);
            coords.put("altitude", altitude);
            coords.put("altitude_accuracy", altitudeAccuracy);
            json.put("coords", coords);
            
            // Activity
            if (activityType != null) {
                JSONObject activity = new JSONObject();
                activity.put("type", activityType);
                activity.put("confidence", activityConfidence);
                json.put("activity", activity);
            }
            
            // Battery
            JSONObject battery = new JSONObject();
            battery.put("level", batteryLevel);
            battery.put("is_charging", batteryIsCharging);
            json.put("battery", battery);
            
            // Extras
            if (extras != null && !extras.isEmpty()) {
                json.put("extras", new JSONObject(extras));
            }
            
            return json;
        } catch (Exception e) {
            e.printStackTrace();
            return new JSONObject();
        }
    }

    /**
     * Create from JSON
     */
    public static LocationModel fromJSON(JSONObject json) {
        try {
            LocationModel location = new LocationModel();
            
            if (json.has("uuid")) {
                location.uuid = json.getString("uuid");
            }
            if (json.has("timestamp")) {
                location.timestamp = json.getLong("timestamp");
            }
            if (json.has("is_moving")) {
                location.isMoving = json.getBoolean("is_moving");
            }
            if (json.has("odometer")) {
                location.odometer = (float) json.getDouble("odometer");
            }
            
            // Coordinates
            if (json.has("coords")) {
                JSONObject coords = json.getJSONObject("coords");
                location.latitude = coords.getDouble("latitude");
                location.longitude = coords.getDouble("longitude");
                location.accuracy = (float) coords.getDouble("accuracy");
                location.speed = (float) coords.optDouble("speed", 0);
                location.heading = (float) coords.optDouble("heading", 0);
                location.altitude = coords.optDouble("altitude", 0);
                location.altitudeAccuracy = (float) coords.optDouble("altitude_accuracy", 0);
            }
            
            // Activity
            if (json.has("activity")) {
                JSONObject activity = json.getJSONObject("activity");
                location.activityType = activity.getString("type");
                location.activityConfidence = activity.getInt("confidence");
            }
            
            // Battery
            if (json.has("battery")) {
                JSONObject battery = json.getJSONObject("battery");
                location.batteryLevel = (float) battery.getDouble("level");
                location.batteryIsCharging = battery.getBoolean("is_charging");
            }
            
            // Extras
            if (json.has("extras")) {
                location.extras = json.getJSONObject("extras").toString();
            }
            
            return location;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }
}
