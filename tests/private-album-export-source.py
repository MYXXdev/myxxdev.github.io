#!/usr/bin/env python3
# Private Album bulk export: a ZIP of copies for the share sheet; originals untouched; temporary files cleaned up.
import sys,pathlib
R=lambda p:(pathlib.Path(__file__).resolve().parent.parent/p).read_text(encoding='utf-8')
bad=[]
def need(c,m):
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
pa=R('Companions/MYBPrivatePhotos/PrivateAlbum.m');adv=R('Preferences/MYBAdvancedController.m')
need('NSFileCoordinatorReadingForUploading' in pa and 'memcmp(head.bytes, "PK", 2)' in pa,'the system zips a staging folder and the result is checked to be a ZIP')
need('linkItemAtURL' in pa and 'copyItemAtURL:source' in pa,'items are linked into staging, or copied if linking is refused; no data is loaded into memory')
need('removeItemAtURL' not in pa.split('static void BuildZip')[1].split('@interface MYXXAlbumCell')[0].replace('[files removeItemAtURL:destination','').replace('[files removeItemAtURL:staging','').replace('removeItemAtURL:ExportRoot()','') ,'export never removes a private item (it only removes its own temporary files)')
need('CleanExports()' in pa.split('completionWithItemsHandler')[1][:200] and pa.count('CleanExports();')>=4,'temporary staging and ZIP are removed after sharing, before the next export and when the album opens')
need('exportAll' in pa and 'Export as ZIP' in pa and 'square.and.arrow.up.on.square' in pa and 'self.exportButton' in pa,'Export All is a bar button and Export as ZIP is in the selection actions')
need('The private copies stay' in pa and 'delete it from wherever you put it' in pa,'the confirmation says it is a copy and that the ZIP is no longer private')
need('UIActivityViewController' in pa.split('- (void)buildExport')[1],'the ZIP is handed to the share sheet')
need('Export as ZIP' in adv,'the Settings note mentions the export')
sys.exit(1 if bad else 0)
