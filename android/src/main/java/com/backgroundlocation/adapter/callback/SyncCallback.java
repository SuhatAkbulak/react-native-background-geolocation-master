package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.LocationModel;
import java.util.List;

/**
 * SyncCallback
 * TSSyncCallback.java
 * Sync callback
 */
public interface SyncCallback {
    void onSuccess(List<LocationModel> locations);
    void onFailure(String error);
}

