package com.backgroundlocation.event;

import android.content.Context;
import com.backgroundlocation.data.LocationModel;
import org.json.JSONObject;

/**
 * PersistEvent
 * PersistEvent.java
 * Persist event
 */
public class PersistEvent {
    private final LocationModel location;
    private final JSONObject params;
    private final Context context;
    
    public PersistEvent(Context context, LocationModel location, JSONObject params) {
        this.context = context;
        this.location = location;
        this.params = params;
    }
    
    public Context getContext() {
        return context;
    }
    
    public LocationModel getLocation() {
        return location;
    }
    
    public JSONObject getParams() {
        return params;
    }
    
    public String getEventName() {
        return "persist";
    }
}

