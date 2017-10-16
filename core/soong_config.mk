SOONG := $(SOONG_OUT_DIR)/soong
SOONG_BOOTSTRAP := $(SOONG_OUT_DIR)/.soong.bootstrap
SOONG_BUILD_NINJA := $(SOONG_OUT_DIR)/build.ninja
SOONG_IN_MAKE := $(SOONG_OUT_DIR)/.soong.in_make
SOONG_MAKEVARS_MK := $(SOONG_OUT_DIR)/make_vars-$(TARGET_PRODUCT).mk
SOONG_VARIABLES := $(SOONG_OUT_DIR)/soong.variables
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android-$(TARGET_PRODUCT).mk

BINDER32BIT :=
ifneq ($(TARGET_USES_64_BIT_BINDER),true)
ifneq ($(TARGET_IS_64_BIT),true)
BINDER32BIT := true
endif
endif

ifeq ($(WRITE_SOONG_VARIABLES),true)
# Converts a list to a JSON list.
# $1: List separator.
# $2: List.
_json_list = [$(if $(2),"$(subst $(1),"$(comma)",$(2))")]

# Converts a space-separated list to a JSON list.
json_list = $(call _json_list,$(space),$(1))

# Converts a comma-separated list to a JSON list.
csv_to_json_list = $(call _json_list,$(comma),$(1))

# 1: Key name
# 2: Value
add_json_val = $(eval _contents := $$(_contents)    "$$(strip $$(1))":$$(space)$$(strip $$(2))$$(comma)$$(newline))
add_json_str = $(call add_json_val,$(1),"$(strip $(2))")
add_json_list = $(call add_json_val,$(1),$(call json_list,$(patsubst %,%,$(2))))
add_json_csv = $(call add_json_val,$(1),$(call csv_to_json_list,$(strip $(2))))
add_json_bool = $(call add_json_val,$(1),$(if $(strip $(2)),true,false))

invert_bool = $(if $(strip $(1)),,true)

# Create soong.variables with copies of makefile settings.  Runs every build,
# but only updates soong.variables if it changes
$(shell mkdir -p $(dir $(SOONG_VARIABLES)))
_contents := {$(newline)

$(call add_json_str,  Make_suffix, -$(TARGET_PRODUCT))

$(call add_json_val,  Platform_sdk_version,              $(PLATFORM_SDK_VERSION))
$(call add_json_csv,  Platform_version_active_codenames, $(PLATFORM_VERSION_ALL_CODENAMES))
$(call add_json_csv,  Platform_version_future_codenames, $(PLATFORM_VERSION_FUTURE_CODENAMES))

$(call add_json_bool, Allow_missing_dependencies,        $(ALLOW_MISSING_DEPENDENCIES))
$(call add_json_bool, Unbundled_build,                   $(TARGET_BUILD_APPS))
$(call add_json_bool, Pdk,                               $(filter true,$(TARGET_BUILD_PDK)))

$(call add_json_bool, Debuggable,                        $(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
$(call add_json_bool, Eng,                               $(filter eng,$(TARGET_BUILD_VARIANT)))

$(call add_json_str,  DeviceName,                        $(TARGET_DEVICE))
$(call add_json_str,  DeviceArch,                        $(TARGET_ARCH))
$(call add_json_str,  DeviceArchVariant,                 $(TARGET_ARCH_VARIANT))
$(call add_json_str,  DeviceCpuVariant,                  $(TARGET_CPU_VARIANT))
$(call add_json_list, DeviceAbi,                         $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2))

$(call add_json_str,  DeviceSecondaryArch,               $(TARGET_2ND_ARCH))
$(call add_json_str,  DeviceSecondaryArchVariant,        $(TARGET_2ND_ARCH_VARIANT))
$(call add_json_str,  DeviceSecondaryCpuVariant,         $(TARGET_2ND_CPU_VARIANT))
$(call add_json_list, DeviceSecondaryAbi,                $(TARGET_2ND_CPU_ABI) $(TARGET_2ND_CPU_ABI2))
$(call add_json_bool, DeviceIsContainer,                 $(filter true,$(BOARD_IS_CONTAINER)))

$(call add_json_str,  HostArch,                          $(HOST_ARCH))
$(call add_json_str,  HostSecondaryArch,                 $(HOST_2ND_ARCH))
$(call add_json_bool, HostStaticBinaries,                $(BUILD_HOST_static))

$(call add_json_str,  CrossHost,                         $(HOST_CROSS_OS))
$(call add_json_str,  CrossHostArch,                     $(HOST_CROSS_ARCH))
$(call add_json_str,  CrossHostSecondaryArch,            $(HOST_CROSS_2ND_ARCH))

$(call add_json_list, SanitizeHost,                      $(SANITIZE_HOST))
$(call add_json_list, SanitizeDevice,                    $(SANITIZE_TARGET))
$(call add_json_list, SanitizeDeviceDiag,                $(SANITIZE_TARGET_DIAG))
$(call add_json_list, SanitizeDeviceArch,                $(SANITIZE_TARGET_ARCH))

$(call add_json_bool, Safestack,                         $(filter true,$(USE_SAFESTACK)))
$(call add_json_bool, EnableCFI,                         $(call invert_bool,$(filter false,$(ENABLE_CFI))))
$(call add_json_list, IntegerOverflowExcludePaths,       $(INTEGER_OVERFLOW_EXCLUDE_PATHS) $(PRODUCT_INTEGER_OVERFLOW_EXCLUDE_PATHS))

$(call add_json_bool, ClangTidy,                         $(filter 1 true,$(WITH_TIDY)))
$(call add_json_str,  TidyChecks,                        $(WITH_TIDY_CHECKS))

$(call add_json_bool, NativeCoverage,                    $(filter true,$(NATIVE_COVERAGE)))
$(call add_json_csv,  CoveragePaths,                     $(COVERAGE_PATHS))
$(call add_json_csv,  CoverageExcludePaths,              $(COVERAGE_EXCLUDE_PATHS))

$(call add_json_bool, ArtUseReadBarrier,                 $(call invert_bool,$(filter false,$(PRODUCT_ART_USE_READ_BARRIER))))
$(call add_json_bool, Binder32bit,                       $(BINDER32BIT))
$(call add_json_bool, Brillo,                            $(BRILLO))
$(call add_json_str,  BtConfigIncludeDir,                $(BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR))
$(call add_json_bool, Device_uses_hwc2,                  $(filter true,$(TARGET_USES_HWC2)))
$(call add_json_list, DeviceKernelHeaders,               $(TARGET_PROJECT_SYSTEM_INCLUDES))
$(call add_json_bool, DevicePrefer32BitExecutables,      $(filter true,$(TARGET_PREFER_32_BIT_EXECUTABLES)))
$(call add_json_val,  DeviceUsesClang,                   $(if $(USE_CLANG_PLATFORM_BUILD),$(USE_CLANG_PLATFORM_BUILD),false))
$(call add_json_str,  DeviceVndkVersion,                 $(BOARD_VNDK_VERSION))
$(call add_json_bool, Malloc_not_svelte,                 $(call invert_bool,$(filter true,$(MALLOC_SVELTE))))
$(call add_json_str,  Override_rs_driver,                $(OVERRIDE_RS_DRIVER))
$(call add_json_bool, Treble,                            $(filter true,$(PRODUCT_FULL_TREBLE)))
$(call add_json_bool, Uml,                               $(filter true,$(TARGET_USER_MODE_LINUX)))
$(call add_json_str,  VendorPath,                        $(TARGET_COPY_OUT_VENDOR))

$(call add_json_bool, UseGoma,                           $(filter-out false,$(USE_GOMA)))

_contents := $(subst $(comma)$(newline)__SV_END,$(newline)}$(newline),$(_contents)__SV_END)

$(file >$(SOONG_VARIABLES).tmp,$(_contents))

$(shell if ! cmp -s $(SOONG_VARIABLES).tmp $(SOONG_VARIABLES); then \
	  mv $(SOONG_VARIABLES).tmp $(SOONG_VARIABLES); \
	else \
	  rm $(SOONG_VARIABLES).tmp; \
	fi)

_json_list :=
json_list :=
csv_to_json_list :=
add_json_val :=
add_json_str :=
add_json_list :=
add_json_csv :=
add_json_bool :=
invert_bool :=
_contents :=

endif # CONFIGURE_SOONG
