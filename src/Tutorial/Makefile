pot_file_path = po/all.pot

.PHONEY: generate_translations
generate_translations: $(pot_file_path)
	po4a po4a.cfg

$(pot_file_path): generate_po4a_config_file.sh *.md
	./$<
