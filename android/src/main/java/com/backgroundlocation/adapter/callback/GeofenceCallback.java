package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.GeofenceEvent;

/**
 * Geofence Callback Interface
 * TSGeofenceCallback
 */
public interface GeofenceCallback {
    void onGeofence(GeofenceEvent geofenceEvent);
}

