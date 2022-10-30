#!/bin/sh

echo '[po_directory] .'

for markdown in ../src/**/*.md ../README.md; do
  cat << END_OF_CFG

[type:text] \\
  $markdown \\
  \$lang:\$lang/${markdown#../} \\
  opt:"--option markdown --keep 0"
END_OF_CFG
done
