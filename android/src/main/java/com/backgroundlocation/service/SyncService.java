package com.backgroundlocation.service;

import android.content.Context;
import android.os.AsyncTask;

import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.data.sqlite.SQLiteLocationDAO;
import com.backgroundlocation.event.HttpResponseEvent;
import com.backgroundlocation.util.LogHelper;

import org.greenrobot.eventbus.EventBus;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Iterator;
import java.util.List;
import java.util.ArrayList;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * HTTP Sync Service
 * LOCKING mekanizmalı batch sync
 * 
 * CRITICAL FEATURES:
 * 1. Locking: kayıtları sync sırasında kilitler
 * 2. Batch: toplu gönderim (multi-location)
 * 3. Unlock: başarısız olursa kilidi açar
 * 4. Destroy: başarılı olursa siler
 * 5. Retry: offline iken queue'da bekler
 */
public class SyncService {
    
    private static final String TAG = "SyncService";
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");
    
    // Thread-safe busy flag ()
    private static final AtomicBoolean isSyncing = new AtomicBoolean(false);
    
    /**
     * Sync locations to server with LOCKING mechanism
     * AtomicBoolean compareAndSet
     */
    public static void sync(Context context) {
        // Thread-safe check ()
        if (isSyncing.compareAndSet(false, true)) {
            new SyncTask(context).execute();
        } else {
            LogHelper.d(context, TAG, "⏸️ HttpService is busy, skipping");
        }
    }
    
    private static class SyncTask extends AsyncTask<Void, Void, SyncResult> {
        private Context context;
        private Config config;
        private SQLiteLocationDAO database;
        
        public SyncTask(Context context) {
            this.context = context.getApplicationContext();
            this.config = Config.getInstance(this.context);
            this.database = SQLiteLocationDAO.getInstance(this.context);
        }
        
        @Override
        protected void onPreExecute() {
            // isSyncing already set in sync() method
        }
        
        @Override
        protected SyncResult doInBackground(Void... voids) {
            try {
                // 1. Get unlocked count ()
                int unlockedCount = database.count(true); // only unlocked
                
                LogHelper.d(TAG, "📊 Unlocked locations: " + unlockedCount);
                
                // Check threshold
                if (config.autoSyncThreshold > 0 && unlockedCount < config.autoSyncThreshold) {
                    android.util.Log.i(TAG, "⏸️ Below threshold (" + config.autoSyncThreshold + "), skipping sync");
                    return new SyncResult(true, 0, "Below threshold");
                }
                
                // 2. CRITICAL: Get locations WITH LOCKING ()
                // This will SELECT WHERE locked=0 and UPDATE SET locked=1
                List<LocationModel> locations = database.allWithLocking(config.maxBatchSize);
                
                if (locations.isEmpty()) {
                    LogHelper.d(TAG, "ℹ️ No locations to sync");
                    return new SyncResult(true, 0, "No locations to sync");
                }
                
                LogHelper.d(TAG, "🔒 Locked " + locations.size() + " records (allWithLocking)");
                
                // 4. Convert to JSON array (batch)
                JSONArray jsonArray = new JSONArray();
                for (LocationModel location : locations) {
                    jsonArray.put(location.toJSON());
                }
                
                // 5. Prepare request body
                JSONObject body = new JSONObject();
                
                // Check batchSync mode
                if (config.batchSync) {
                    // Batch mode: wrap in "locations" array
                    body.put("locations", jsonArray);
                } else {
                    // Single mode: send first location only
                    if (jsonArray.length() > 0) {
                        body = jsonArray.getJSONObject(0);
                    }
                }
                
                // Merge params from config
                if (config.params != null && !config.params.isEmpty()) {
                    try {
                        JSONObject paramsJson = new JSONObject(config.params);
                        Iterator<String> keys = paramsJson.keys();
                        while (keys.hasNext()) {
                            String key = keys.next();
                            body.put(key, paramsJson.get(key));
                        }
                    } catch (Exception e) {
                        LogHelper.w(TAG, "Failed to merge params: " + e.getMessage());
                    }
                }
                
                // 6. Create HTTP client
                OkHttpClient client = new OkHttpClient.Builder()
                        .connectTimeout(30, TimeUnit.SECONDS)
                        .readTimeout(30, TimeUnit.SECONDS)
                        .writeTimeout(30, TimeUnit.SECONDS)
                        .build();
                
                // 7. Build request with headers
                RequestBody requestBody = RequestBody.create(body.toString(), JSON);
                Request.Builder requestBuilder = new Request.Builder()
                        .url(config.url);
                
                // Add headers from config
                requestBuilder.addHeader("Content-Type", "application/json");
                if (config.headers != null && !config.headers.isEmpty()) {
                    try {
                        JSONObject headersJson = new JSONObject(config.headers);
                        Iterator<String> keys = headersJson.keys();
                        while (keys.hasNext()) {
                            String key = keys.next();
                            String value = headersJson.getString(key);
                            requestBuilder.addHeader(key, value);
                        }
                    } catch (Exception e) {
                        LogHelper.w(TAG, "Failed to add headers: " + e.getMessage());
                    }
                }
                
                if (config.method.equalsIgnoreCase("POST")) {
                    requestBuilder.post(requestBody);
                } else if (config.method.equalsIgnoreCase("PUT")) {
                    requestBuilder.put(requestBody);
                }
                
                Request request = requestBuilder.build();
                
                LogHelper.d(TAG, "HTTP " + config.method + " batch (" + locations.size() + ") to " + config.url);
                
                // 8. Execute request
                Response response = client.newCall(request).execute();
                int statusCode = response.code();
                String responseBody = response.body() != null ? response.body().string() : "";
                
                boolean success = response.isSuccessful();
                
                LogHelper.d(TAG, "HTTP Response: " + statusCode + " - " +
                    (success ? "SUCCESS" : "FAILED"));
                
                // 9. Emit HTTP event (direct EventBus)
                HttpResponseEvent httpEvent = new HttpResponseEvent(statusCode, success, responseBody);
                EventBus.getDefault().post(httpEvent);
                
                if (success) {
                    // 10. SUCCESS: Delete synced locations ()
                    database.destroyAll(locations);
                    LogHelper.d(TAG, "✅ DELETED " + locations.size() + " synced records");
                    
                    // Check if there are more to sync (recursive pattern)
                    int remaining = database.count(true); // unlocked count
                    if (config.autoSyncThreshold > 0 && remaining >= config.autoSyncThreshold) {
                        // Recursively sync more
                        LogHelper.d(TAG, "🔄 More locations to sync (" + remaining + "), continuing...");
                        return doInBackground(); // Recursive call
                    }
                    
                    return new SyncResult(true, locations.size(), responseBody);
                } else {
                    // 11. FAILURE: Unlock locations for retry ()
                    database.unlock(locations);
                    LogHelper.w(TAG, "🔓 UNLOCKED " + locations.size() + " records (will retry later)");
                    
                    return new SyncResult(false, 0, "HTTP " + statusCode + ": " + responseBody);
                }
                
            } catch (Exception e) {
                e.printStackTrace();
                
                // On exception, unlock all to be safe ()
                try {
                    database.unlockAll();
                    LogHelper.w(TAG, "🔓 Unlocked all locations due to exception");
                } catch (Exception ex) {
                    ex.printStackTrace();
                }
                
                return new SyncResult(false, 0, e.getMessage());
            }
        }
        
        @Override
        protected void onPostExecute(SyncResult result) {
            // Release busy flag ()
            isSyncing.set(false);
            
            if (!result.success && result.message != null) {
                LogHelper.e(TAG, "❌ Sync failed: " + result.message);
            } else if (result.success && result.count > 0) {
                LogHelper.d(TAG, "✅ Sync completed: " + result.count + " locations synced");
            }
        }
    }
    
    /**
     * Result class for sync operation
     */
    private static class SyncResult {
        boolean success;
        int count;
        String message;
        
        SyncResult(boolean success, int count, String message) {
            this.success = success;
            this.count = count;
            this.message = message;
        }
    }
    
    /**
     * Check if network is available
     */
    public static boolean isNetworkAvailable(Context context) {
        try {
            android.net.ConnectivityManager cm = 
                (android.net.ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            android.net.NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
            return activeNetwork != null && activeNetwork.isConnectedOrConnecting();
        } catch (Exception e) {
            return false;
        }
    }
}
