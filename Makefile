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
SOURCE_PARAMS:=$(wildcard params/*.tpl)
TEMPLATES:=$(patsubst %.tpl, $(BUILD_DIR)/%.template, $(SOURCE_TEMPLATES))
STACK_PARAMS:=$(patsubst %.tpl, $(BUILD_DIR)/%.params, $(SOURCE_PARAMS))

SOURCES:=$(shell find stacks/ -type f -name '*.in')

.PHONY: all
all: autogen/stack.def \
	 $(TEMPLATES) \
	 $(STACK_PARAMS)

autogen/stack.def: autogen/stack.def.in
	cat $^ > $@

$(BUILD_DIR)/%.json: %.tpl $(SOURCES)
	mkdir -p $(dir $@)
	$(AG) --override-tpl=$< --definitions=autogen/stack.def > $@

$(BUILD_DIR)/%.template: $(BUILD_DIR)/%.json
	$(JQ) . $< > $@

$(BUILD_DIR)/%.params: $(BUILD_DIR)/%.json
	$(JQ) '.' $< > $@

.PHONY: clean
clean:
	-rm -r $(BUILD_DIR)
