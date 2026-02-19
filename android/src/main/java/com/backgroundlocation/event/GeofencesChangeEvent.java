package com.backgroundlocation.event;

import com.backgroundlocation.data.GeofenceModel;
import java.util.List;

/**
 * GeofencesChangeEvent
 * GeofencesChangeEvent.java
 * Geofences değişiklik event
 */
public class GeofencesChangeEvent {
    private final List<GeofenceModel> geofences;
    private final String action; // "add", "remove", "update"
    
    public GeofencesChangeEvent(List<GeofenceModel> geofences, String action) {
        this.geofences = geofences;
        this.action = action;
    }
    
    public List<GeofenceModel> getGeofences() {
        return geofences;
    }
    
    public String getAction() {
        return action;
    }
    
    public String getEventName() {
        return "geofenceschange";
    }
}

