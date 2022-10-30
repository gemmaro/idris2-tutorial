po4a = po4a.cfg

.PHONY: watch
watch: log
	./watch

log:
	mkdir $@

translate: ${po4a}
	po4a $<

${po4a}: po4a.sh ../src/**/*.md
	./$< > $@
