package com.backgroundlocation.device;

import android.os.Build;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * DeviceSettingsRequest
 * DeviceSettingsRequest.java
 * Ayarlar istek yönetimi
 */
public class DeviceSettingsRequest {
    
    private String manufacturer = Build.MANUFACTURER;
    private String model = Build.MODEL;
    private String version = Build.VERSION.RELEASE;
    private boolean seen = false;
    private long lastSeenAt = 0;
    private String action;
    
    public DeviceSettingsRequest(String action) {
        this.action = action;
    }
    
    public DeviceSettingsRequest(String action, long lastSeenAt) {
        this.action = action;
        this.lastSeenAt = lastSeenAt;
        this.seen = lastSeenAt > 0;
    }
    
    public String getAction() {
        return action;
    }
    
    public void setAction(String action) {
        this.action = action;
    }
    
    public String getManufacturer() {
        return manufacturer;
    }
    
    public void setManufacturer(String manufacturer) {
        this.manufacturer = manufacturer;
    }
    
    public String getModel() {
        return model;
    }
    
    public void setModel(String model) {
        this.model = model;
    }
    
    public String getVersion() {
        return version;
    }
    
    public void setVersion(String version) {
        this.version = version;
    }
    
    public boolean isSeen() {
        return seen;
    }
    
    public void setSeen(boolean seen) {
        this.seen = seen;
    }
    
    public long getLastSeenAt() {
        return lastSeenAt;
    }
    
    public void setLastSeenAt(long lastSeenAt) {
        this.lastSeenAt = lastSeenAt;
        this.seen = lastSeenAt > 0;
    }
    
    public JSONObject toJson() throws JSONException {
        JSONObject json = new JSONObject();
        json.put("manufacturer", manufacturer);
        json.put("model", model);
        json.put("version", version);
        json.put("seen", seen);
        json.put("lastSeenAt", lastSeenAt);
        json.put("action", action);
        return json;
    }
    
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("manufacturer", manufacturer);
        map.put("model", model);
        map.put("version", version);
        map.put("seen", seen);
        map.put("lastSeenAt", lastSeenAt);
        map.put("action", action);
        return map;
    }
}

