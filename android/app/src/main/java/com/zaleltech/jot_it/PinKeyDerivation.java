package com.zaleltech.jot_it;

import java.security.GeneralSecurityException;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Same PBKDF2-HMAC-SHA256 parameters as existing saved PIN records. */
public final class PinKeyDerivation {
    private PinKeyDerivation() {}

    public static byte[] derive(String pin, byte[] salt) throws GeneralSecurityException {
        if (pin == null || !pin.matches("[0-9]{4}") || salt == null || salt.length != 16) {
            throw new IllegalArgumentException("Invalid PIN derivation input.");
        }
        PBEKeySpec spec = new PBEKeySpec(pin.toCharArray(), salt, 600000, 256);
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                    .generateSecret(spec).getEncoded();
        } finally {
            spec.clearPassword();
        }
    }
}
