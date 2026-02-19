package com.backgroundlocation.location;

import android.content.Context;
import android.location.Location;
import com.backgroundlocation.config.Config;

/**
 * MotionChangeRequest
 * TSMotionChangeRequest.java
 * Motion change request
 */
public class MotionChangeRequest extends SingleLocationRequest {
    
    public static class Builder extends SingleLocationRequest.Builder<Builder> {
        public Builder(Context context) {
            super(context);
            this.action = ACTION_MOTION_CHANGE;
            Config config = Config.getInstance(context.getApplicationContext());
            
            if (!config.enabled) {
                this.persist = false;
            } else {
                // Only persist if in tracking mode
                this.persist = true; // Simplified
            }
            
            this.timeout = 30000; // 30 seconds
            this.samples = 3;
            this.desiredAccuracy = 50;
        }
        
        public MotionChangeRequest build() {
            return new MotionChangeRequest(this);
        }
    }
    
    private MotionChangeRequest(Builder builder) {
        super(builder);
    }
    
    @Override
    protected void onLocation(Location location) {
        super.onLocation(location);
        
        long locationAge = LocationManager.locationAge(location);
        if (location.getAccuracy() <= desiredAccuracy && locationAge <= 5000) {
            finish();
        }
    }
}

