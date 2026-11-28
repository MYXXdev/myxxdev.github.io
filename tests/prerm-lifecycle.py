from pathlib import Path
import os, subprocess, tempfile
source=(Path(__file__).resolve().parents[1]/'layout/DEBIAN/prerm').read_text()
with tempfile.TemporaryDirectory() as temp:
    root=Path(temp); helper=root/'usr/sbin/MYXXdev/MYbloXX/MYXXdev';helper.parent.mkdir(parents=True)
    log=root/'events'; commands=root/'commands';commands.mkdir()
    (commands/'launchctl').write_text('#!/bin/sh\necho "stop $*" >> "$MYB_TEST_EVENTS"\n')
    (commands/'launchctl').chmod(0o755)
    helper.write_text('#!/bin/sh\necho "helper $*" >> "$MYB_TEST_EVENTS"\nexit "${MYB_TEST_RESULT:-0}"\n');helper.chmod(0o755)
    script=root/'prerm';script.write_text(source.replace('for candidate in / /var/jb;',f'for candidate in "{root}";'))
    env=dict(os.environ,PATH=str(commands)+os.pathsep+os.environ['PATH'],MYB_TEST_EVENTS=str(log))
    for action in ['upgrade','failed-upgrade','']:
        assert subprocess.run(['sh',str(script),action],env=env).returncode==0
        assert not log.exists(), 'upgrade must not stop services or remove configuration'
    log.unlink(missing_ok=True)
    assert subprocess.run(['sh',str(script),'deconfigure'],env=env).returncode==0
    assert not log.exists(), 'deconfigure (temporary replacement) must not detach protection or delete data'
    log.unlink(missing_ok=True)
    assert subprocess.run(['sh',str(script),'remove'],env=env).returncode==0
    events=log.read_text().splitlines()
    assert len(events)==6 and all(s.startswith('stop ') for s in events[:5]) and events[-1]=='helper uninstall'
    env['MYB_TEST_RESULT']='73'
    assert subprocess.run(['sh',str(script),'remove'],env=env,capture_output=True).returncode==73, 'failed cleanup must not silently remove the helper'
print('Removal invokes native cleanup after stopping writers; upgrades and deconfigure do nothing; errors stop removal')
