import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
js=(root/'Companions/SpeedyAds/Acceleration.js').read_text()
header='// Generated from Acceleration.js; do not edit.\nstatic NSString *MYBAccelerationScript(BOOL active){return [@'+json.dumps(js)+' stringByReplacingOccurrencesOfString:@"__MYB_INITIAL_ENABLED__" withString:active?@"true":@"false"]; }\n'
(root/'Companions/SpeedyAds/Acceleration.generated.h').write_text(header)
