package com.pierrejoshua.digivi;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;
import android.os.Looper;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

/**
 * Keeps the pet's senses running while the game is not on screen. It only counts things
 * (steps, shakes, loud noises, visited places); the game reads and clears the counts.
 */
public class DigiviService extends Service implements SensorEventListener {
    static final String PREFS = "digivi_pending";
    private SensorManager sensors;
    private LocationManager locations;
    private float lastCounter = -1f;
    private double ema = 9.8;
    private final ArrayList<Long> spikes = new ArrayList<>();
    private long lastShake = 0;
    private volatile boolean micRunning = false;
    private Thread micThread;

    private final LocationListener locationListener = new LocationListener() {
        @Override public void onLocationChanged(Location l) {
            if (l.hasAccuracy() && l.getAccuracy() > 150f) return;
            String key = Math.round(l.getLatitude() * 1000.0) + "," + Math.round(l.getLongitude() * 1000.0);
            synchronized (PREFS) {
                SharedPreferences p = prefs(DigiviService.this);
                Set<String> keys = new HashSet<>(p.getStringSet("keys", new HashSet<String>()));
                keys.add(key);
                p.edit().putStringSet("keys", keys).putString("fix", l.getLatitude() + "," + l.getLongitude() + "," + (l.hasAccuracy() ? l.getAccuracy() : 9999f)).apply();
            }
        }
        @Override public void onStatusChanged(String p, int s, Bundle e) {}
        @Override public void onProviderEnabled(String p) {}
        @Override public void onProviderDisabled(String p) {}
    };

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences(PREFS, MODE_PRIVATE); }

    static void add(Context c, String key, int n) {
        synchronized (PREFS) {
            SharedPreferences p = prefs(c);
            p.edit().putInt(key, p.getInt(key, 0) + n).apply();
        }
    }

    static boolean granted(Context c, String perm) {
        return c.checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED;
    }

    @Override public IBinder onBind(Intent i) { return null; }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        boolean loc = granted(this, "android.permission.ACCESS_FINE_LOCATION");
        boolean mic = granted(this, "android.permission.RECORD_AUDIO");
        boolean act = granted(this, "android.permission.ACTIVITY_RECOGNITION");
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(new NotificationChannel("digivi", "Digivi", NotificationManager.IMPORTANCE_LOW));
        }
        Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent pi = PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder nb = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, "digivi") : new Notification.Builder(this);
        Notification n = nb.setContentTitle("Digivi").setContentText("Watching over your pet")
                .setSmallIcon(android.R.drawable.ic_menu_compass).setContentIntent(pi).setOngoing(true).build();
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                int types = 0;
                if (loc) types |= ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION;
                if (mic) types |= ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE;
                if (Build.VERSION.SDK_INT >= 34 && act) types |= ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH;
                if (types == 0 && Build.VERSION.SDK_INT >= 34) types = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE;
                if (types == 0) startForeground(1, n); else startForeground(1, n, types);
            } else {
                startForeground(1, n);
            }
        } catch (Throwable t) {
            stopSelf();
            return START_NOT_STICKY;
        }
        startSensors(loc, mic, act);
        return START_STICKY;
    }

    private void startSensors(boolean loc, boolean mic, boolean act) {
        sensors = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        sensors.unregisterListener(this);
        lastCounter = prefs(this).getFloat("lastCounter", -1f);
        Sensor counter = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
        if (counter != null && act) sensors.registerListener(this, counter, SensorManager.SENSOR_DELAY_NORMAL);
        Sensor accel = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (accel != null) sensors.registerListener(this, accel, SensorManager.SENSOR_DELAY_GAME);
        if (loc) {
            try {
                locations = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
                locations.removeUpdates(locationListener);
                for (String provider : new String[] {"gps", "network", "fused"}) {
                    if (locations.getAllProviders().contains(provider)) {
                        locations.requestLocationUpdates(provider, 15000L, 0f, locationListener, Looper.getMainLooper());
                    }
                }
            } catch (Throwable t) { /* no location */ }
        }
        if (mic && !micRunning) startMic();
    }

    private void startMic() {
        micRunning = true;
        micThread = new Thread(new MicTask(this), "digivi-mic");
        micThread.start();
    }

    private static class MicTask implements Runnable {
        private final DigiviService svc;
        MicTask(DigiviService s) { svc = s; }

        @Override public void run() {
            AudioRecord rec = null;
            try {
                int rate = 16000;
                int buf = Math.max(AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT), 3200);
                rec = new AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, buf);
                rec.startRecording();
                loop(rec);
            } catch (Throwable t) {
                // mic unavailable
            }
            release(rec);
            svc.micRunning = false;
        }

        private void loop(AudioRecord rec) {
            short[] data = new short[1600];
            double base = 0.02;
            long lastLoud = 0;
            while (svc.micRunning) {
                int got = rec.read(data, 0, data.length);
                if (got <= 0) continue;
                double s = 0;
                for (int i = 0; i < got; i++) {
                    double v = data[i] / 32768.0;
                    s += v * v;
                }
                double lvl = Math.sqrt(s / got);
                base += (Math.min(lvl, 0.1) - base) * 0.01;
                long now = System.currentTimeMillis();
                if (lvl > 0.45 && lvl > base * 4 && now - lastLoud > 1500) {
                    lastLoud = now;
                    add(svc, "louds", 1);
                }
            }
        }

        private void release(AudioRecord rec) {
            if (rec == null) return;
            try { rec.stop(); } catch (Throwable t) { }
            rec.release();
        }
    }

    @Override public void onSensorChanged(SensorEvent e) {
        if (e.sensor.getType() == Sensor.TYPE_STEP_COUNTER) {
            float v = e.values[0];
            float delta = 0;
            if (lastCounter >= 0) delta = v >= lastCounter ? v - lastCounter : v;
            lastCounter = v;
            SharedPreferences p = prefs(this);
            p.edit().putFloat("lastCounter", v).apply();
            if (delta > 0 && delta < 20000) add(this, "steps", (int) delta);
        } else if (e.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
            double mag = Math.sqrt(e.values[0] * e.values[0] + e.values[1] * e.values[1] + e.values[2] * e.values[2]);
            ema += (mag - ema) * 0.05;
            double d = mag - ema;
            long now = System.currentTimeMillis();
            if (Math.abs(d) > 16) {
                spikes.add(now);
                while (!spikes.isEmpty() && now - spikes.get(0) > 900) spikes.remove(0);
                if (spikes.size() >= 3 && now - lastShake > 1500) {
                    lastShake = now;
                    spikes.clear();
                    add(this, "shakes", 1);
                }
            }
        }
    }

    @Override public void onAccuracyChanged(Sensor s, int a) {}

    @Override public void onDestroy() {
        micRunning = false;
        if (sensors != null) sensors.unregisterListener(this);
        if (locations != null) locations.removeUpdates(locationListener);
        super.onDestroy();
    }
}
