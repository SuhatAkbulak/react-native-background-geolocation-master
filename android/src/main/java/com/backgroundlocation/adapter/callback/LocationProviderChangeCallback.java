package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.event.LocationProviderChangeEvent;

/**
 * LocationProviderChangeCallback
 * TSLocationProviderChangeCallback.java
 * Provider değişiklik callback
 */
public interface LocationProviderChangeCallback {
    void onLocationProviderChange(LocationProviderChangeEvent event);
}

