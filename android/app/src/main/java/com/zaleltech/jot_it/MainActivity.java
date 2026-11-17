package com.zaleltech.jot_it;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;
import java.security.GeneralSecurityException;
import java.security.NoSuchAlgorithmException;

public class MainActivity extends FlutterFragmentActivity {
    private MethodChannel pinChannel;

    @Override
    public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        BinaryMessenger messenger = engine.getDartExecutor().getBinaryMessenger();
        // Derive on a serial platform worker, never the Android UI thread.
        pinChannel = new MethodChannel(messenger, "jotit/pin_hash",
                StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue());
        pinChannel.setMethodCallHandler((call, result) -> {
            if (!call.method.equals("pbkdf2")) {
                result.notImplemented();
                return;
            }
            try {
                String pin = call.argument("pin");
                byte[] salt = call.argument("salt");
                result.success(PinKeyDerivation.derive(pin, salt));
            } catch (NoSuchAlgorithmException error) {
                result.error("PIN_HASH_UNAVAILABLE", "Native PIN hashing is unavailable.", null);
            } catch (GeneralSecurityException | IllegalArgumentException | ClassCastException error) {
                // Never return the PIN, salt, hash, arguments or raw exception.
                result.error("PIN_HASH_FAILED", "Could not verify PIN.", null);
            }
        });
    }

    @Override
    public void cleanUpFlutterEngine(FlutterEngine engine) {
        if (pinChannel != null) {
            pinChannel.setMethodCallHandler(null);
            pinChannel = null;
        }
        super.cleanUpFlutterEngine(engine);
    }
}
