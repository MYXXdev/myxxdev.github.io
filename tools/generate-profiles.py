#!/usr/bin/env python3
"""Generates the six Legacy Mode profiles. Each is a standalone proxy profile (com.apple.proxy.http.global, automatic configuration)
whose PAC address is the PUBLISHED standalone PAC on jsDelivr, never localhost: it works with no MYbloXX® service running.
Identifiers and UUIDs are the historical ones recovered from the project's published profiles (MYXXdev/myxxdev.github.io, MYbloXX/*.mobileconfig),
so installing one replaces an older MYbloXX® profile in place. The historical profiles were CMS-signed with the author's developer certificate;
these are unsigned (iOS says so when you install them), which cannot be fixed without that certificate."""
from pathlib import Path
import plistlib,uuid
root=Path(__file__).resolve().parents[1]/'layout/usr/share/mybloxx/profiles';root.mkdir(parents=True,exist_ok=True)
# name -> (standalone PAC file, historical top-level UUID, historical proxy payload identifier suffix, historical proxy payload UUID)
profiles={
 'Default':('Default','FD9913A0-D24B-4C09-93B0-D3F4066D8E79','F0A95878-A788-4CD4-AC31-42EDDB342D63','7050428D-BAFC-46BD-9762-8C63D8A6330C'),
 'allowY':('allowY','257827F1-D835-45BD-85E2-F25056B81C6A','5608408B-C7B0-481B-AC3D-5F53CA96909F','AA900903-FE1C-4D59-8F8F-DE047CC42373'),
 'noApple':('blockApple','9DB9ED54-D401-4CE1-880D-F669E6155EBA','FDD30EB4-0D97-4301-824F-075331C66FEC','9950291A-8969-4A01-9106-ED4952BB90D3'),
 'noSocials':('blockSocials','FFB0B45E-9845-4AC6-8965-04DD10FF4FC7','FDD30EB4-0D97-4301-824F-075331C66FEC','94C3BD08-3037-4F07-A6B4-4C042DE97FAD'),
 'noXXX':('blockXXX','CE2BD79D-0696-4922-A872-AD78BFBB60C4','FDD30EB4-0D97-4301-824F-075331C66FEC','D71247AC-9E35-48BF-80AB-B187BB79717F'),
}
ns=uuid.UUID('9e123947-571c-409f-8d5e-afac53c10ef3')
profiles['blockAdSense']=('blockAdSense',str(uuid.uuid5(ns,'profile-blockAdSense')).upper(),'FDD30EB4-0D97-4301-824F-075331C66FEC',str(uuid.uuid5(ns,'proxy-blockAdSense')).upper()) # no historical profile existed
for name,(pac,top,proxy_id,proxy_uuid) in profiles.items():
    payload={'PayloadType':'com.apple.proxy.http.global','PayloadVersion':1,'PayloadIdentifier':'com.apple.proxy.http.global.'+proxy_id,'PayloadUUID':proxy_uuid,
      'PayloadDisplayName':'Global HTTP Proxy','ProxyType':'Auto','ProxyPACURL':f'https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/{pac}.pac','ProxyCaptiveLoginAllowed':True,'ProxyPACFallbackAllowed':True}
    profile={'PayloadType':'Configuration','PayloadVersion':1,'PayloadIdentifier':'net.myxxdev.mybloxx','PayloadUUID':top,'PayloadDisplayName':'MYbloXX® ('+name+')',
      'PayloadOrganization':'MYXXdev™','PayloadDescription':'Legacy Mode: points iOS at the published '+name+' PAC. It works without MYbloXX® running and is separate from native MYbloXX® protection. Remove it in Settings > General > VPN & Device Management to return to native protection.',
      'PayloadScope':'System','PayloadRemovalDisallowed':False,'PayloadContent':[payload]}
    (root/(name+'.mobileconfig')).write_bytes(plistlib.dumps(profile,sort_keys=False))
print('Generated',len(profiles),'legacy profiles with remote PAC addresses')
