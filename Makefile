PROJROOT:=$(git rev-parse --show-toplevel)

AG:=autogen
JQ:=jq
JQ_OPTIONS:=
REGION?=us-east-1
BUILD_DIR:=_build/$(REGION)
VERBOSE?=0

ifeq ($(VERBOSE),1)
	VFILTER :=
else
	VFILTER :=>/dev/null
endif

SOURCE_TEMPLATES:=$(wildcard stacks/*.tpl)
IN_SOURCES:= stacks/codecommit-build.py
SOURCE_PARAMS:=$(wildcard params/*.tpl)
TEMPLATES:=$(patsubst %.tpl, $(BUILD_DIR)/%.template, $(SOURCE_TEMPLATES))
STACK_PARAMS:=$(patsubst %.tpl, $(BUILD_DIR)/%.params, $(SOURCE_PARAMS))
IN_OUTPUTS:=$(patsubst %,%.in, $(IN_SOURCES))

SOURCES:=$(shell find stacks/ -type f -name '*.in')

.PHONY: all
all: autogen/stack.def \
	 $(TEMPLATES) \
	 $(STACK_PARAMS)

autogen/stack.def: autogen/stack.def.in
	cat $^ > $@

$(BUILD_DIR)/%.json: %.tpl $(SOURCES) $(IN_OUTPUTS)
	mkdir -p $(dir $@)
	$(AG) --override-tpl=$< --definitions=autogen/stack.def > $@

$(BUILD_DIR)/%.template: $(BUILD_DIR)/%.json
	$(JQ) . $< > $@

$(BUILD_DIR)/%.params: $(BUILD_DIR)/%.json
	$(JQ) '.' $< > $@

%.in: %
	echo "[+ autogen5 template +]" > $@
	echo '{"Fn::Join": ["\n", [' >> $@
	$(SHELL) scm/ppag.scm $^ >> $@
	echo ']]}' >> $@

.PHONY: clean
clean:
	-rm -r $(BUILD_DIR)
