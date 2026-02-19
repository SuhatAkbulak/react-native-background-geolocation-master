package com.backgroundlocation.scheduler;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Schedule
 * Schedule
 * Schedule model - zamanlama bilgilerini tutar
 */
public class Schedule {
    
    private static final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.US);
    private static final Pattern datePattern = Pattern.compile("\\d{4}-\\d{2}-\\d{2}.*");
    private static final String TRACKING_MODE_GEOFENCE = "geofence";
    private static final String TRACKING_MODE_LOCATION = "location";
    
    private final List<Integer> days = new ArrayList<>();
    private boolean isLiteralDate = false;
    public Calendar offTime;
    public Calendar onTime;
    public int trackingMode;
    
    /**
     * Constructor - parse schedule string
     * Format: "1-5 09:00-17:00" or "1,3,5 09:00-17:00" or "2024-01-01 09:00-2024-01-02 17:00"
     */
    public Schedule(String scheduleString) {
        parseSchedule(scheduleString);
    }
    
    /**
     * Parse schedule string
     */
    private void parseSchedule(String scheduleString) {
        String[] parts = scheduleString.split(" ");
        Locale locale = Locale.US;
        
        this.onTime = Calendar.getInstance(locale);
        this.offTime = Calendar.getInstance(locale);
        
        // Parse days/dates
        if (parts[0].contains("-")) {
            // Check if it's a literal date (YYYY-MM-DD)
            if (datePattern.matcher(parts[0]).matches()) {
                this.isLiteralDate = true;
                String[] dateParts = parts[0].split("-");
                this.onTime.set(Calendar.YEAR, Integer.parseInt(dateParts[0]));
                this.onTime.set(Calendar.MONTH, Integer.parseInt(dateParts[1]) - 1);
                this.onTime.set(Calendar.DAY_OF_MONTH, Integer.parseInt(dateParts[2]));
                
                // Check if off time is also a date
                if (datePattern.matcher(parts[1]).matches()) {
                    String[] offDateParts = parts[1].split("-");
                    this.offTime.set(Calendar.YEAR, Integer.parseInt(offDateParts[0]));
                    this.offTime.set(Calendar.MONTH, Integer.parseInt(offDateParts[1]) - 1);
                    this.offTime.set(Calendar.DAY_OF_MONTH, Integer.parseInt(offDateParts[2]));
                    // Extract time from date string
                    parts[1] = dateParts[3] + "-" + offDateParts[3];
                } else {
                    this.offTime.set(Calendar.YEAR, this.onTime.get(Calendar.YEAR));
                    this.offTime.set(Calendar.MONTH, this.onTime.get(Calendar.MONTH));
                    this.offTime.set(Calendar.DAY_OF_MONTH, this.onTime.get(Calendar.DAY_OF_MONTH));
                }
            } else {
                // Day range (e.g., "1-5" for Monday-Friday)
                String[] dayRange = parts[0].split("-");
                int startDay = Integer.parseInt(dayRange[0]);
                int endDay = Integer.parseInt(dayRange[1]);
                for (int day = startDay; day <= endDay; day++) {
                    this.days.add(day);
                }
            }
        } else {
            // Comma-separated days (e.g., "1,3,5")
            String[] dayList = parts[0].split(",");
            for (String dayStr : dayList) {
                this.days.add(Integer.parseInt(dayStr.trim()));
            }
        }
        
        // Parse time range
        String[] timeRange = parts[1].split("-");
        String[] onTimeParts = timeRange[0].split(":");
        this.onTime.set(Calendar.HOUR_OF_DAY, Integer.parseInt(onTimeParts[0]));
        this.onTime.set(Calendar.MINUTE, Integer.parseInt(onTimeParts[1]));
        this.onTime.set(Calendar.SECOND, 0);
        this.onTime.set(Calendar.MILLISECOND, 0);
        
        String[] offTimeParts = timeRange[1].split(":");
        this.offTime.set(Calendar.HOUR_OF_DAY, Integer.parseInt(offTimeParts[0]));
        this.offTime.set(Calendar.MINUTE, Integer.parseInt(offTimeParts[1]));
        this.offTime.set(Calendar.SECOND, 0);
        this.offTime.set(Calendar.MILLISECOND, 0);
        
        // If literal date and off time is before on time, add one day
        if (this.isLiteralDate && this.offTime.before(this.onTime)) {
            this.offTime.add(Calendar.DAY_OF_YEAR, 1);
        }
        
        // Parse tracking mode
        if (parts.length <= 2) {
            this.trackingMode = 1; // Location tracking
        } else if (parts[2].contains(TRACKING_MODE_GEOFENCE)) {
            this.trackingMode = 0; // Geofence only
        } else {
            this.trackingMode = 1; // Location tracking
        }
    }
    
    /**
     * Check if schedule has specific day
     */
    public Boolean hasDay(int day) {
        return Boolean.valueOf(this.days.contains(Integer.valueOf(day)));
    }
    
    /**
     * Check if schedule is expired
     */
    public boolean isExpired() {
        return Calendar.getInstance(Locale.US).after(this.offTime);
    }
    
    /**
     * Check if schedule uses literal date
     */
    public boolean isLiteralDate() {
        return this.isLiteralDate;
    }
    
    /**
     * Check if schedule is next (should be triggered)
     */
    public boolean isNext(Calendar calendar) {
        if (!this.isLiteralDate) {
            make(calendar);
            if (!hasDay(calendar.get(Calendar.DAY_OF_WEEK)).booleanValue()) {
                return false;
            }
        }
        return calendar.before(this.offTime);
    }
    
    /**
     * Make schedule for specific calendar date
     */
    public void make(Calendar calendar) {
        if (!this.isLiteralDate) {
            this.onTime.set(Calendar.DAY_OF_YEAR, calendar.get(Calendar.DAY_OF_YEAR));
            this.onTime.set(Calendar.YEAR, calendar.get(Calendar.YEAR));
            this.offTime.set(Calendar.DAY_OF_YEAR, calendar.get(Calendar.DAY_OF_YEAR));
            this.offTime.set(Calendar.YEAR, calendar.get(Calendar.YEAR));
            if (this.offTime.before(this.onTime)) {
                this.offTime.add(Calendar.DAY_OF_YEAR, 1);
            }
        }
    }
    
    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("Schedule[");
        sb.append(timeFormat.format(this.onTime.getTime()));
        sb.append("-");
        sb.append(timeFormat.format(this.offTime.getTime()));
        sb.append(", Days: ");
        sb.append(this.days);
        sb.append(", trackingMode: ");
        sb.append(this.trackingMode);
        sb.append("]");
        return sb.toString();
    }
}

