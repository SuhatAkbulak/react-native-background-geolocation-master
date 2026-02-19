package com.backgroundlocation.adapter.callback;

/**
 * RequestPermissionCallback
 * TSRequestPermissionCallback.java
 * Permission request callback
 */
public interface RequestPermissionCallback {
    void onSuccess(int resultCode);
    void onFailure(int errorCode);
}

