import com.zaleltech.jot_it.PinKeyDerivation;
import java.security.MessageDigest;
import java.util.Base64;

public final class PinKeyDerivationTest {
    public static void main(String[] args) throws Exception {
        byte[] salt = new byte[16];
        for (int i = 0; i < salt.length; i++) salt[i] = (byte) i;
        byte[] expected = Base64.getDecoder().decode("rDEMyFJ8bDpOINKiJG69d9WXZtrhxf6EPWXs9qfiDGU=");
        if (!MessageDigest.isEqual(expected, PinKeyDerivation.derive("2468", salt))) {
            throw new AssertionError("Native PBKDF2 differs from the independent compatibility vector.");
        }
        if (MessageDigest.isEqual(expected, PinKeyDerivation.derive("8642", salt))) {
            throw new AssertionError("Incorrect PIN produced the expected key.");
        }
        try {
            PinKeyDerivation.derive("123", salt);
            throw new AssertionError("Invalid PIN was accepted.");
        } catch (IllegalArgumentException expectedError) { }
        try {
            PinKeyDerivation.derive("2468", new byte[2]);
            throw new AssertionError("Invalid salt was accepted.");
        } catch (IllegalArgumentException expectedError) { }
        System.out.println("Native PIN compatibility and rejection checks passed.");
    }
}
