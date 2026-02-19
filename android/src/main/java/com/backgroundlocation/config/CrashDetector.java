package com.backgroundlocation.config;

import android.util.Log;
import com.backgroundlocation.util.LogHelper;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * CrashDetector
 * TSCrashDetector.java
 * Crash detection yapılandırması
 */
public class CrashDetector extends ConfigModuleBase implements IModule {
    
    public static final String NAME = "crashDetector";
    
    private Boolean enabled = null;
    private Double accelerometerThresholdHigh = null;
    private Double accelerometerThresholdLow = null;
    private Double gyroscopeThresholdHigh = null;
    private Double gyroscopeThresholdLow = null;
    
    public CrashDetector() {
        super(NAME);
        applyDefaults();
    }
    
    public CrashDetector(JSONObject jsonObject, boolean applyDefaults) throws JSONException {
        super(NAME);
        if (jsonObject.has("enabled")) {
            this.enabled = jsonObject.getBoolean("enabled");
        }
        if (jsonObject.has("accelerometerThresholdHigh")) {
            this.accelerometerThresholdHigh = jsonObject.getDouble("accelerometerThresholdHigh");
        }
        if (jsonObject.has("accelerometerThresholdLow")) {
            this.accelerometerThresholdLow = jsonObject.getDouble("accelerometerThresholdLow");
        }
        if (jsonObject.has("gyroscopeThresholdHigh")) {
            this.gyroscopeThresholdHigh = jsonObject.getDouble("gyroscopeThresholdHigh");
        }
        if (jsonObject.has("gyroscopeThresholdLow")) {
            this.gyroscopeThresholdLow = jsonObject.getDouble("gyroscopeThresholdLow");
        }
        if (applyDefaults) {
            applyDefaults();
        }
    }
    
    @Override
    public void applyDefaults() {
        if (this.enabled == null) {
            this.enabled = false;
        }
        if (this.accelerometerThresholdHigh == null) {
            this.accelerometerThresholdHigh = 20.0;
        }
        if (this.accelerometerThresholdLow == null) {
            this.accelerometerThresholdLow = 4.5;
        }
        if (this.gyroscopeThresholdHigh == null) {
            this.gyroscopeThresholdHigh = 20.0;
        }
        if (this.gyroscopeThresholdLow == null) {
            this.gyroscopeThresholdLow = 4.5;
        }
    }
    
    @Override
    public JSONObject toJson(boolean redact) {
        JSONObject json = new JSONObject();
        try {
            json.put("enabled", enabled);
            json.put("accelerometerThresholdHigh", accelerometerThresholdHigh);
            json.put("accelerometerThresholdLow", accelerometerThresholdLow);
            json.put("gyroscopeThresholdHigh", gyroscopeThresholdHigh);
            json.put("gyroscopeThresholdLow", gyroscopeThresholdLow);
        } catch (JSONException e) {
            Log.e("CrashDetector", "Error creating JSON: " + e.getMessage(), e);
            LogHelper.e("CrashDetector", "Error creating JSON: " + e.getMessage(), e);
        }
        return json;
    }
    
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("enabled", enabled);
        map.put("accelerometerThresholdHigh", accelerometerThresholdHigh);
        map.put("accelerometerThresholdLow", accelerometerThresholdLow);
        map.put("gyroscopeThresholdHigh", gyroscopeThresholdHigh);
        map.put("gyroscopeThresholdLow", gyroscopeThresholdLow);
        return map;
    }
    
    public boolean update(CrashDetector other) {
        clearDirtyFields();
        
        if (other.getEnabled() != null && !other.getEnabled().equals(this.enabled)) {
            this.enabled = other.getEnabled();
            markDirty("enabled");
        }
        if (other.getAccelerometerThresholdHigh() != null && 
            !other.getAccelerometerThresholdHigh().equals(this.accelerometerThresholdHigh)) {
            this.accelerometerThresholdHigh = other.getAccelerometerThresholdHigh();
            markDirty("accelerometerThresholdHigh");
        }
        if (other.getAccelerometerThresholdLow() != null && 
            !other.getAccelerometerThresholdLow().equals(this.accelerometerThresholdLow)) {
            this.accelerometerThresholdLow = other.getAccelerometerThresholdLow();
            markDirty("accelerometerThresholdLow");
        }
        if (other.getGyroscopeThresholdHigh() != null && 
            !other.getGyroscopeThresholdHigh().equals(this.gyroscopeThresholdHigh)) {
            this.gyroscopeThresholdHigh = other.getGyroscopeThresholdHigh();
            markDirty("gyroscopeThresholdHigh");
        }
        if (other.getGyroscopeThresholdLow() != null && 
            !other.getGyroscopeThresholdLow().equals(this.gyroscopeThresholdLow)) {
            this.gyroscopeThresholdLow = other.getGyroscopeThresholdLow();
            markDirty("gyroscopeThresholdLow");
        }
        
        return !getDirtyFields().isEmpty();
    }
    
    // Getters and Setters
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public Double getAccelerometerThresholdHigh() { return accelerometerThresholdHigh; }
    public void setAccelerometerThresholdHigh(Double accelerometerThresholdHigh) { 
        this.accelerometerThresholdHigh = accelerometerThresholdHigh; 
    }
    
    public Double getAccelerometerThresholdLow() { return accelerometerThresholdLow; }
    public void setAccelerometerThresholdLow(Double accelerometerThresholdLow) { 
        this.accelerometerThresholdLow = accelerometerThresholdLow; 
    }
    
    public Double getGyroscopeThresholdHigh() { return gyroscopeThresholdHigh; }
    public void setGyroscopeThresholdHigh(Double gyroscopeThresholdHigh) { 
        this.gyroscopeThresholdHigh = gyroscopeThresholdHigh; 
    }
    
    public Double getGyroscopeThresholdLow() { return gyroscopeThresholdLow; }
    public void setGyroscopeThresholdLow(Double gyroscopeThresholdLow) { 
        this.gyroscopeThresholdLow = gyroscopeThresholdLow; 
    }
}

