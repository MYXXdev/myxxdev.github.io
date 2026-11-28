#pragma once
// MYbloXX® Private Calls, incoming-call actions. Runs only inside the incoming-call app (com.apple.InCallService). It uses the phone's own TelephonyUtilities
// client API, one call object at a time. It never touches CommCenter, carrier settings, SIM or baseband services, call delivery, outgoing calls, emergency
// calls, FaceTime or other apps' calls, and it does nothing at all unless Private Calls is switched on and the call's number is on the list.
void PCCallInstall(void);
