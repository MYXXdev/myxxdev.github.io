#!/bin/bash
dpkg-scanpackages -m debs/ /dev/null > Packages && bzip2 -c9 Packages > Packages.bz2 && gzip -c9 Packages > Packages.gz
