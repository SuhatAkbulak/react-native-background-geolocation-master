package com.backgroundlocation.location;

import android.location.Location;

/**
 * WatchPositionResult
 * WatchPositionResult.java
 * Watch position result
 */
public class WatchPositionResult {
    
    private final Location location;
    private final boolean isFinished;
    
    public WatchPositionResult(Location location, boolean isFinished) {
        this.location = location;
        this.isFinished = isFinished;
    }
    
    public Location getLocation() {
        return location;
    }
    
    public boolean isFinished() {
        return isFinished;
    }
}

