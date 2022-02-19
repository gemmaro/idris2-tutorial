#!/bin/sh

po4a_config_file_path=po4a.cfg

echo '[po_directory] po/' > $po4a_config_file_path

for markdown_file_path in *.md; do
	markdown_basename=$(basename "$markdown_file_path")
	echo "[type: text] $markdown_basename \$lang:po/\$lang/$markdown_basename opt:\"--option markdown --option neverwrap\" --keep 0" >> $po4a_config_file_path
done
