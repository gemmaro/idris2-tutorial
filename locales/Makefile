po4a = po4a.cfg

all: ${po4a}
	po4a $<

${po4a}: po4a.sh ../src/**/*.md
	./$< > $@
