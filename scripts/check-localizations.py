#!/usr/bin/env python3
"""檢查翻譯鍵值、格式參數與 macOS 語言解析，不啟動 App 或操控滑鼠。"""
import json
import re
import plistlib
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
languages = ['en', 'zh-Hant', 'zh-Hans']
tables = {}
for language in languages:
    path = root / 'Resources' / (language + '.lproj') / 'Localizable.strings'
    tables[language] = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
assert all(set(table) == set(tables['en']) for table in tables.values())
for key in tables['en']:
    formats = [re.findall(r'%(?:%|@|d)', tables[language][key]) for language in languages]
    assert formats[0] == formats[1] == formats[2], (key, formats)
source = (root / 'Sources' / 'main.swift').read_text()
keys = set(re.findall(r'localized(?:Format)?\("([^"]+)"', source))
assert keys == set(tables['en']), (keys, set(tables['en']))
app = root / 'build' / '暗幕.app'
with tempfile.TemporaryDirectory(prefix='anmu-languages-') as directory:
    directory = Path(directory)
    probe = directory / 'main.swift'
    probe.write_text('''import Foundation
let bundle = Bundle(path: CommandLine.arguments[1])!
print(bundle.preferredLocalizations.joined(separator: ","))
for key in ["panel.title", "overlay.enable", "help", "shortcut.failed"] {
    print(bundle.localizedString(forKey: key, value: nil, table: nil))
}
''')
    contents = directory / 'Probe.app' / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    metadata = plistlib.loads((root / 'Resources' / 'Info.plist').read_bytes())
    metadata['CFBundleExecutable'] = 'probe'
    (contents / 'Info.plist').write_bytes(plistlib.dumps(metadata))
    executable = contents / 'MacOS' / 'probe'
    subprocess.run(['xcrun', 'swiftc', str(probe), '-o', str(executable)], check=True)
    for requested, expected in [('en', 'en'), ('zh-TW', 'zh-Hant'), ('zh-HK', 'zh-Hant'), ('zh-CN', 'zh-Hans'), ('zh-SG', 'zh-Hans'), ('fr', 'en')]:
        result = subprocess.check_output([str(executable), str(app), '-AppleLanguages', '(' + requested + ')'], text=True)
        assert result.splitlines()[0].split(',')[0] == expected, (requested, result)
        assert tables[expected]['panel.title'] in result, (requested, result)
        assert tables[expected]['shortcut.failed'] in result, (requested, result)
        print(requested + ' -> ' + expected + ': OK')
print('Translation keys and format parameters: OK')
