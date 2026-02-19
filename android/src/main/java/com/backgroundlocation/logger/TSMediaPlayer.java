package com.backgroundlocation.logger;

import android.content.Context;
import android.media.MediaPlayer;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.util.LogHelper;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * TSMediaPlayer
 * TSMediaPlayer.java
 * Media player - ses çalma için (debug modda)
 */
public class TSMediaPlayer {
    
    // Sound constants
    public static final String BEEP_OFF = "tslocationmanager_beep_off";
    public static final String BEEP_ON = "tslocationmanager_beep_on";
    public static final String BEEP_TRIP_DRY = "tslocationmanager_beep_trip_dry";
    public static final String BEEP_TRIP_UP_DRY = "tslocationmanager_beep_trip_up_dry";
    public static final String BEEP_TRIP_UP_ECHO = "tslocationmanager_beep_trip_up_echo";
    public static final String BELL_DING_POP = "tslocationmanager_bell_ding_pop";
    public static final String BUTTON_CLICK = "tslocationmanager_click_tap_done_checkbox1";
    public static final String CHIME_BELL_CONFIRM = "tslocationmanager_chime_bell_confirm";
    public static final String CHIME_SHORT_CHORD_UP = "tslocationmanager_chime_short_chord_up";
    public static final String CHIME_SHORT_OFF = "tslocationmanager_chime_short_off";
    public static final String CHIME_SHORT_ON = "tslocationmanager_chime_short_on";
    public static final String CLICK_TAP_DONE = "tslocationmanager_click_tap_done_checkbox5_full_vol";
    public static final String CLOCK_TICK = "tslocationmanager_click_clock_tick";
    public static final String CLOCK_TOCK = "tslocationmanager_click_clock_tock";
    public static final String CLOSE = "tslocationmanager_tiny_retry_failure1";
    public static final String DIGI_WARN = "tslocationmanager_digi_warn";
    public static final String DOT_RETRY = "tslocationmanager_dot_retry";
    public static final String DOT_START = "tslocationmanager_dot_startaction1";
    public static final String DOT_STOP = "tslocationmanager_dot_stopaction2";
    public static final String DOT_SUCCESS = "tslocationmanager_dot_success";
    public static final String ERROR = "tslocationmanager_music_timpani_error_01";
    public static final String GEOFENCE_DWELL = "tslocationmanager_beep_trip_up_echo";
    public static final String GEOFENCE_ENTER = "tslocationmanager_beep_trip_up_dry";
    public static final String GEOFENCE_EXIT = "tslocationmanager_beep_trip_dry";
    public static final String HEARTBEAT = "tslocationmanager_peep_note1";
    public static final String LOCATION_ERROR = "tslocationmanager_digi_warn";
    public static final String LOCATION_RECORDED = "tslocationmanager_ooooiii3_full_vol";
    public static final String LOCATION_SAMPLE = "tslocationmanager_click_tap_done_checkbox5_full_vol";
    public static final String MARIMBA_DROP = "tslocationmanager_marimba_drop";
    public static final String MOTIONCHANGE_FALSE = "tslocationmanager_marimba_drop";
    public static final String MOTIONCHANGE_TRUE = "tslocationmanager_chime_short_chord_up";
    public static final String MUSIC_TIMPANI_ERROR = "tslocationmanager_music_timpani_error_01";
    public static final String OOOOIII = "tslocationmanager_ooooiii3_full_vol";
    public static final String OPEN = "tslocationmanager_tiny_retry_failure3";
    public static final String PEEP_NOTE = "tslocationmanager_peep_note1";
    public static final String PIPE_ALERT = "tslocationmanager_music_pipe_chord";
    public static final String PIPE_CLOSE = "tslocationmanager_music_pipe_cancel";
    public static final String PIPE_CONFIRM = "tslocationmanager_music_pipe_confirm";
    public static final String PIPE_OPEN = "tslocationmanager_music_pipe_chord_nice";
    public static final String POLYGON_ENCLOSING_CIRCLE_ENTER = "tslocationmanager_chime_short_on";
    public static final String POLYGON_ENCLOSING_CIRCLE_EXIT = "tslocationmanager_chime_short_off";
    public static final String POP = "tslocationmanager_pop_notification4";
    public static final String POP_CLOSE = "tslocationmanager_pop_notification2";
    public static final String POP_OPEN = "tslocationmanager_pop_notification1";
    public static final String STATIONARY_GEOFENCE_EXIT = "tslocationmanager_zap_fast";
    public static final String STOP_TIMER_OFF = "tslocationmanager_bell_ding_pop";
    public static final String STOP_TIMER_ON = "tslocationmanager_chime_bell_confirm";
    public static final String TINY_RETRY_FAILURE1 = "tslocationmanager_tiny_retry_failure1";
    public static final String TINY_RETRY_FAILURE3 = "tslocationmanager_tiny_retry_failure3";
    public static final String WARNING = "tslocationmanager_digi_warn";
    public static final String WHOO_SEND_SHARE = "tslocationmanager_whoo_send_share1";
    public static final String ZAP_FAST = "tslocationmanager_zap_fast";
    
    private static TSMediaPlayer instance = null;
    private android.media.MediaPlayer mediaPlayer;
    private final AtomicBoolean isEnabled = new AtomicBoolean(false);
    private final AtomicBoolean isPlaying = new AtomicBoolean(false);
    private final List<Integer> soundResources = new ArrayList<>();
    
    private TSMediaPlayer() {
    }
    
    private static synchronized TSMediaPlayer getInstanceInternal() {
        if (instance == null) {
            instance = new TSMediaPlayer();
        }
        return instance;
    }
    
    public static TSMediaPlayer getInstance() {
        if (instance == null) {
            instance = getInstanceInternal();
        }
        return instance;
    }
    
    /**
     * Initialize media player
     */
    public void init(Context context) {
        Config config = Config.getInstance(context);
        isEnabled.set(config.debug);
        
        // TODO: Listen to config changes
    }
    
    /**
     * Play sound (debug mode only)
     */
    public void debug(Context context, String soundName) {
        if (isEnabled.get()) {
            play(context, soundName);
        }
    }
    
    /**
     * Play sound
     */
    public void play(Context context, String soundName) {
        if (isPlaying.get()) {
            return; // Already playing
        }
        
        String upperCase = soundName.toUpperCase();
        
        // Get resource ID from sound name
        // TODO: Implement resource ID mapping
        // For now, just log
        LogHelper.d("MediaPlayer", "Playing sound: " + soundName);
        
        // TODO: Implement actual sound playback
        // int resourceId = context.getResources().getIdentifier(soundName, "raw", context.getPackageName());
        // if (resourceId != 0) {
        //     try {
        //         mediaPlayer = android.media.MediaPlayer.create(context, resourceId);
        //         if (mediaPlayer != null) {
        //             mediaPlayer.setOnCompletionListener(mp -> {
        //                 isPlaying.set(false);
        //                 mp.release();
        //             });
        //             isPlaying.set(true);
        //             mediaPlayer.start();
        //         }
        //     } catch (Exception e) {
        //         LogHelper.e("MediaPlayer", "Error playing sound: " + e.getMessage(), e);
        //         isPlaying.set(false);
        //     }
        // }
    }
    
    /**
     * Stop playing
     */
    public void stop() {
        if (mediaPlayer != null && isPlaying.get()) {
            try {
                mediaPlayer.stop();
                mediaPlayer.release();
                mediaPlayer = null;
                isPlaying.set(false);
            } catch (Exception e) {
                LogHelper.e("MediaPlayer", "Error stopping sound: " + e.getMessage(), e);
            }
        }
    }
}

