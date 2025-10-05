// Simple runtime flag controlled at startup to indicate whether Firebase initialized
// When Firebase fails to initialize (e.g. running on web without firebase_options.dart)
// this flag is set to false so other screens can avoid calling Firebase APIs.
library;

bool firebaseEnabled = true;
