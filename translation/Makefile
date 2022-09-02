proc_runner ?= foreman

.PHONY: start
start:
	${proc_runner} start

po4a = po4a.cfg

.PHONY: translate
translate: ${po4a}
	po4a $<

${po4a}: gen-po4a-cfg
	./$< > $@
