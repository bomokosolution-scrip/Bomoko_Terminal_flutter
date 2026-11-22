"""Patch the generated android/ folder: app name, INTERNET permission, link queries."""
import re, sys, pathlib

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "android")
mf = root / "app/src/main/AndroidManifest.xml"
s = mf.read_text(encoding="utf-8")

s = re.sub(r'android:label="[^"]*"', 'android:label="Bomoko Terminal"', s, count=1)

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

if "<queries>" not in s:
    q = """<queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
    </queries>
    """
    s = s.replace("<application", q + "<application", 1)

mf.write_text(s, encoding="utf-8")
print("Manifest patched:", mf)
