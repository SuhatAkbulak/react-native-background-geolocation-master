package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.GeofenceModel;

/**
 * GetGeofenceCallback
 * TSGetGeofenceCallback.java
 * Tek geofence get callback
 */
public interface GetGeofenceCallback {
    void onSuccess(GeofenceModel geofence);
    void onFailure(String error);
}

