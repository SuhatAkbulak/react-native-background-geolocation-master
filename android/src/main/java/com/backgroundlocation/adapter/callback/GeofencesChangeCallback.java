package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.GeofencesChangeEvent;

/**
 * GeofencesChangeCallback
 * TSGeofencesChangeCallback.java
 * Geofences değişiklik callback
 */
public interface GeofencesChangeCallback {
    void onGeofencesChange(GeofencesChangeEvent event);
}

