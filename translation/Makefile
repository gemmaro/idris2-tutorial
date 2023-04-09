PO4A		?= po4a
po4a-cfg	:= po4a.cfg

translate: ${po4a-cfg} record-po4a-version
	${PO4A} $<
.PHONY: translate

record-po4a-version:
	po4a --version > .po4a-version
.PHONY: record-po4a-version
