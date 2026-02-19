package com.backgroundlocation.adapter.callback;

import org.json.JSONObject;

/**
 * GetLogCallback
 * TSGetLogCallback.java
 * Log get callback
 */
public interface GetLogCallback {
    void onSuccess(JSONObject log);
    void onFailure(String error);
}

