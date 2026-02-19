package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.LocationModel;

/**
 * InsertLocationCallback
 * TSInsertLocationCallback.java
 * Location insert callback
 */
public interface InsertLocationCallback {
    void onSuccess(LocationModel location);
    void onFailure(String error);
}

