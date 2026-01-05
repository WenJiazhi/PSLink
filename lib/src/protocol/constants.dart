// PS Remote Play Protocol Constants
// Based on Chiaki open source implementation

class PSConstants {
  // Discovery Ports
  static const int discoveryPortPS4 = 987;
  static const int discoveryPortPS5 = 9302;
  static const int discoveryPortLocalMin = 9303;
  static const int discoveryPortLocalMax = 9319;

  // Session Port
  static const int sessionPort = 9295;
  static const int registrationPort = 9295;

  // Registration Endpoints
  static const String registrationEndpointPS4 = '/sce/rp/regist';
  static const String registrationEndpointPS5 = '/sie/ps5/rp/sess/rgst';

  // Protocol Versions
  static const String protocolVersionPS4 = '00020020';
  static const String protocolVersionPS5 = '00030010';

  // Discovery Commands
  static const String discoveryCmdSearch = 'SRCH';
  static const String discoveryCmdWakeup = 'WAKEUP';

  // Key Sizes
  static const int ecdhSecretSize = 32;
  static const int handshakeKeySize = 0x10;
  static const int sessionAuthSize = 0x10;
  static const int psnAccountIdSize = 8;
  static const int rpCryptKeySize = 0x10;

  // Takion Protocol
  static const int takionV9AvHeaderSizeVideo = 0x17;
  static const int takionV12AvHeaderSizeAudio = 0x13;

  // Controller Button Masks
  static const int buttonCross = 1 << 0;
  static const int buttonMoon = 1 << 1; // Circle
  static const int buttonBox = 1 << 2; // Square
  static const int buttonPyramid = 1 << 3; // Triangle
  static const int buttonDpadLeft = 1 << 4;
  static const int buttonDpadRight = 1 << 5;
  static const int buttonDpadUp = 1 << 6;
  static const int buttonDpadDown = 1 << 7;
  static const int buttonL1 = 1 << 8;
  static const int buttonR1 = 1 << 9;
  static const int buttonL3 = 1 << 10;
  static const int buttonR3 = 1 << 11;
  static const int buttonOptions = 1 << 12;
  static const int buttonShare = 1 << 13;
  static const int buttonTouchpad = 1 << 14;
  static const int buttonPS = 1 << 15;
  static const int analogButtonL2 = 1 << 16;
  static const int analogButtonR2 = 1 << 17;

  // Touchpad
  static const int maxTouches = 2;

  // Host States
  static const String hostStateReady = 'READY';
  static const String hostStateStandby = 'STANDBY';

  // Target Types
  static const int targetPS4_8 = 800;
  static const int targetPS4_9 = 900;
  static const int targetPS4_10 = 1000;
  static const int targetPS5_1 = 1100;

  // Video Codecs
  static const int codecH264 = 0;
  static const int codecHEVC = 1;

  // Discovery Packet Magic
  static const List<int> discoveryMagic = [0x44, 0x44, 0x50, 0x4C]; // DDPL
}
