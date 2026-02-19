package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.GeofenceModel;
import java.util.List;

/**
 * GetGeofencesCallback
 * TSGetGeofencesCallback.java
 * Tüm geofences get callback
 */
public interface GetGeofencesCallback {
    void onSuccess(List<GeofenceModel> geofences);
    void onFailure(String error);
}

