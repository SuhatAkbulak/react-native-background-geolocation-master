package com.backgroundlocation.adapter.callback;

import com.backgroundlocation.data.LocationModel;
import org.json.JSONObject;

/**
 * BeforeInsertBlock
 * TSBeforeInsertBlock.java
 * Location insert öncesi callback - location'ı modify edebilir
 */
public interface BeforeInsertBlock {
    JSONObject onBeforeInsert(LocationModel location);
}

