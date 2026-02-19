package com.backgroundlocation.config;

import android.content.Context;
import android.util.Log;
import com.backgroundlocation.event.AuthorizationEvent;
import com.backgroundlocation.util.LogHelper;
import okhttp3.Call;
import okhttp3.FormBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Authorization
 * Authorization
 * Authorization yönetimi - JWT ve SAS token desteği
 */
public class Authorization extends ConfigModuleBase implements IModule {
    
    public static final String CONTENT_TYPE_FORM = "application/x-www-form-urlencoded";
    public static final String FIELD_ACCESS_TOKEN = "accessToken";
    public static final String FIELD_EXPIRES = "expires";
    public static final String FIELD_REFRESH_HEADERS = "refreshHeaders";
    public static final String FIELD_REFRESH_PAYLOAD = "refreshPayload";
    public static final String FIELD_REFRESH_TOKEN = "refreshToken";
    public static final String FIELD_REFRESH_URL = "refreshUrl";
    public static final String FIELD_STRATEGY = "strategy";
    public static final String NAME = "authorization";
    public static final String STRATEGY_JWT = "JWT";
    public static final String STRATEGY_SAS = "SAS";
    
    private static final String REFRESH_TOKEN_PLACEHOLDER = "{refreshToken}";
    private static final String ACCESS_TOKEN_PLACEHOLDER = "{accessToken}";
    private static final Pattern ACCESS_TOKEN_PATTERN = Pattern.compile("^(access|auth|id_token)");
    private static final Pattern REFRESH_TOKEN_PATTERN = Pattern.compile("^(renew|refresh)");
    private static final Pattern EXPIRES_PATTERN = Pattern.compile("^expir.*");
    
    private String strategy = null;
    private String accessToken = null;
    private String refreshToken = null;
    private String refreshUrl = null;
    private Map<String, Object> refreshPayload = null;
    private Map<String, Object> refreshHeaders = null;
    private long expires = -1;
    
    private boolean foundAccessToken = false;
    private boolean foundRefreshToken = false;
    private boolean foundExpires = false;
    
    public Authorization() {
        super(NAME);
        applyDefaults();
    }
    
    public Authorization(JSONObject jsonObject, boolean applyDefaults) throws JSONException {
        super(NAME);
        if (jsonObject.has(FIELD_STRATEGY)) {
            this.strategy = jsonObject.getString(FIELD_STRATEGY);
        }
        if (jsonObject.has(FIELD_ACCESS_TOKEN)) {
            this.accessToken = jsonObject.getString(FIELD_ACCESS_TOKEN);
        }
        if (jsonObject.has(FIELD_REFRESH_TOKEN)) {
            this.refreshToken = jsonObject.getString(FIELD_REFRESH_TOKEN);
        }
        if (jsonObject.has(FIELD_REFRESH_URL)) {
            this.refreshUrl = jsonObject.getString(FIELD_REFRESH_URL);
        }
        if (jsonObject.has(FIELD_REFRESH_PAYLOAD)) {
            // TODO: Implement Util.toMap
            // this.refreshPayload = Util.toMap(jsonObject.getJSONObject(FIELD_REFRESH_PAYLOAD));
            this.refreshPayload = jsonObjectToMap(jsonObject.getJSONObject(FIELD_REFRESH_PAYLOAD));
        }
        if (jsonObject.has(FIELD_REFRESH_HEADERS)) {
            // TODO: Implement Util.toMap
            // this.refreshHeaders = Util.toMap(jsonObject.getJSONObject(FIELD_REFRESH_HEADERS));
            this.refreshHeaders = jsonObjectToMap(jsonObject.getJSONObject(FIELD_REFRESH_HEADERS));
        }
        if (jsonObject.has(FIELD_EXPIRES)) {
            this.expires = jsonObject.getLong(FIELD_EXPIRES);
        }
        if (applyDefaults) {
            applyDefaults();
        }
    }
    
    public Authorization(Map<String, Object> map) {
        super(NAME);
        if (map.containsKey(FIELD_STRATEGY)) {
            this.strategy = (String) map.get(FIELD_STRATEGY);
        }
        if (map.containsKey(FIELD_ACCESS_TOKEN)) {
            this.accessToken = (String) map.get(FIELD_ACCESS_TOKEN);
        }
        if (map.containsKey(FIELD_REFRESH_TOKEN)) {
            this.refreshToken = (String) map.get(FIELD_REFRESH_TOKEN);
        }
        if (map.containsKey(FIELD_REFRESH_URL)) {
            this.refreshUrl = (String) map.get(FIELD_REFRESH_URL);
        }
        if (map.containsKey(FIELD_REFRESH_PAYLOAD)) {
            this.refreshPayload = (Map<String, Object>) map.get(FIELD_REFRESH_PAYLOAD);
        }
        if (map.containsKey(FIELD_REFRESH_HEADERS)) {
            this.refreshHeaders = (Map<String, Object>) map.get(FIELD_REFRESH_HEADERS);
        }
        if (map.containsKey(FIELD_EXPIRES)) {
            Object expiresObj = map.get(FIELD_EXPIRES);
            if (expiresObj instanceof Number) {
                this.expires = ((Number) expiresObj).longValue();
            }
        }
    }
    
    @Override
    public void applyDefaults() {
        if (this.strategy == null) {
            this.strategy = STRATEGY_JWT;
        }
        if (this.refreshPayload == null) {
            this.refreshPayload = new HashMap<>();
        }
        if (this.refreshHeaders == null) {
            this.refreshHeaders = new HashMap<>();
            if (this.strategy.equalsIgnoreCase(STRATEGY_JWT)) {
                this.refreshHeaders.put("Authorization", "Bearer " + ACCESS_TOKEN_PLACEHOLDER);
            } else if (this.strategy.equalsIgnoreCase(STRATEGY_SAS)) {
                this.refreshHeaders.put("Authorization", ACCESS_TOKEN_PLACEHOLDER);
            }
        }
    }
    
    public void apply(Request.Builder builder) {
        if (this.accessToken == null) {
            return;
        }
        if (this.strategy.equalsIgnoreCase(STRATEGY_JWT)) {
            builder.header("Authorization", "Bearer " + this.accessToken);
        } else if (this.strategy.equalsIgnoreCase(STRATEGY_SAS)) {
            builder.header("Authorization", this.accessToken);
        }
    }
    
    public boolean canRefreshAuthorizationToken() {
        return refreshUrl != null && !refreshUrl.isEmpty() &&
               refreshToken != null && !refreshToken.isEmpty() &&
               refreshPayload != null && !refreshPayload.isEmpty();
    }
    
    public void refreshAuthorizationToken(Context context, Authorization.Callback callback) {
        if (!canRefreshAuthorizationToken()) {
            callback.invoke(new AuthorizationEvent(0, "Cannot refresh: missing refreshUrl, refreshToken, or refreshPayload"));
            return;
        }
        
        // TODO: Implement HttpService
        // OkHttpClient client = HttpService.getInstance(context).getClient();
        OkHttpClient client = new OkHttpClient();
        FormBody.Builder formBuilder = new FormBody.Builder();
        
        // Build form payload with refresh token replacement
        for (Map.Entry<String, Object> entry : refreshPayload.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();
            if (value instanceof String) {
                String strValue = (String) value;
                if (strValue.contains(REFRESH_TOKEN_PLACEHOLDER)) {
                    value = strValue.replace(REFRESH_TOKEN_PLACEHOLDER, refreshToken);
                }
            }
            formBuilder.add(key, value.toString());
        }
        
        Request.Builder requestBuilder = new Request.Builder()
            .url(refreshUrl)
            .post(formBuilder.build());
        
        // Add default headers from Config
        Config config = Config.getInstance(context);
        try {
            JSONObject headers = new JSONObject(config.headers);
            Iterator<String> keys = headers.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                if (key != null && !key.equalsIgnoreCase("content-type")) {
                    requestBuilder.header(key, headers.getString(key));
                }
            }
        } catch (JSONException e) {
            LogHelper.w("Authorization", "Invalid headers in config: " + e.getMessage());
        }
        
        requestBuilder.header("Content-Type", CONTENT_TYPE_FORM);
        
        // Add refresh headers with access token replacement
        for (Map.Entry<String, Object> entry : refreshHeaders.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();
            if (value instanceof String) {
                String strValue = (String) value;
                if (strValue.contains(ACCESS_TOKEN_PLACEHOLDER)) {
                    value = strValue.replace(ACCESS_TOKEN_PLACEHOLDER, accessToken != null ? accessToken : "");
                }
            }
            requestBuilder.header(key, value.toString());
        }
        
        client.newCall(requestBuilder.build()).enqueue(new okhttp3.Callback() {
            @Override
            public void onFailure(Call call, IOException e) {
                LogHelper.w("Authorization", "Refresh token failure: " + e.getMessage());
                callback.invoke(new AuthorizationEvent(0, e.getMessage()));
            }
            
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                ResponseBody body = response.body();
                if (body == null) {
                    callback.invoke(new AuthorizationEvent(response.code(), "NO_RESPONSE_DATA"));
                    return;
                }
                
                try {
                    String responseString = body.string();
                    JSONObject jsonObject = new JSONObject(responseString);
                    
                    if (response.isSuccessful()) {
                        parseRefreshResponse(context, response.code(), jsonObject, callback);
                    } else {
                        callback.invoke(new AuthorizationEvent(response.code(), responseString));
                    }
                } catch (JSONException e) {
                    callback.invoke(new AuthorizationEvent(response.code(), e.getMessage()));
                }
            }
        });
    }
    
    private void parseRefreshResponse(Context context, int statusCode, JSONObject jsonObject, Callback callback) {
        foundAccessToken = false;
        foundRefreshToken = false;
        foundExpires = false;
        
        try {
            Authorization newAuth = new Authorization();
            newAuth.setStrategy(strategy);
            newAuth.setRefreshToken(refreshToken);
            newAuth.setRefreshPayload(refreshPayload);
            newAuth.setRefreshHeaders(refreshHeaders);
            
            parseJsonRecursive(jsonObject, newAuth);
            
            if (foundAccessToken) {
                LogHelper.d("Authorization", "Refresh token success");
                Config.getInstance(context).updateAuthorization(newAuth);
                callback.invoke(new AuthorizationEvent(statusCode, jsonObject));
            } else {
                callback.invoke(new AuthorizationEvent(statusCode, "Failed to find refreshToken or accessToken in response from " + refreshUrl));
            }
        } catch (JSONException e) {
            String error = "Error parsing response data from refreshUrl: " + e.getMessage();
            LogHelper.e("Authorization", error, e);
            callback.invoke(new AuthorizationEvent(statusCode, error));
        }
    }
    
    private void parseJsonRecursive(JSONObject jsonObject, Authorization auth) throws JSONException {
        Iterator<String> keys = jsonObject.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object obj = jsonObject.get(key);
            
            if (obj instanceof JSONObject) {
                parseJsonRecursive((JSONObject) obj, auth);
            } else if (!(obj instanceof JSONArray)) {
                String value = obj.toString();
                boolean isNumeric = isNumeric(value);
                
                if (!foundAccessToken && ACCESS_TOKEN_PATTERN.matcher(key).find() && !isNumeric) {
                    foundAccessToken = true;
                    LogHelper.d("Authorization", "Received accessToken");
                    auth.setAccessToken(value);
                } else if (!foundRefreshToken && REFRESH_TOKEN_PATTERN.matcher(key).find() && !isNumeric) {
                    foundRefreshToken = true;
                    LogHelper.d("Authorization", "Received refreshToken");
                    auth.setRefreshToken(value);
                } else if (!foundExpires && EXPIRES_PATTERN.matcher(key).find()) {
                    foundExpires = true;
                    LogHelper.d("Authorization", "Received expires");
                    auth.setExpires(Long.parseLong(value));
                }
            }
        }
    }
    
    private static boolean isNumeric(String str) {
        try {
            Double.parseDouble(str);
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
    
    @Override
    public JSONObject toJson(boolean redact) {
        JSONObject json = new JSONObject();
        try {
            if (accessToken == null) {
                return json;
            }
            
            String accessTokenValue = accessToken;
            if (redact && accessToken.length() > 5) {
                accessTokenValue = accessToken.substring(0, Math.min(accessToken.length(), 5)) + "<redacted>";
            }
            
            String refreshTokenValue = refreshToken;
            if (refreshToken != null && redact && refreshToken.length() > 5) {
                refreshTokenValue = refreshToken.substring(0, Math.min(refreshToken.length(), 5)) + "<redacted>";
            }
            
            json.put(FIELD_STRATEGY, strategy);
            json.put(FIELD_ACCESS_TOKEN, accessTokenValue);
            json.put(FIELD_REFRESH_TOKEN, refreshTokenValue);
            json.put(FIELD_REFRESH_URL, refreshUrl);
            json.put(FIELD_REFRESH_PAYLOAD, refreshPayload != null ? new JSONObject(refreshPayload) : null);
            json.put(FIELD_REFRESH_HEADERS, refreshHeaders != null ? new JSONObject(refreshHeaders) : null);
            json.put(FIELD_EXPIRES, expires);
        } catch (JSONException e) {
            Log.e("Authorization", "Error creating JSON: " + e.getMessage(), e);
        }
        return json;
    }
    
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put(FIELD_STRATEGY, strategy);
        map.put(FIELD_ACCESS_TOKEN, accessToken);
        map.put(FIELD_REFRESH_TOKEN, refreshToken);
        map.put(FIELD_REFRESH_URL, refreshUrl);
        map.put(FIELD_REFRESH_PAYLOAD, refreshPayload);
        map.put(FIELD_REFRESH_HEADERS, refreshHeaders);
        map.put(FIELD_EXPIRES, expires);
        return map;
    }
    
    // Getters and Setters
    public String getStrategy() { return strategy; }
    public void setStrategy(String strategy) { this.strategy = strategy; }
    
    public String getAccessToken() { return accessToken; }
    public void setAccessToken(String accessToken) { this.accessToken = accessToken; }
    
    public String getRefreshToken() { return refreshToken; }
    public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }
    
    public String getRefreshUrl() { return refreshUrl; }
    public void setRefreshUrl(String refreshUrl) { this.refreshUrl = refreshUrl; }
    
    public Map<String, Object> getRefreshPayload() { return refreshPayload; }
    public void setRefreshPayload(Map<String, Object> refreshPayload) { this.refreshPayload = refreshPayload; }
    
    public Map<String, Object> getRefreshHeaders() { return refreshHeaders; }
    public void setRefreshHeaders(Map<String, Object> refreshHeaders) { this.refreshHeaders = refreshHeaders; }
    
    public long getExpires() { return expires; }
    public void setExpires(long expires) { this.expires = expires; }
    
    public interface Callback {
        void invoke(AuthorizationEvent event);
    }
    
    // Helper method - TODO: Move to Util class
    private static Map<String, Object> jsonObjectToMap(JSONObject jsonObject) throws JSONException {
        Map<String, Object> map = new HashMap<>();
        Iterator<String> keys = jsonObject.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = jsonObject.get(key);
            if (value instanceof JSONObject) {
                map.put(key, jsonObjectToMap((JSONObject) value));
            } else {
                map.put(key, value);
            }
        }
        return map;
    }
}

