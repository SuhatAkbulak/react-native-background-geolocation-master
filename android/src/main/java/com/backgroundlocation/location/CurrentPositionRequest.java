package com.backgroundlocation.location;

import android.content.Context;
import android.location.Location;

/**
 * CurrentPositionRequest
 * TSCurrentPositionRequest.java
 * Current position request
 */
public class CurrentPositionRequest extends SingleLocationRequest {
    
    private final long maximumAge;
    
    public static class Builder extends SingleLocationRequest.Builder<Builder> {
        private long maximumAge = 0;
        
        public Builder(Context context) {
            super(context);
            this.action = ACTION_GET_CURRENT_POSITION;
        }
        
        public Builder setMaximumAge(Long maximumAge) {
            this.maximumAge = maximumAge;
            return this;
        }
        
        public CurrentPositionRequest build() {
            return new CurrentPositionRequest(this);
        }
    }
    
    protected CurrentPositionRequest(Builder builder) {
        super(builder);
        this.maximumAge = builder.maximumAge;
    }
    
    @Override
    protected void onLocation(Location location) {
        int currentState = state.get();
        super.onLocation(location);
        
        if (maximumAge > 0) {
            long locationAge = LocationManager.locationAge(location);
            if (locationAge > maximumAge || location.getAccuracy() > desiredAccuracy) {
                if (currentState == 1) {
                    state.set(2);
                }
                return;
            }
        }
        
        finish();
    }
    
    public long getMaximumAge() {
        return maximumAge;
    }
}

