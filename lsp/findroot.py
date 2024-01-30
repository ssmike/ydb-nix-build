#!/bin/env python
import sys
import os


def find_arc_root(path):
    path = os.path.abspath(path)
    while path != '/':
        if os.path.isfile(os.path.join(path, '.arcadia.root')):
            return path
        path = os.path.split(path)[0]


if __name__ == '__main__':
    print(find_arc_root(sys.argv[1]))
