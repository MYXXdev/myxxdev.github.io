#pragma once
#import <Foundation/Foundation.h>
// Legacy Mode profiles: standalone proxy profiles that point iOS at a PAC hosted online, so they work without any MYbloXX service
// on the iPhone. The six names are the Settings labels; each maps to one standalone PAC (the generated legacy output of the canonical
// rules) published with the rules at MYXXdev/myxxdev.github.io, MYbloXX/<PAC>.pac, and served through jsDelivr.
static inline NSArray *MYBLegacyProfileNames(void){return @[@"Default",@"allowY",@"blockAdSense",@"noApple",@"noSocials",@"noXXX"];}
static inline NSString *MYBLegacyProfilePAC(NSString *profile){return @{@"Default":@"Default",@"allowY":@"allowY",@"blockAdSense":@"blockAdSense",@"noApple":@"blockApple",@"noSocials":@"blockSocials",@"noXXX":@"blockXXX"}[profile];}
// The profile file as the project's published profiles name it (the historical alias names kept for older installs).
static inline NSString *MYBLegacyProfilePublishedName(NSString *profile){return @{@"Default":@"MYbloXX",@"allowY":@"MYbloXXallowY",@"noApple":@"MYbloXXnoApple",@"noSocials":@"MYbloXXnoSocials",@"noXXX":@"MYbloXXnoXXX"}[profile];}
static inline NSString *MYBLegacyPACURL(NSString *profile){NSString *pac=MYBLegacyProfilePAC(profile);return pac?[NSString stringWithFormat:@"https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/%@.pac",pac]:nil;}
// Link to the published profile file, for the Copy Link fallback. nil for a profile that has no published file.
static inline NSString *MYBLegacyProfileLink(NSString *profile){NSString *n=MYBLegacyProfilePublishedName(profile);return n?[NSString stringWithFormat:@"https://myxxdev.github.io/MYbloXX/%@.mobileconfig",n]:nil;}
// A top-level profile identifier every MYbloXX proxy profile has used since the first release. A new profile with the same identifier
// replaces an older one in place, so installing a second MYbloXX profile does not leave two competing global proxies.
#define MYB_LEGACY_PROFILE_ID @"net.myxxdev.mybloxx"
// Identifiers of the local-PAC profiles that shipped in earlier builds of this package (recognised for migration only).
static inline NSArray *MYBLegacyProfileKnownIdentifiers(void){return @[@"net.myxxdev.mybloxx",@"net.myxxdev.mybloxx.legacy"];}
// PayloadUUIDs of every MYbloXX proxy profile the project has published (MYXXdev/myxxdev.github.io, MYbloXX/*.mobileconfig, whole history:
// each file appears once, with an http:// jsDelivr PAC address and the organisation "MYXXdev\u2122"). All of them share the identifier
// net.myxxdev.mybloxx, which is why the identifier alone is not enough to tell the profiles apart.
static inline NSArray *MYBLegacyProfileKnownUUIDs(void){return @[@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79",@"73857AE2-F370-4581-9143-8B725816008B",@"257827F1-D835-45BD-85E2-F25056B81C6A",@"9DB9ED54-D401-4CE1-880D-F669E6155EBA",@"FFB0B45E-9845-4AC6-8965-04DD10FF4FC7",@"CE2BD79D-0696-4922-A872-AD78BFBB60C4"];}

// Bundled DNS profiles (usr/share/mybloxx/dns/<Name>.mobileconfig), served by the local PAC service like the legacy profiles.
// The profile is hosted on this iPhone; the DNS provider it points to is external.
static inline NSArray *MYBDNSProfileNames(void){return @[@"Cloudflare",@"Google",@"Quad9"];}
