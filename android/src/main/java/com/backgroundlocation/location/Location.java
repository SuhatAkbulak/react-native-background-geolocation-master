package com.backgroundlocation.location;

import android.content.Context;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.SystemClock;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.ActivityTransitionEvent;
import com.google.android.gms.location.DetectedActivity;
import org.json.JSONException;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;
import java.util.UUID;

/**
 * Location
 * Location
 * Location model sınıfı - LocationModel wrapper'ı
 */
public class Location {
    
    private static final String ISO_DATE_FORMAT = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    private static final ThreadLocal<SimpleDateFormat> dateFormatter = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            SimpleDateFormat sdf = new SimpleDateFormat(ISO_DATE_FORMAT, Locale.ENGLISH);
            sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
            return sdf;
        }
    };
    
    public static final String LOCATION_OPTIONS_ODOMETER = "odometer";
    
    public Integer id = null;
    public android.location.Location mLocation = null;
    public JSONObject json = null;
    
    private String uuid;
    private Long timestamp;
    private Double latitude;
    private Double longitude;
    private Double altitude;
    private Float accuracy;
    private Float speed;
    private Float heading;
    private Double altitudeAccuracy;
    private String activityType;
    private Integer activityConfidence;
    private Float batteryLevel;
    private Boolean batteryIsCharging;
    private Boolean isMoving;
    private Double odometer;
    private String extras;
    private DetectedActivity detectedActivity;
    
    /**
     * Create from Android Location
     */
    public Location(Context context, android.location.Location location, ActivityTransitionEvent activityTransitionEvent) {
        this.uuid = UUID.randomUUID().toString();
        this.timestamp = System.currentTimeMillis();
        this.isMoving = false;
        this.odometer = -1.0;
        
        if (location != null) {
            this.mLocation = location;
            this.latitude = location.getLatitude();
            this.longitude = location.getLongitude();
            this.altitude = location.getAltitude();
            this.accuracy = location.getAccuracy();
            this.speed = location.getSpeed();
            this.heading = location.getBearing();
            this.timestamp = location.getTime();
            
            // Get battery info
            Bundle extras = location.getExtras();
            if (extras != null) {
                this.batteryLevel = extras.getFloat("battery_level", -1f);
                this.batteryIsCharging = extras.getBoolean("is_charging", false);
                this.odometer = (double) extras.getFloat(LOCATION_OPTIONS_ODOMETER, -1f);
            }
        }
        
        // Activity recognition
        if (activityTransitionEvent != null) {
            int activityType = activityTransitionEvent.getActivityType();
            this.activityType = getActivityTypeString(activityType);
            this.activityConfidence = activityTransitionEvent.getTransitionType();
        }
    }
    
    /**
     * Create from LocationModel
     */
    public Location(LocationModel model) {
        this.uuid = model.uuid;
        this.timestamp = model.timestamp;
        this.latitude = model.latitude;
        this.longitude = model.longitude;
        this.altitude = model.altitude;
        this.accuracy = model.accuracy;
        this.speed = model.speed;
        this.heading = model.heading;
        this.altitudeAccuracy = (double) model.altitudeAccuracy;
        this.activityType = model.activityType;
        this.activityConfidence = model.activityConfidence;
        this.batteryLevel = model.batteryLevel;
        this.batteryIsCharging = model.batteryIsCharging;
        this.isMoving = model.isMoving;
        this.odometer = (double) model.odometer;
        this.extras = model.extras;
    }
    
    /**
     * Build from JSON
     */
    public static Location buildFromJson(Context context, JSONObject jsonObject) throws JSONException {
        android.location.Location location = new android.location.Location("fused");
        
        JSONObject coords = jsonObject.getJSONObject("coords");
        location.setLatitude(coords.getDouble("latitude"));
        location.setLongitude(coords.getDouble("longitude"));
        location.setAccuracy((float) coords.optDouble("accuracy", 0));
        location.setSpeed((float) coords.optDouble("speed", 0));
        location.setBearing((float) coords.optDouble("heading", 0));
        location.setAltitude(coords.optDouble("altitude", 0));
        location.setTime(jsonObject.optLong("timestamp", System.currentTimeMillis()));
        
        // Apply extras
        location = applyExtras(context, location);
        
        return new Location(context, location, null);
    }
    
    /**
     * Apply extras to location
     */
    public static android.location.Location applyExtras(Context context, android.location.Location location) {
        Bundle extras = location.getExtras();
        if (extras == null) {
            extras = new Bundle();
        }
        
        com.backgroundlocation.config.Config config = com.backgroundlocation.config.Config.getInstance(context);
        extras.putFloat(LOCATION_OPTIONS_ODOMETER, config.odometer);
        
        // Battery info
        android.content.IntentFilter filter = new android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED);
        android.content.Intent batteryStatus = context.registerReceiver(null, filter);
        if (batteryStatus != null) {
            int level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            extras.putFloat("battery_level", level / (float) scale);
            
            int status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            boolean isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || 
                                status == BatteryManager.BATTERY_STATUS_FULL;
            extras.putBoolean("is_charging", isCharging);
        }
        
        location.setExtras(extras);
        return location;
    }
    
    /**
     * Get activity type string
     */
    private String getActivityTypeString(int activityType) {
        switch (activityType) {
            case DetectedActivity.IN_VEHICLE: return "in_vehicle";
            case DetectedActivity.ON_BICYCLE: return "on_bicycle";
            case DetectedActivity.ON_FOOT: return "on_foot";
            case DetectedActivity.RUNNING: return "running";
            case DetectedActivity.STILL: return "still";
            case DetectedActivity.WALKING: return "walking";
            default: return "unknown";
        }
    }
    
    /**
     * Convert to JSON
     */
    public JSONObject toJson() {
        try {
            JSONObject json = new JSONObject();
            json.put("uuid", uuid);
            json.put("timestamp", timestamp);
            json.put("is_moving", isMoving != null ? isMoving : false);
            json.put("odometer", odometer != null ? odometer : -1);
            
            // Coordinates
            JSONObject coords = new JSONObject();
            coords.put("latitude", latitude);
            coords.put("longitude", longitude);
            coords.put("accuracy", accuracy != null ? accuracy : 0);
            coords.put("speed", speed != null ? speed : 0);
            coords.put("heading", heading != null ? heading : 0);
            coords.put("altitude", altitude != null ? altitude : 0);
            coords.put("altitude_accuracy", altitudeAccuracy != null ? altitudeAccuracy : 0);
            json.put("coords", coords);
            
            // Activity
            if (activityType != null) {
                JSONObject activity = new JSONObject();
                activity.put("type", activityType);
                activity.put("confidence", activityConfidence != null ? activityConfidence : 0);
                json.put("activity", activity);
            }
            
            // Battery
            if (batteryLevel != null) {
                JSONObject battery = new JSONObject();
                battery.put("level", batteryLevel);
                battery.put("is_charging", batteryIsCharging != null ? batteryIsCharging : false);
                json.put("battery", battery);
            }
            
            // Extras
            if (extras != null && !extras.isEmpty()) {
                try {
                    json.put("extras", new JSONObject(extras));
                } catch (JSONException e) {
                    LogHelper.w("Location", "Invalid extras JSON: " + e.getMessage());
                }
            }
            
            this.json = json;
            return json;
        } catch (JSONException e) {
            LogHelper.e("Location", "Error creating JSON: " + e.getMessage(), e);
            return new JSONObject();
        }
    }
    
    /**
     * Convert to LocationModel
     */
    public LocationModel toLocationModel() {
        LocationModel model = new LocationModel();
        model.uuid = this.uuid;
        model.timestamp = this.timestamp;
        model.latitude = this.latitude;
        model.longitude = this.longitude;
        model.altitude = this.altitude;
        model.accuracy = this.accuracy != null ? this.accuracy : 0;
        model.speed = this.speed != null ? this.speed : 0;
        model.heading = this.heading != null ? this.heading : 0;
        model.altitudeAccuracy = this.altitudeAccuracy != null ? this.altitudeAccuracy.floatValue() : 0;
        model.activityType = this.activityType;
        model.activityConfidence = this.activityConfidence != null ? this.activityConfidence : 0;
        model.batteryLevel = this.batteryLevel != null ? this.batteryLevel : 0;
        model.batteryIsCharging = this.batteryIsCharging != null ? this.batteryIsCharging : false;
        model.isMoving = this.isMoving != null ? this.isMoving : false;
        model.odometer = this.odometer != null ? this.odometer.floatValue() : 0;
        model.extras = this.extras;
        return model;
    }
    
    // Getters
    public String getUuid() { return uuid; }
    public Long getTimestamp() { return timestamp; }
    public Double getLatitude() { return latitude; }
    public Double getLongitude() { return longitude; }
    public Double getAltitude() { return altitude; }
    public Float getAccuracy() { return accuracy; }
    public Float getSpeed() { return speed; }
    public Float getHeading() { return heading; }
    public Boolean getIsMoving() { return isMoving; }
    public Double getOdometer() { return odometer; }
    
    // Setters
    public void setUuid(String uuid) { this.uuid = uuid; }
    public void setTimestamp(Long timestamp) { this.timestamp = timestamp; }
    public void setIsMoving(Boolean isMoving) { this.isMoving = isMoving; }
    public void setOdometer(Double odometer) { this.odometer = odometer; }
}

