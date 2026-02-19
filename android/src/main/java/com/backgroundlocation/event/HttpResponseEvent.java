package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * HTTP Response Event
 * Type-safe event class
 */
public class HttpResponseEvent {
    private final int status;
    private final boolean success;
    private final String responseText;
    
    public HttpResponseEvent(int status, boolean success, String responseText) {
        this.status = status;
        this.success = success;
        this.responseText = responseText;
    }
    
    public int getStatus() {
        return status;
    }
    
    public boolean isSuccess() {
        return success;
    }
    
    public String getResponseText() {
        return responseText;
    }
    
    public JSONObject toJson() {
        try {
            JSONObject json = new JSONObject();
            json.put("status", status);
            json.put("success", success);
            json.put("responseText", responseText);
            return json;
        } catch (Exception e) {
            return new JSONObject();
        }
    }
    
    public String getEventName() {
        return "http";
    }
}



