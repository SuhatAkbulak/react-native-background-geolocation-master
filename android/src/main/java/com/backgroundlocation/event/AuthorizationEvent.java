package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * AuthorizationEvent
 * AuthorizationEvent.java
 * Authorization event
 */
public class AuthorizationEvent {
    private final int statusCode;
    private final String error;
    private final JSONObject response;
    
    public AuthorizationEvent(int statusCode, String error) {
        this.statusCode = statusCode;
        this.error = error;
        this.response = null;
    }
    
    public AuthorizationEvent(int statusCode, JSONObject response) {
        this.statusCode = statusCode;
        this.error = null;
        this.response = response;
    }
    
    public int getStatusCode() {
        return statusCode;
    }
    
    public String getError() {
        return error;
    }
    
    public JSONObject getResponse() {
        return response;
    }
    
    public boolean isSuccess() {
        return error == null && response != null;
    }
    
    public String getEventName() {
        return "authorization";
    }
}

