package com.backgroundlocation.http;

import android.content.Context;
import com.backgroundlocation.util.LogHelper;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * HttpResponse
 * HttpResponse.java
 * HTTP response model
 */
public class HttpResponse {
    
    private final Context context;
    public String responseText = "";
    public int status;
    
    public HttpResponse(Context context, int status, String responseText) {
        this.context = context;
        this.status = status;
        if (responseText != null) {
            this.responseText = responseText;
        }
    }
    
    public Context getContext() {
        return context;
    }
    
    public String getResponseText() {
        return responseText;
    }
    
    public void setResponseText(String responseText) {
        this.responseText = responseText;
    }
    
    public int getStatus() {
        return status;
    }
    
    public void setStatus(int status) {
        this.status = status;
    }
    
    public Boolean isSuccess() {
        return status == 200 || status == 201 || status == 204;
    }
    
    public JSONObject toJson() {
        JSONObject json = new JSONObject();
        try {
            json.put("status", status);
            json.put("responseText", responseText);
            json.put("success", isSuccess());
        } catch (JSONException e) {
            LogHelper.e("HttpResponse", "Error creating JSON: " + e.getMessage(), e);
        }
        return json;
    }
}

