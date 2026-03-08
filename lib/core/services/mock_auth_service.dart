class MockAuthService {
  Future<Map<String, dynamic>> login(String email, String pin) async {
    await Future.delayed(const Duration(seconds: 2));

    if (email == "busofficer@test.com" && pin == "123456") {
      return {
        "token": "fake_jwt_token_123",
        "user": {
          "id": "001",
          "email": email,
          "firstname": "Harper",
          "surname": "Ethan",
          "image": "https://i.pravatar.cc/150?img=3",
          "role": "bus_officer",
          "permissions": [
            "bus_access",
            "bus_drop_off",
          ],
          "phoneNumber": "08012345678",
          "estate": "Sunrise Estate",
          "houseAddress": "123 Roseville Estate, Lagos"
        }
      };
    }

    if (email == "gateofficer@test.com" && pin == "123456") {
      return {
        "token": "fake_jwt_token_456",
        "user": {
          "id": "002",
          "email": email,
          "firstname": "Oliver",
          "surname": "Jacobs",
          "image": "https://i.pravatar.cc/150?img=7",
          "role": "gate_officer",
          "permissions": [
            "drop_off",
            "pick_up",
          ],
          "phoneNumber": "08098765432",
          "estate": "Sunset Estate",
          "houseAddress": "456 Honeysuckle Villa, Opposite Grand Capital Park, Lagos"
        }
      };
    }

    else {
      throw Exception("Invalid credentials");
    }
  }
}
