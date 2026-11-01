package com.pierrejoshua.digivi;

import android.app.Activity;
import android.graphics.Bitmap;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.media.FaceDetector;
import android.os.Bundle;
import android.os.Looper;

/** Small helpers the Godot game calls through JavaClassWrapper: location and face detection. */
public class Native {
    private static volatile String lastFix = "";
    private static volatile String status = "idle";
    private static LocationManager manager;
    private static final LocationListener listener = new LocationListener() {
        @Override public void onLocationChanged(Location l) {
            lastFix = l.getLatitude() + "," + l.getLongitude() + "," + (l.hasAccuracy() ? l.getAccuracy() : 9999f);
        }
        @Override public void onStatusChanged(String p, int s, Bundle e) {}
        @Override public void onProviderEnabled(String p) {}
        @Override public void onProviderDisabled(String p) {}
    };

    /** Starts listening for location. Returns "ok", "denied" or "error: ...". */
    public static String startLocation(Activity activity) {
        try {
            manager = (LocationManager) activity.getSystemService("location");
            if (manager == null) return "error: no location service";
            boolean any = false;
            for (String provider : new String[] {"gps", "network", "fused"}) {
                try {
                    if (manager.getAllProviders().contains(provider)) {
                        manager.requestLocationUpdates(provider, 15000L, 0f, listener, Looper.getMainLooper());
                        Location last = manager.getLastKnownLocation(provider);
                        if (last != null && lastFix.isEmpty()) listener.onLocationChanged(last);
                        any = true;
                    }
                } catch (SecurityException se) {
                    return "denied";
                }
            }
            status = any ? "ok" : "error: no providers";
            return status;
        } catch (Throwable t) {
            return "error: " + t;
        }
    }

    private static volatile float luxValue = -1f;
    private static boolean lightStarted = false;

    /** Starts the ambient light sensor (no permission needed). */
    public static void startLight(Activity activity) {
        if (lightStarted) return;
        try {
            android.hardware.SensorManager sm = (android.hardware.SensorManager) activity.getSystemService("sensor");
            android.hardware.Sensor s = sm.getDefaultSensor(android.hardware.Sensor.TYPE_LIGHT);
            if (s == null) return;
            sm.registerListener(new android.hardware.SensorEventListener() {
                @Override public void onSensorChanged(android.hardware.SensorEvent e) { luxValue = e.values[0]; }
                @Override public void onAccuracyChanged(android.hardware.Sensor sensor, int a) {}
            }, s, android.hardware.SensorManager.SENSOR_DELAY_NORMAL);
            lightStarted = true;
        } catch (Throwable t) { }
    }

    /** Latest light level in lux, or -1 if unknown. */
    public static float lux() { return luxValue; }

    /** "percent,charging" e.g. "80,1", or "" if unknown. */
    public static String power(Activity activity) {
        try {
            android.content.Intent i = activity.registerReceiver(null, new android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED));
            if (i == null) return "";
            int level = i.getIntExtra("level", -1), scale = i.getIntExtra("scale", 100), plugged = i.getIntExtra("plugged", 0);
            return (level * 100 / Math.max(1, scale)) + "," + (plugged != 0 ? 1 : 0);
        } catch (Throwable t) { return ""; }
    }

    /** "lat,lon,accuracy" or "" if there is no fix yet. */
    public static String lastFix() { return lastFix; }

    /** Starts (or refreshes) the background service. Returns "ok" or "error: ...". */
    public static String startService(Activity activity) {
        try {
            android.content.Intent i = new android.content.Intent(activity, DigiviService.class);
            if (android.os.Build.VERSION.SDK_INT >= 26) activity.startForegroundService(i); else activity.startService(i);
            return "ok";
        } catch (Throwable t) {
            return "error: " + t;
        }
    }

    /** Asks Android for permissions (comma separated short names, e.g. "ACTIVITY_RECOGNITION"). */
    public static void requestPerms(final Activity activity, final String csv) {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() {
                try {
                    String[] p = csv.split(",");
                    for (int i = 0; i < p.length; i++) p[i] = "android.permission." + p[i].trim();
                    activity.requestPermissions(p, 4242);
                } catch (Throwable t) { }
            }
        });
    }

    public static boolean hasPerm(Activity activity, String name) {
        try {
            return activity.checkSelfPermission("android.permission." + name) == android.content.pm.PackageManager.PERMISSION_GRANTED;
        } catch (Throwable t) {
            return false;
        }
    }

    /** One line describing the background service, for the sensors panel. */
    public static String diag(Activity activity) {
        try {
            android.content.SharedPreferences p = activity.getSharedPreferences("digivi_pending", android.content.Context.MODE_PRIVATE);
            return "service " + (DigiviService.running ? "running" : "NOT running") + ", counter " + hasStepCounter(activity)
                    + ", last " + p.getFloat("lastCounter", -1f) + ", waiting steps " + p.getInt("steps", 0);
        } catch (Throwable t) {
            return "diag error " + t;
        }
    }

    /** True if the phone has a hardware step counter and permission to read it. */
    public static boolean hasStepCounter(Activity activity) {
        try {
            android.hardware.SensorManager sm = (android.hardware.SensorManager) activity.getSystemService("sensor");
            return sm.getDefaultSensor(android.hardware.Sensor.TYPE_STEP_COUNTER) != null
                    && activity.checkSelfPermission("android.permission.ACTIVITY_RECOGNITION") == android.content.pm.PackageManager.PERMISSION_GRANTED;
        } catch (Throwable t) {
            return false;
        }
    }

    /** Reads and clears what the service counted: "steps,shakes,louds,key1;key2". */
    public static String takePending(Activity activity) {
        try {
            synchronized ("digivi_pending") {
                android.content.SharedPreferences p = activity.getSharedPreferences("digivi_pending", android.content.Context.MODE_PRIVATE);
                java.util.Set<String> keys = p.getStringSet("keys", new java.util.HashSet<String>());
                String out = p.getInt("steps", 0) + "," + p.getInt("shakes", 0) + "," + p.getInt("louds", 0) + "," + android.text.TextUtils.join(";", keys);
                p.edit().remove("steps").remove("shakes").remove("louds").remove("keys").apply();
                return out;
            }
        } catch (Throwable t) {
            return "";
        }
    }

    /** How many faces are in an RGBA image (width must be even). */
    public static int faces(byte[] rgba, int w, int h) {
        try {
            if (w % 2 != 0) w -= 1;
            int[] px = new int[w * h];
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int i = (y * w + x) * 4;
                    px[y * w + x] = 0xFF000000 | ((rgba[i] & 0xFF) << 16) | ((rgba[i + 1] & 0xFF) << 8) | (rgba[i + 2] & 0xFF);
                }
            }
            Bitmap bmp = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565);
            bmp.setPixels(px, 0, w, 0, 0, w, h);
            FaceDetector.Face[] found = new FaceDetector.Face[2];
            int n = new FaceDetector(w, h, 2).findFaces(bmp, found);
            int count = 0;
            for (int i = 0; i < n; i++) if (found[i] != null && found[i].confidence() > 0.4f) count++;
            bmp.recycle();
            return count;
        } catch (Throwable t) {
            return -1;
        }
    }
}
