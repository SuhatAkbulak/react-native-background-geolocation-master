package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.LocationModel;
import java.util.List;

/**
 * GetLocationsCallback
 * TSGetLocationsCallback.java
 * Locations get callback
 */
public interface GetLocationsCallback {
    void onSuccess(List<LocationModel> locations);
    void onFailure(Integer errorCode);
}

