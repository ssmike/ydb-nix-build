#!/usr/bin/env python3
'''
    Usage:
    [arcdir] -- update compile commands for arcdir
'''

import os
import os.path
import sys
import json
import collections
import subprocess

sys.path.append(os.path.dirname(__file__))
from findroot import find_arc_root  # noqa


paths = [os.path.abspath(f) for f in sys.argv[1:]]
arc_root = find_arc_root(paths[0])

base = os.path.join(arc_root, 'compile_commands.json')

files_to_commands = collections.defaultdict(str)


def _check_json(_json, abs_files):
    if len(_json) == 0:
        return
    entry = _json[0]
    if abs_files:
        for entry in _json:
            fname = entry["file"]
            if 'pb.cc' not in fname:
                if os.path.isfile(entry["file"]):
                    print(entry["file"])
                    return
        assert False
    else:
        assert '/' not in entry["file"]


def parse_database(_json, abs_files=False, extra=''):
    _check_json(_json, abs_files)
    for entry in _json:
        _file = entry["file"]
        _dir = entry["directory"]
        if abs_files:
            _dir = os.path.dirname(_file)
            _file = os.path.basename(_file)
        files_to_commands[_dir + '/' + _file] = entry['command'] + ' ' + extra


if os.path.isfile(base):
    with open(base) as fin:
        parse_database(json.load(fin))
    print('database loaded', file=sys.stderr)


command = [os.path.join(arc_root, 'ya'), 'dump', 'compile-commands'] + paths
print('call', command)
generated = subprocess.run(command, check=True, capture_output=True).stdout
extra_includes = (
    ('.ycm',),
    ('.ycm', 'yt'),
    ('.ycm', 'contrib', 'libs', 'opentelemetry-proto'),
    ('library', 'cpp', 'testing'),
    ('contrib', 'libs', 'protobuf', 'src'),
)
extras = ' '.join('-I' + os.path.join(arc_root, *path) for path in extra_includes)
parse_database(json.loads(generated), abs_files=True, extra=extras)

print('writing database')
result = []
for file, command in files_to_commands.items():
    dirname = os.path.dirname(file)
    filename = os.path.basename(file)
    result.append(
        {
            'directory': dirname,
            'command': command,
            'file': filename
        }
    )


path = base
newpath = base + '.new'

with open(newpath, 'w') as fout:
    json.dump(result, fout, indent=2)

os.rename(newpath, path)
