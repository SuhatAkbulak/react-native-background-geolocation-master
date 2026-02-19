package com.backgroundlocation.event;

import android.content.Context;
import org.json.JSONObject;

/**
 * Headless Event
 * HeadlessEvent.java
 * Uygulama kapalıyken (headless mode) JavaScript'e gönderilecek event'leri temsil eder
 */
public class HeadlessEvent {
    private final String name;
    private final Object event;
    private final Context context;
    
    public HeadlessEvent(Context context, String name, Object event) {
        this.context = context;
        this.name = name;
        this.event = event;
    }
    
    public String getName() {
        return name;
    }
    
    public Object getEvent() {
        return event;
    }
    
    public Context getContext() {
        return context;
    }
    
    // Event type getters
    public LocationEvent getLocationEvent() {
        return (LocationEvent) event;
    }
    
    public MotionChangeEvent getMotionChangeEvent() {
        return (MotionChangeEvent) event;
    }
    
    public GeofenceEvent getGeofenceEvent() {
        return (GeofenceEvent) event;
    }
    
    public HeartbeatEvent getHeartbeatEvent() {
        return (HeartbeatEvent) event;
    }
    
    public HttpResponseEvent getHttpEvent() {
        return (HttpResponseEvent) event;
    }
    
    public ActivityChangeEvent getActivityChangeEvent() {
        return (ActivityChangeEvent) event;
    }
    
    public ConnectivityChangeEvent getConnectivityChangeEvent() {
        return (ConnectivityChangeEvent) event;
    }
    
    public EnabledChangeEvent getEnabledChangeEvent() {
        return (EnabledChangeEvent) event;
    }
    
    public JSONObject getTerminateEvent() {
        return (JSONObject) event;
    }
}

