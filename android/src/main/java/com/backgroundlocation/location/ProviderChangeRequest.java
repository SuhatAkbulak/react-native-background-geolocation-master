package com.backgroundlocation.location;

import android.content.Context;
import com.backgroundlocation.config.Config;

/**
 * ProviderChangeRequest
 * TSProviderChangeRequest.java
 * Provider change request
 */
public class ProviderChangeRequest extends SingleLocationRequest {
    
    public static class Builder extends SingleLocationRequest.Builder<Builder> {
        public Builder(Context context) {
            super(context);
            this.action = ACTION_PROVIDER_CHANGE;
            Config config = Config.getInstance(context.getApplicationContext());
            this.persist = config.enabled; // Simplified
        }
        
        public ProviderChangeRequest build() {
            return new ProviderChangeRequest(this);
        }
    }
    
    ProviderChangeRequest(Builder builder) {
        super(builder);
    }
}

