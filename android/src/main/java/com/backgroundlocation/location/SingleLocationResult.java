package com.backgroundlocation.location;

import android.location.Location;

/**
 * SingleLocationResult
 * SingleLocationResult.java
 * Single location result
 */
public class SingleLocationResult {
    
    private final int requestId;
    private final Location location;
    
    public SingleLocationResult(int requestId, Location location) {
        this.requestId = requestId;
        this.location = location;
    }
    
    public int getRequestId() {
        return requestId;
    }
    
    public Location getLocation() {
        return location;
    }
}

