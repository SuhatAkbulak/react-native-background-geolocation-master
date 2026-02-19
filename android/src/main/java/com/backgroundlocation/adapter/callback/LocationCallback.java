package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.LocationModel;

/**
 * Location Callback Interface
 * TSLocationCallback
 */
public interface LocationCallback {
    void onError(Integer errorCode);
    void onLocation(LocationModel location);
}

