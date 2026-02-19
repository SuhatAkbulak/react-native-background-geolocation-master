package com.backgroundlocation.receiver;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import com.backgroundlocation.data.GeofenceModel;
import com.backgroundlocation.data.sqlite.SQLiteGeofenceDAO;
import com.backgroundlocation.event.GeofenceEvent;

import org.greenrobot.eventbus.EventBus;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;

import org.json.JSONObject;

/**
 * Geofence Broadcast Receiver
 * Geofence olaylarını yakalar
 */
public class GeofenceBroadcastReceiver extends BroadcastReceiver {
    
    private static final String TAG = "GeofenceReceiver";
    private static final String ACTION_GEOFENCE = "com.backgroundlocation.GEOFENCE";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(intent);
        
        if (geofencingEvent == null || geofencingEvent.hasError()) {
            Log.e(TAG, "Geofencing error");
            return;
        }
        
        // Get the transition type
        int geofenceTransition = geofencingEvent.getGeofenceTransition();
        String action = getActionString(geofenceTransition);
        
        if (action == null) {
            return;
        }
        
        // Get triggering geofences
        for (Geofence geofence : geofencingEvent.getTriggeringGeofences()) {
            String identifier = geofence.getRequestId();
            
            // Get geofence details from SQLite database
            SQLiteGeofenceDAO database = SQLiteGeofenceDAO.getInstance(context);
            GeofenceModel geofenceModel = database.get(identifier);
            
            if (geofenceModel != null) {
                try {
                    // Emit event (direct EventBus)
                    GeofenceEvent event = new GeofenceEvent(
                        identifier, 
                        action, 
                        geofenceModel.toJSON()
                    );
                    EventBus.getDefault().post(event);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
    }
    
    private String getActionString(int transitionType) {
        switch (transitionType) {
            case Geofence.GEOFENCE_TRANSITION_ENTER:
                return "ENTER";
            case Geofence.GEOFENCE_TRANSITION_EXIT:
                return "EXIT";
            case Geofence.GEOFENCE_TRANSITION_DWELL:
                return "DWELL";
            default:
                return null;
        }
    }
    
    /**
     * Get PendingIntent for geofence events
     * getPendingIntent()
     */
    public static PendingIntent getPendingIntent(Context context) {
        Intent intent = new Intent(context, GeofenceBroadcastReceiver.class);
        intent.setAction(ACTION_GEOFENCE);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getBroadcast(context, 0, intent, flags);
    }
}

