package com.backgroundlocation.adapter.callback;

import org.json.JSONObject;

/**
 * ConfigureCallback
 * TSConfigureCallback.java
 * Configure callback
 */
public interface ConfigureCallback {
    void onSuccess(JSONObject config);
    void onFailure(String error);
}

