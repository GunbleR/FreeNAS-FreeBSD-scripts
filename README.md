# FreeNAS-FreeBSD-scripts
Scripts written for personal use in FreeBSD jails.
***
# flac-split.sh
automates spliting flac + cue rip into separete flac files w/ tags.
requires installation of: cuetools shntool flac bash

Usage: flac_split.sh [option...] [path_to/file.flac]
options:
   -c, --cue xyz        name of cue file
   -t, --template xyz   output name template, use 'man shnsplit' for info, default:'%n_-_%t'
   -d, --directory      output directory, defaults to input file
   -s,                  disables prompts and picks 1st detected file, use for scripts, run at your own risk
                        ex: find . -name *.flac | xargs -I '{}' ~/scripts/flac_split.sh -s '{}'

***
