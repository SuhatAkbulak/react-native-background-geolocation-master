package com.backgroundlocation.config;

import android.util.Log;
import com.backgroundlocation.util.LogHelper;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Notification
 * TSNotification.java
 * Notification yönetimi
 */
public class Notification extends ConfigModuleBase implements IModule {
    
    public static final String NAME = "notification";
    private static final String DEFAULT_TITLE = "";
    private static final String DEFAULT_TEXT = "Location Service activated";
    private static final Integer DEFAULT_PRIORITY = -1;
    private static final String DEFAULT_CHANNEL_NAME = "TSLocationManager";
    
    private Map<String, Object> previousValues;
    private String layout = null;
    private String title = null;
    private String text = null;
    private String smallIcon = null;
    private String largeIcon = null;
    private Integer priority = null;
    private String color = null;
    private String channelName = null;
    private String channelId = null;
    private Map<String, String> strings = null;
    private List<String> actions = null;
    private Boolean sticky = null;
    
    public Notification() {
        super(NAME);
        applyDefaults();
    }
    
    public Notification(JSONObject jsonObject, boolean applyDefaults) throws JSONException {
        super(NAME);
        if (jsonObject.has("layout")) {
            this.layout = jsonObject.getString("layout");
        }
        if (jsonObject.has("title")) {
            this.title = jsonObject.getString("title");
        }
        if (jsonObject.has("text")) {
            this.text = jsonObject.getString("text");
        }
        if (jsonObject.has("smallIcon")) {
            this.smallIcon = jsonObject.getString("smallIcon");
        }
        if (jsonObject.has("largeIcon")) {
            this.largeIcon = jsonObject.getString("largeIcon");
        }
        if (jsonObject.has("priority")) {
            this.priority = jsonObject.getInt("priority");
        }
        if (jsonObject.has("color")) {
            this.color = jsonObject.getString("color");
        }
        if (jsonObject.has("channelName")) {
            this.channelName = jsonObject.getString("channelName");
        }
        if (jsonObject.has("channelId")) {
            this.channelId = jsonObject.getString("channelId");
        }
        if (jsonObject.has("strings")) {
            this.strings = new HashMap<>();
            JSONObject stringsObj = jsonObject.getJSONObject("strings");
            Iterator<String> keys = stringsObj.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                addString(key, stringsObj.getString(key));
            }
        }
        if (jsonObject.has("actions")) {
            this.actions = new ArrayList<>();
            JSONArray actionsArray = jsonObject.getJSONArray("actions");
            for (int i = 0; i < actionsArray.length(); i++) {
                addAction(actionsArray.getString(i));
            }
        }
        if (jsonObject.has("sticky")) {
            this.sticky = jsonObject.getBoolean("sticky");
        }
        if (applyDefaults) {
            applyDefaults();
        }
    }
    
    @Override
    public void applyDefaults() {
        if (this.title == null) {
            this.title = DEFAULT_TITLE;
        }
        if (this.text == null) {
            this.text = DEFAULT_TEXT;
        }
        if (this.priority == null) {
            this.priority = DEFAULT_PRIORITY;
        }
        if (this.color == null) {
            this.color = "";
        }
        if (this.smallIcon == null) {
            this.smallIcon = "";
        }
        if (this.largeIcon == null) {
            this.largeIcon = "";
        }
        if (this.channelName == null) {
            this.channelName = DEFAULT_CHANNEL_NAME;
        }
        if (this.channelId == null) {
            this.channelId = "";
        }
        if (this.layout == null) {
            this.layout = "";
        }
        if (this.strings == null) {
            this.strings = new HashMap<>();
        }
        if (this.actions == null) {
            this.actions = new ArrayList<>();
        }
        if (this.sticky == null) {
            this.sticky = false;
        }
    }
    
    public void addAction(String action) {
        if (actions == null) {
            actions = new ArrayList<>();
        }
        actions.add(action);
    }
    
    public void addString(String key, String value) {
        if (strings == null) {
            strings = new HashMap<>();
        }
        strings.put(key, value);
    }
    
    @Override
    public JSONObject toJson(boolean redact) {
        JSONObject json = new JSONObject();
        try {
            JSONObject stringsObj = new JSONObject();
            JSONArray actionsArray = new JSONArray();
            
            json.put("layout", layout);
            json.put("title", title);
            json.put("text", text);
            json.put("color", color);
            json.put("channelName", channelName);
            json.put("channelId", channelId);
            json.put("smallIcon", smallIcon);
            json.put("largeIcon", largeIcon);
            json.put("priority", priority);
            json.put("sticky", sticky);
            
            if (strings != null) {
                for (Map.Entry<String, String> entry : strings.entrySet()) {
                    stringsObj.put(entry.getKey(), entry.getValue());
                }
            }
            json.put("strings", stringsObj);
            
            if (actions != null) {
                for (String action : actions) {
                    actionsArray.put(action);
                }
            }
            json.put("actions", actionsArray);
        } catch (JSONException e) {
            Log.e("Notification", "Error creating JSON: " + e.getMessage(), e);
            LogHelper.e("Notification", "Error creating JSON: " + e.getMessage(), e);
        }
        return json;
    }
    
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("layout", layout);
        map.put("title", title);
        map.put("text", text);
        map.put("color", color);
        map.put("channelName", channelName);
        map.put("channelId", channelId);
        map.put("smallIcon", smallIcon);
        map.put("largeIcon", largeIcon);
        map.put("priority", priority);
        map.put("strings", strings);
        map.put("actions", actions);
        map.put("sticky", sticky);
        return map;
    }
    
    public Map<String, Object> getPreviousValues() {
        return previousValues;
    }
    
    public boolean update(Notification other) {
        this.previousValues = toMap();
        clearDirtyFields();
        
        if (other.getTitle() != null && !other.getTitle().equals(this.title)) {
            this.title = other.getTitle();
            markDirty("title");
        }
        if (other.getText() != null && !other.getText().equals(this.text)) {
            this.text = other.getText();
            markDirty("text");
        }
        if (other.getLayout() != null && !other.getLayout().equals(this.layout)) {
            this.layout = other.getLayout();
            markDirty("layout");
        }
        if (other.getColor() != null && !other.getColor().equals(this.color)) {
            this.color = other.getColor();
            markDirty("color");
        }
        if (other.getSmallIcon() != null && !other.getSmallIcon().equals(this.smallIcon)) {
            this.smallIcon = other.getSmallIcon();
            markDirty("smallIcon");
        }
        if (other.getLargeIcon() != null && !other.getLargeIcon().equals(this.largeIcon)) {
            this.largeIcon = other.getLargeIcon();
            markDirty("largeIcon");
        }
        if (other.getPriority() != null && !other.getPriority().equals(this.priority)) {
            this.priority = other.getPriority();
            markDirty("priority");
        }
        if (other.getSticky() != null && !other.getSticky().equals(this.sticky)) {
            this.sticky = other.getSticky();
            markDirty("sticky");
        }
        if (other.getActions() != null && (!this.actions.containsAll(other.getActions()) || 
            other.getActions().size() != this.actions.size())) {
            this.actions = other.getActions();
            markDirty("actions");
        }
        if (other.getStrings() != null && !other.getStrings().equals(this.strings)) {
            this.strings = other.getStrings();
            markDirty("strings");
        }
        if (other.getChannelName() != null && !other.getChannelName().equals(this.channelName)) {
            this.channelName = other.getChannelName();
            markDirty("channelName");
        }
        if (other.getChannelId() != null && !other.getChannelId().equals(this.channelId)) {
            this.channelId = other.getChannelId();
            markDirty("channelId");
        }
        
        return !getDirtyFields().isEmpty();
    }
    
    // Getters and Setters
    public String getLayout() { return layout; }
    public void setLayout(String layout) { this.layout = layout; }
    
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    
    public String getText() { return text; }
    public void setText(String text) { this.text = text; }
    
    public String getSmallIcon() { return smallIcon; }
    public void setSmallIcon(String smallIcon) { this.smallIcon = smallIcon; }
    
    public String getLargeIcon() { return largeIcon; }
    public void setLargeIcon(String largeIcon) { this.largeIcon = largeIcon; }
    
    public Integer getPriority() { return priority; }
    public void setPriority(Integer priority) { this.priority = priority; }
    
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }
    
    public String getChannelName() { return channelName; }
    public void setChannelName(String channelName) { this.channelName = channelName; }
    
    public String getChannelId() { return channelId; }
    public void setChannelId(String channelId) { this.channelId = channelId; }
    
    public Map<String, String> getStrings() { return strings; }
    public void setStrings(Map<String, String> strings) { this.strings = strings; }
    
    public String getString(String key) {
        if (strings == null || !strings.containsKey(key)) {
            return null;
        }
        return strings.get(key);
    }
    
    public List<String> getActions() { return actions; }
    public void setActions(List<String> actions) { this.actions = actions; }
    
    public Boolean getSticky() { return sticky; }
    public void setSticky(Boolean sticky) { this.sticky = sticky; }
}

