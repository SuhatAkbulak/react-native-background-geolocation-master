package com.backgroundlocation.location;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.google.android.gms.location.LocationResult;
import com.backgroundlocation.util.LogHelper;

/**
 * SingleLocationReceiver
 * SingleLocationReceiver.java
 * Single location receiver - handles location updates from PendingIntent
 */
public class SingleLocationReceiver extends BroadcastReceiver {
    
    private static final String TAG = "SingleLocationReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (LocationResult.hasResult(intent)) {
            LocationResult locationResult = LocationResult.extractResult(intent);
            if (locationResult != null) {
                int requestId = intent.getIntExtra("requestId", -1);
                if (requestId >= 0) {
                    for (android.location.Location location : locationResult.getLocations()) {
                        SingleLocationResult result = new SingleLocationResult(requestId, location);
                        LocationManager.getInstance(context).onSingleLocationResult(result);
                    }
                } else {
                    LogHelper.w(TAG, "Received location update without requestId");
                }
            }
        }
    }
}

