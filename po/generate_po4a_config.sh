#!/bin/sh

config=po4a.cfg

echo '[po_directory] po/' > $config

for markdown in src/**/*.md; do
	echo "[type: text] $markdown \$lang:po/\$lang/$markdown opt:\"--option markdown --option neverwrap --keep 0\"" >> $config
done
