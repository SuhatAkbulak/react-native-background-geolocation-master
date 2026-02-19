package com.backgroundlocation.device;

import android.content.Context;
import android.os.Build;
import com.backgroundlocation.util.LogHelper;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * DeviceInfo
 * DeviceInfo.java
 * Cihaz bilgileri yönetimi
 */
public class DeviceInfo {
    
    public static final String ACTION_GET_DEVICE_INFO = "getDeviceInfo";
    public static final String MANUFACTURER_HUAWEI = "Huawei";
    private static final String PLATFORM = "Android";
    private static final String FRAMEWORK = "ReactNative"; // React Native için
    
    private static DeviceInfo instance = null;
    
    private String uniqueId;
    private final String model = Build.MODEL;
    private final String manufacturer = Build.MANUFACTURER;
    private final String version = Build.VERSION.RELEASE;
    
    private DeviceInfo(Context context) {
        // Unique ID'yi context'ten alabiliriz
        // TODO: Implement unique ID generation
        this.uniqueId = null;
    }
    
    private static synchronized DeviceInfo getInstanceInternal(Context context) {
        if (instance == null) {
            instance = new DeviceInfo(context.getApplicationContext());
        }
        return instance;
    }
    
    public static DeviceInfo getInstance(Context context) {
        if (instance == null) {
            instance = getInstanceInternal(context.getApplicationContext());
        }
        return instance;
    }
    
    public String getManufacturer() {
        return manufacturer;
    }
    
    public String getModel() {
        return model;
    }
    
    public String getPlatform() {
        return PLATFORM;
    }
    
    public String getFramework() {
        return FRAMEWORK;
    }
    
    public String getUniqueId() {
        return uniqueId;
    }
    
    public void setUniqueId(String uniqueId) {
        this.uniqueId = uniqueId;
    }
    
    public String getVersion() {
        return version;
    }
    
    public String print() {
        return manufacturer + " " + model + " @ " + version + " (" + FRAMEWORK + ")";
    }
    
    public JSONObject toJson() {
        JSONObject json = new JSONObject();
        try {
            json.put("model", model);
            json.put("manufacturer", manufacturer);
            json.put("version", version);
            json.put("platform", PLATFORM);
            json.put("framework", FRAMEWORK);
            if (uniqueId != null) {
                json.put("uniqueId", uniqueId);
            }
        } catch (JSONException e) {
            LogHelper.e("DeviceInfo", "Error creating JSON: " + e.getMessage(), e);
        }
        return json;
    }
    
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("model", model);
        map.put("manufacturer", manufacturer);
        map.put("version", version);
        map.put("platform", PLATFORM);
        map.put("framework", FRAMEWORK);
        if (uniqueId != null) {
            map.put("uniqueId", uniqueId);
        }
        return map;
    }
}

