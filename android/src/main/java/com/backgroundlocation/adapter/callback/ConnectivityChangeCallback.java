package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.ConnectivityChangeEvent;

/**
 * Connectivity Change Callback Interface
 * TSConnectivityChangeCallback
 */
public interface ConnectivityChangeCallback {
    void onConnectivityChange(ConnectivityChangeEvent connectivityChangeEvent);
}

