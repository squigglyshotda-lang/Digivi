package com.pierrejoshua.digivi;

import android.app.Activity;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.Settings;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/** Checks a version.json on the web, downloads the new APK and hands it to Android's installer. */
public class Updater {
    public static volatile String state = "idle"; // idle, checking, info:<json>, downloading:<pct>, downloaded, error:<msg>
    static volatile boolean busy = false;

    public static String state() { return state; }

    public static int versionCode(Activity a) {
        try {
            return a.getPackageManager().getPackageInfo(a.getPackageName(), 0).versionCode;
        } catch (Throwable t) { return 0; }
    }

    public static String versionName(Activity a) {
        try {
            return a.getPackageManager().getPackageInfo(a.getPackageName(), 0).versionName;
        } catch (Throwable t) { return "?"; }
    }

    static String get(String u) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(u + (u.contains("?") ? "&" : "?") + "t=" + System.currentTimeMillis()).openConnection();
        c.setConnectTimeout(15000);
        c.setReadTimeout(20000);
        c.setUseCaches(false);
        InputStream in = c.getInputStream();
        java.io.ByteArrayOutputStream b = new java.io.ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = in.read(buf)) > 0) b.write(buf, 0, n);
        in.close();
        return b.toString("UTF-8");
    }

    public static void check(final String url) {
        if (busy) return;
        busy = true;
        state = "checking";
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    state = "info:" + get(url);
                } catch (Throwable t) {
                    state = "error:" + t.getClass().getSimpleName() + " " + t.getMessage();
                }
                busy = false;
            }
        }).start();
    }

    public static void download(final Activity a, final String url) {
        if (busy) return;
        busy = true;
        state = "downloading:0";
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    File dir = new File(a.getFilesDir(), "updates");
                    dir.mkdirs();
                    File f = new File(dir, "update.apk");
                    File tmp = new File(dir, "update.part");
                    HttpURLConnection c = (HttpURLConnection) new URL(url + (url.contains("?") ? "&" : "?") + "t=" + System.currentTimeMillis()).openConnection();
                    c.setConnectTimeout(15000);
                    c.setReadTimeout(30000);
                    c.setUseCaches(false);
                    long total = c.getContentLengthLong();
                    InputStream in = c.getInputStream();
                    FileOutputStream out = new FileOutputStream(tmp);
                    byte[] buf = new byte[32768];
                    long got = 0;
                    int n, last = -1;
                    while ((n = in.read(buf)) > 0) {
                        out.write(buf, 0, n);
                        got += n;
                        int pct = total > 0 ? (int) (got * 100 / total) : 0;
                        if (pct != last) { last = pct; state = "downloading:" + pct; }
                    }
                    out.close();
                    in.close();
                    if (total > 0 && got != total) throw new Exception("incomplete download");
                    if (f.exists()) f.delete();
                    if (!tmp.renameTo(f)) throw new Exception("could not save file");
                    state = "downloaded";
                } catch (Throwable t) {
                    state = "error:" + t.getClass().getSimpleName() + " " + t.getMessage();
                }
                busy = false;
            }
        }).start();
    }

    /** Returns "ok", or "permission" if the user must first allow installs from Digivi. */
    public static String install(final Activity a) {
        try {
            if (android.os.Build.VERSION.SDK_INT >= 26 && !a.getPackageManager().canRequestPackageInstalls()) {
                Intent s = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + a.getPackageName()));
                s.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                a.startActivity(s);
                return "permission";
            }
            Uri u = Uri.parse("content://" + a.getPackageName() + ".apk/update.apk");
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setDataAndType(u, "application/vnd.android.package-archive");
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            a.startActivity(i);
            return "ok";
        } catch (Throwable t) {
            return "error:" + t;
        }
    }

    /** Serves the downloaded APK to the system installer. */
    public static class ApkProvider extends ContentProvider {
        @Override public boolean onCreate() { return true; }
        @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws java.io.FileNotFoundException {
            File f = new File(new File(getContext().getFilesDir(), "updates"), "update.apk");
            return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY);
        }
        @Override public Cursor query(Uri u, String[] p, String s, String[] a, String o) {
            File f = new File(new File(getContext().getFilesDir(), "updates"), "update.apk");
            android.database.MatrixCursor c = new android.database.MatrixCursor(new String[]{"_display_name", "_size"});
            c.addRow(new Object[]{"update.apk", f.length()});
            return c;
        }
        @Override public String getType(Uri u) { return "application/vnd.android.package-archive"; }
        @Override public Uri insert(Uri u, ContentValues v) { return null; }
        @Override public int delete(Uri u, String s, String[] a) { return 0; }
        @Override public int update(Uri u, ContentValues v, String s, String[] a) { return 0; }
    }
}
