from pathlib import Path
import base64,hashlib,json,re
root=Path(__file__).resolve().parents[1]
import subprocess,sys
subprocess.check_call([sys.executable,str(root/'tools/generate-design-tokens.py')])
tokens=(root/'BlockedServer/tokens.generated.css').read_text();glass=(root/'BlockedServer/glass.css').read_text()
def build(name):
    page=(root/('BlockedServer/'+name)).read_text().replace('/*MYB_TOKENS*/',tokens).replace('/*MYB_GLASS*/',glass)
    scripts=re.findall(r'<script>(.*?)</script>',page,re.S)
    assert len(scripts)==1,name
    return page,base64.b64encode(hashlib.sha256(scripts[0].encode()).digest()).decode()
page,script_hash=build('BlockedPage.html');status_page,status_hash=build('StatusPage.html');popup_page,popup_hash=build('PopupTestPage.html')
target_page=(root/'BlockedServer/PopupTarget.html').read_text().replace('/*MYB_TOKENS*/',tokens)
brand=base64.b64encode((root/'Preferences/Resources/MYBIcon.png').read_bytes()).decode()
header='static NSString *const MYBBrandBase64=@'+json.dumps(brand)+';\n'
header+='static NSString *const MYBBlockedPage=@'+json.dumps(page,ensure_ascii=False)+';\n'
header+='static NSString *const MYBPageScriptHash=@'+json.dumps(script_hash)+';\n'
header+='static NSString *const MYBStatusPage=@'+json.dumps(status_page,ensure_ascii=False)+';\n'
header+='static NSString *const MYBStatusScriptHash=@'+json.dumps(status_hash)+';\n'
header+='static NSString *const MYBPopupTestPage=@'+json.dumps(popup_page,ensure_ascii=False)+';\n'
header+='static NSString *const MYBPopupScriptHash=@'+json.dumps(popup_hash)+';\n'
header+='static NSString *const MYBPopupTargetPage=@'+json.dumps(target_page,ensure_ascii=False)+';\n'
(root/'BlockedServer/Brand.h').write_text(header)
