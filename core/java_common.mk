# Common to host and target Java modules.

###########################################################
## Java version
###########################################################
# Use the LOCAL_JAVA_LANGUAGE_VERSION if it is set, otherwise
# use one based on the LOCAL_SDK_VERSION. If it is < 24
# pass "1.7" to the tools, if it is unset, >= 24 or "current"
# pass "1.8".
#
# The LOCAL_SDK_VERSION behavior is to ensure that, by default,
# code that is expected to run on older releases of Android
# does not use any 1.8 language features that are not supported
# on earlier runtimes (like default / static interface methods).
# Modules can override this logic by specifying
# LOCAL_JAVA_LANGUAGE_VERSION explicitly.
ifeq (,$(LOCAL_JAVA_LANGUAGE_VERSION))
  private_sdk_versions_without_any_java_18_support := 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
  ifneq (,$(filter $(LOCAL_SDK_VERSION), $(private_sdk_versions_without_any_java_18_support)))
    LOCAL_JAVA_LANGUAGE_VERSION := 1.7
  else
    ifneq ($(EXPERIMENTAL_USE_OPENJDK9),true)
      LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    else
      LOCAL_JAVA_LANGUAGE_VERSION := 1.9
    endif
  endif
endif
LOCAL_JAVACFLAGS += -source $(LOCAL_JAVA_LANGUAGE_VERSION) -target $(LOCAL_JAVA_LANGUAGE_VERSION)

###########################################################
## .proto files: Compile proto files to .java
###########################################################
proto_sources := $(filter %.proto,$(LOCAL_SRC_FILES))
# Because names of the .java files compiled from .proto files are unknown until the
# .proto files are compiled, we use a timestamp file as depedency.
proto_java_sources_file_stamp :=
ifneq ($(proto_sources),)
proto_sources_fullpath := $(addprefix $(LOCAL_PATH)/, $(proto_sources))

proto_java_intemediate_dir := $(intermediates.COMMON)/proto
proto_java_sources_file_stamp := $(proto_java_intemediate_dir)/Proto.stamp
proto_java_sources_dir := $(proto_java_intemediate_dir)/src

$(proto_java_sources_file_stamp): PRIVATE_PROTO_INCLUDES := $(TOP)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_SRC_FILES := $(proto_sources_fullpath)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_DIR := $(proto_java_sources_dir)
ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),micro)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javamicro_out
else
  ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nano)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javanano_out
  else
    ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),stream)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javastream_out
$(proto_java_sources_file_stamp): $(HOST_OUT_EXECUTABLES)/protoc-gen-javastream
    else
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --java_out
    endif
  endif
endif
$(proto_java_sources_file_stamp): PRIVATE_PROTOC_FLAGS := $(LOCAL_PROTOC_FLAGS)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_PARAMS := $(LOCAL_PROTO_JAVA_OUTPUT_PARAMS)
$(proto_java_sources_file_stamp) : $(proto_sources_fullpath) $(PROTOC)
	$(call transform-proto-to-java)

#TODO: protoc should output the dependencies introduced by imports.

ALL_MODULES.$(my_register_name).PROTO_FILES := $(proto_sources_fullpath)
endif # proto_sources

#########################################
## Java resources

# Look for resource files in any specified directories.
# Non-java and non-doc files will be picked up as resources
# and included in the output jar file.
java_resource_file_groups :=

LOCAL_JAVA_RESOURCE_DIRS := $(strip $(LOCAL_JAVA_RESOURCE_DIRS))
ifneq ($(LOCAL_JAVA_RESOURCE_DIRS),)
  # This makes a list of words like
  #     <dir1>::<file1>:<file2> <dir2>::<file1> <dir3>:
  # where each of the files is relative to the directory it's grouped with.
  # Directories that don't contain any resource files will result in groups
  # that end with a colon, and they are stripped out in the next step.
  java_resource_file_groups += \
    $(foreach dir,$(LOCAL_JAVA_RESOURCE_DIRS), \
	$(subst $(space),:,$(strip \
		$(LOCAL_PATH)/$(dir): \
	    $(patsubst ./%,%,$(sort $(shell cd $(LOCAL_PATH)/$(dir) && \
		find . \
		    -type d -a -name ".svn" -prune -o \
		    -type f \
			-a \! -name "*.java" \
			-a \! -name "package.html" \
			-a \! -name "overview.html" \
			-a \! -name ".*.swp" \
			-a \! -name ".DS_Store" \
			-a \! -name "*~" \
			-print \
		    ))) \
	)) \
    )
  java_resource_file_groups := $(filter-out %:,$(java_resource_file_groups))
endif # LOCAL_JAVA_RESOURCE_DIRS

ifneq ($(LOCAL_JAVA_RESOURCE_FILES),)
  # Converts LOCAL_JAVA_RESOURCE_FILES := <file> to $(dir $(file))::$(notdir $(file))
  # and LOCAL_JAVA_RESOURCE_FILES := <dir>:<file> to <dir>::<file>
  java_resource_file_groups += $(strip $(foreach res,$(LOCAL_JAVA_RESOURCE_FILES), \
    $(eval _file := $(call word-colon,2,$(res))) \
    $(if $(_file), \
      $(eval _base := $(call word-colon,1,$(res))), \
      $(eval _base := $(dir $(res))) \
        $(eval _file := $(notdir $(res)))) \
    $(if $(filter /%, \
      $(filter-out $(OUT_DIR)/%,$(_base) $(_file))), \
        $(call pretty-error,LOCAL_JAVA_RESOURCE_FILES may not include absolute paths: $(_base) $(_file))) \
    $(patsubst %/,%,$(_base))::$(_file)))

endif # LOCAL_JAVA_RESOURCE_FILES

ifdef java_resource_file_groups
  # The full paths to all resources, used for dependencies.
  java_resource_sources := \
    $(foreach group,$(java_resource_file_groups), \
	$(addprefix $(word 1,$(subst :,$(space),$(group)))/, \
	    $(wordlist 2,9999,$(subst :,$(space),$(group))) \
	) \
    )
  # The arguments to jar that will include these files in a jar file.
  # Quote the file name to handle special characters (such as #) correctly.
  extra_jar_args := \
    $(foreach group,$(java_resource_file_groups), \
	$(addprefix -C "$(word 1,$(subst :,$(space),$(group)))" , \
	    $(foreach w, $(wordlist 2,9999,$(subst :,$(space),$(group))), "$(w)" ) \
	) \
    )
  java_resource_file_groups :=
else
  java_resource_sources :=
  extra_jar_args :=
endif # java_resource_file_groups

#####################################
## Warn if there is unrecognized file in LOCAL_SRC_FILES.
my_unknown_src_files := $(filter-out \
  %.java %.aidl %.proto %.logtags %.fs %.rs, \
  $(LOCAL_SRC_FILES) $(LOCAL_INTERMEDIATE_SOURCES) $(LOCAL_GENERATED_SOURCES))
ifneq ($(my_unknown_src_files),)
$(warning $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Unused source files: $(my_unknown_src_files))
endif

######################################
## PRIVATE java vars
# LOCAL_SOURCE_FILES_ALL_GENERATED is set only if the module does not have static source files,
# but generated source files in its LOCAL_INTERMEDIATE_SOURCE_DIR.
# You have to set up the dependency in some other way.
need_compile_java := $(strip $(all_java_sources)$(all_res_assets)$(java_resource_sources))$(LOCAL_STATIC_JAVA_LIBRARIES)$(filter true,$(LOCAL_SOURCE_FILES_ALL_GENERATED))
ifdef need_compile_java

annotation_processor_flags :=
annotation_processor_deps :=

ifdef LOCAL_ANNOTATION_PROCESSORS
  annotation_processor_jars := $(call java-lib-files,$(LOCAL_ANNOTATION_PROCESSORS),true)
  annotation_processor_flags += -processorpath $(call normalize-path-list,$(annotation_processor_jars))
  annotation_processor_deps += $(annotation_processor_jars)

  # b/25860419: annotation processors must be explicitly specified for grok
  annotation_processor_flags += $(foreach class,$(LOCAL_ANNOTATION_PROCESSOR_CLASSES),-processor $(class))

  annotation_processor_jars :=
endif

full_static_java_libs := $(call java-lib-files,$(LOCAL_STATIC_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
full_static_java_header_libs := $(call java-lib-header-files,$(LOCAL_STATIC_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_STATIC_JAVA_LIBRARIES := $(full_static_java_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_STATIC_JAVA_HEADER_LIBRARIES := $(full_static_java_header_libs)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASSET_DIR := $(LOCAL_ASSET_DIR)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CLASS_INTERMEDIATES_DIR := $(intermediates.COMMON)/classes
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ANNO_INTERMEDIATES_DIR := $(intermediates.COMMON)/anno
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/src
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HAS_PROTO_SOURCES := $(if $(proto_sources),true)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_PROTO_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/proto
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HAS_RS_SOURCES :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAVA_SOURCES := $(all_java_sources)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAVA_SOURCE_LIST := $(java_source_list_file)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RMTYPEDEFS := $(LOCAL_RMTYPEDEFS)

full_java_bootclasspath_libs :=
empty_bootclasspath :=

# full_java_libs: The list of files that should be used as the classpath.
#                 Using this list as a dependency list WILL NOT WORK.
ifndef LOCAL_IS_HOST_MODULE
  ifeq ($(LOCAL_SDK_VERSION),)
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      # No bootclasspath. But we still need "" to prevent javac from using default host bootclasspath.
      empty_bootclasspath := ""
    else  # LOCAL_NO_STANDARD_LIBRARIES
      full_java_bootclasspath_libs := $(call java-lib-header-files,$(TARGET_DEFAULT_BOOTCLASSPATH_LIBRARIES))
    endif  # LOCAL_NO_STANDARD_LIBRARIES
  else
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      $(call pretty-error,Must not define both LOCAL_NO_STANDARD_LIBRARIES and LOCAL_SDK_VERSION)
    endif
    ifeq ($(strip $(filter $(LOCAL_SDK_VERSION),$(TARGET_AVAILABLE_SDK_VERSIONS))),)
      $(call pretty-error,Invalid LOCAL_SDK_VERSION '$(LOCAL_SDK_VERSION)' \
             Choices are: $(TARGET_AVAILABLE_SDK_VERSIONS))
    endif
    ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),current)
      # LOCAL_SDK_VERSION is current and no TARGET_BUILD_APPS.
      full_java_bootclasspath_libs := $(call java-lib-header-files,android_stubs_current)
    else ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),system_current)
      full_java_bootclasspath_libs := $(call java-lib-header-files,android_system_stubs_current)
    else ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),test_current)
      full_java_bootclasspath_libs := $(call java-lib-header-files,android_test_stubs_current)
    else
      full_java_bootclasspath_libs := $(call java-lib-header-files,sdk_v$(LOCAL_SDK_VERSION))
    endif # current, system_current, or test_current
  endif # LOCAL_SDK_VERSION

  # In order to compile lambda code javac requires various invokedynamic-
  # related classes to be present. This change adds stubs needed for
  # javac to compile lambdas.
  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    ifdef TARGET_BUILD_APPS
      full_java_bootclasspath_libs += $(call java-lib-header-files,sdk-core-lambda-stubs)
    else
      full_java_bootclasspath_libs += $(call java-lib-header-files,core-lambda-stubs)
    endif
  endif

  full_shared_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
  full_shared_java_header_libs := $(call java-lib-header-files,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))

else # LOCAL_IS_HOST_MODULE

  ifeq ($(USE_CORE_LIB_BOOTCLASSPATH),true)
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      empty_bootclasspath := ""
    else
      full_java_bootclasspath_libs := $(call java-lib-header-files,$(addsuffix -hostdex,$(TARGET_DEFAULT_BOOTCLASSPATH_LIBRARIES)),true)
    endif

    full_shared_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES),true)
    full_shared_java_header_libs := $(call java-lib-header-files,$(LOCAL_JAVA_LIBRARIES),true)
  else # !USE_CORE_LIB_BOOTCLASSPATH

    full_shared_java_libs := $(addprefix $(HOST_OUT_JAVA_LIBRARIES)/,\
      $(addsuffix $(COMMON_JAVA_PACKAGE_SUFFIX),$(LOCAL_JAVA_LIBRARIES)))
  endif # USE_CORE_LIB_BOOTCLASSPATH
endif # !LOCAL_IS_HOST_MODULE

ifdef empty_bootclasspath
  ifdef full_java_bootclasspath_libs
    $(call pretty-error,internal error: empty_bootclasspath and full_java_bootclasspath_libs should not both be set)
  endif
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := $(full_java_bootclasspath_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_EMPTY_BOOTCLASSPATH := $(empty_bootclasspath)

full_java_libs := $(full_shared_java_libs) $(full_static_java_libs) $(LOCAL_CLASSPATH)
full_java_header_libs := $(full_shared_java_header_libs) $(full_static_java_header_libs)

ifndef LOCAL_IS_HOST_MODULE
# This is set by packages that are linking to other packages that export
# shared libraries, allowing them to make use of the code in the linked apk.
apk_libraries := $(sort $(LOCAL_APK_LIBRARIES) $(LOCAL_RES_LIBRARIES))
ifneq ($(apk_libraries),)
  link_apk_libraries := $(call app-lib-files,$(apk_libraries))
  link_apk_header_libs := $(call app-lib-header-files,$(apk_libraries))

  # link against the jar with full original names (before proguard processing).
  full_shared_java_libs += $(link_apk_libraries)
  full_java_libs += $(link_apk_libraries)
  full_java_header_libs += $(link_apk_header_libs)
endif

# This is set by packages that contain instrumentation, allowing them to
# link against the package they are instrumenting.  Currently only one such
# package is allowed.
LOCAL_INSTRUMENTATION_FOR := $(strip $(LOCAL_INSTRUMENTATION_FOR))
ifdef LOCAL_INSTRUMENTATION_FOR
  ifneq ($(words $(LOCAL_INSTRUMENTATION_FOR)),1)
    $(error \
        $(LOCAL_PATH): Multiple LOCAL_INSTRUMENTATION_FOR members defined)
  endif

  link_instr_intermediates_dir.COMMON := $(call intermediates-dir-for, \
      APPS,$(LOCAL_INSTRUMENTATION_FOR),,COMMON)
  # link against the jar with full original names (before proguard processing).
  link_instr_classes_jar := $(link_instr_intermediates_dir.COMMON)/classes-pre-proguard.jar
  ifneq ($(TURBINE_ENABLED),false)
    link_instr_classes_header_jar := $(link_instr_intermediates_dir.COMMON)/classes-header.jar
  else
    link_instr_classes_header_jar := $(link_instr_intermediates_dir.COMMON)/classes.jar
  endif
  full_java_libs += $(link_instr_classes_jar)
  full_java_header_libs += $(link_instr_classes_header_jar)
endif  # LOCAL_INSTRUMENTATION_FOR
endif  # LOCAL_IS_HOST_MODULE

endif  # need_compile_java

# We may want to add jar manifest or jar resource files even if there is no java code at all.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_EXTRA_JAR_ARGS := $(extra_jar_args)
jar_manifest_file :=
ifneq ($(strip $(LOCAL_JAR_MANIFEST)),)
jar_manifest_file := $(LOCAL_PATH)/$(LOCAL_JAR_MANIFEST)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAR_MANIFEST := $(jar_manifest_file)
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAR_MANIFEST :=
endif

##########################################################
ifndef LOCAL_IS_HOST_MODULE
## AAPT Flags
# aapt doesn't accept multiple --extra-packages flags.
# We have to collapse them into a single --extra-packages flag here.
LOCAL_AAPT_FLAGS := $(strip $(LOCAL_AAPT_FLAGS))
ifdef LOCAL_AAPT_FLAGS
ifeq ($(filter 0 1,$(words $(filter --extra-packages,$(LOCAL_AAPT_FLAGS)))),)
aapt_flags := $(subst --extra-packages$(space),--extra-packages@,$(LOCAL_AAPT_FLAGS))
aapt_flags_extra_packages := $(patsubst --extra-packages@%,%,$(filter --extra-packages@%,$(aapt_flags)))
aapt_flags_extra_packages := $(sort $(subst :,$(space),$(aapt_flags_extra_packages)))
LOCAL_AAPT_FLAGS := $(filter-out --extra-packages@%,$(aapt_flags)) \
    --extra-packages $(subst $(space),:,$(aapt_flags_extra_packages))
aapt_flags_extra_packages :=
aapt_flags :=
endif
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) $(PRODUCT_AAPT_FLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_AAPT_CHARACTERISTICS := $(TARGET_AAPT_CHARACTERISTICS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MANIFEST_PACKAGE_NAME := $(LOCAL_MANIFEST_PACKAGE_NAME)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MANIFEST_INSTRUMENTATION_FOR := $(LOCAL_MANIFEST_INSTRUMENTATION_FOR)

ifdef aidl_sources
ALL_MODULES.$(my_register_name).AIDL_FILES := $(aidl_sources)
endif
ifdef renderscript_sources
ALL_MODULES.$(my_register_name).RS_FILES := $(renderscript_sources_fullpath)
endif
endif  # !LOCAL_IS_HOST_MODULE

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_JAVA_LIBRARIES := $(full_java_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_JAVA_HEADER_LIBRARIES := $(full_java_header_libs)

ALL_MODULES.$(my_register_name).INTERMEDIATE_SOURCE_DIR := \
    $(ALL_MODULES.$(my_register_name).INTERMEDIATE_SOURCE_DIR) $(LOCAL_INTERMEDIATE_SOURCE_DIR)

###########################################################
# JACK
###########################################################
ifdef LOCAL_JACK_ENABLED
ifdef need_compile_java

LOCAL_JACK_FLAGS += -D jack.java.source.version=$(LOCAL_JAVA_LANGUAGE_VERSION)

full_static_jack_libs := \
    $(foreach lib,$(LOCAL_STATIC_JAVA_LIBRARIES), \
      $(call intermediates-dir-for, \
        JAVA_LIBRARIES,$(lib),$(LOCAL_IS_HOST_MODULE),COMMON)/classes.jack)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_STATIC_JACK_LIBRARIES := $(full_static_jack_libs)

full_shared_jack_libs := $(call jack-lib-files,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
ifndef LOCAL_SDK_VERSION
  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    my_jack_bootclasspath := $(TARGET_DEFAULT_BOOTCLASSPATH_LIBRARIES)
    ifdef LOCAL_IS_HOST_MODULE
      my_jack_bootclasspath := $(addsuffix -hostdex,$(my_jack_bootclasspath))
    endif
    full_shared_jack_libs := $(call jack-lib-files,$(my_jack_bootclasspath),$(LOCAL_IS_HOST_MODULE)) $(full_shared_jack_libs)
  endif
endif
full_jack_deps := $(full_shared_jack_libs)

ifndef LOCAL_IS_HOST_MODULE
# Turn off .toc optimization for apps build as we cannot build dexdump.
ifeq (,$(TARGET_BUILD_APPS))
full_jack_deps := $(patsubst %.jack, %.dex.toc, $(full_jack_deps))
endif
endif # !LOCAL_IS_HOST_MODULE
full_shared_jack_libs += $(LOCAL_JACK_CLASSPATH)
full_jack_deps += $(full_static_jack_libs) $(LOCAL_JACK_CLASSPATH)

ifndef LOCAL_IS_HOST_MODULE
# This is set by packages that are linking to other packages that export
# shared libraries, allowing them to make use of the code in the linked apk.
ifneq ($(apk_libraries),)
  link_apk_jack_libraries := \
      $(foreach lib,$(apk_libraries), \
        $(call intermediates-dir-for, \
              APPS,$(lib),,COMMON)/classes.jack)

  # link against the jar with full original names (before proguard processing).
  full_shared_jack_libs += $(link_apk_jack_libraries)
  full_jack_deps += $(link_apk_jack_libraries)
endif

# This is set by packages that contain instrumentation, allowing them to
# link against the package they are instrumenting.  Currently only one such
# package is allowed.
ifdef LOCAL_INSTRUMENTATION_FOR
   # link against the jar with full original names (before proguard processing).
   link_instr_classes_jack := $(link_instr_intermediates_dir.COMMON)/classes.noshrob.jack
   full_shared_jack_libs += $(link_instr_classes_jack)
   full_jack_deps += $(link_instr_classes_jack)
endif  # LOCAL_INSTRUMENTATION_FOR
endif  # !LOCAL_IS_HOST_MODULE

# Propagate local configuration options to this target.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JACK_SHARED_LIBRARIES:= $(full_shared_jack_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)

endif  # need_compile_java
endif # LOCAL_JACK_ENABLED


###########################################################
# Verify that all libraries are safe to use
###########################################################
ifndef LOCAL_IS_HOST_MODULE
ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
my_warn_types := java:platform
my_allowed_types := java:sdk java:system
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
my_warn_types := java:system java:platform
my_allowed_types := java:sdk
else
my_link_type := java:platform
my_warn_types :=
my_allowed_types := java:sdk java:system java:platform
endif

my_link_deps := $(addprefix JAVA_LIBRARIES:,$(LOCAL_STATIC_JAVA_LIBRARIES))
my_link_deps += $(addprefix APPS:,$(apk_libraries))

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk
endif  # !LOCAL_IS_HOST_MODULE
