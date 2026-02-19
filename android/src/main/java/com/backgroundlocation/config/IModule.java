package com.backgroundlocation.config;

import org.json.JSONObject;

/**
 * IModule
 * IModule.java
 * Config modülleri için base interface
 */
public interface IModule {
    void applyDefaults();
    JSONObject toJson(boolean redact);
}

