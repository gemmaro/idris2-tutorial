po4a = po4a.cfg

.PHONY: start
start:
	foreman start

translate: ${po4a}
	po4a $<

${po4a}: po4a-cfg ../src/**/*.md
	./$< > $@
