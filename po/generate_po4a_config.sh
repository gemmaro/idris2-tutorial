#!/bin/sh

echo '[po_directory] po/'

for markdown in src/**/*.md; do
  cat << END_OF_CFG

[type: text] \\
  $markdown \\
  \$lang:po/\$lang/$markdown \\
  opt:"--option markdown --keep 0"
END_OF_CFG
done
