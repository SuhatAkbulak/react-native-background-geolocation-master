package com.backgroundlocation.adapter.callback;

import org.json.JSONObject;

/**
 * TestServerRegistrationCallback
 * TSTestServerRegistrationCallback.java
 * Test server registration callback
 */
public interface TestServerRegistrationCallback {
    void onSuccess(JSONObject response);
    void onFailure(String error);
}

