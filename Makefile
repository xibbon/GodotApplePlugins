.PHONY: run build build2 package dist xcframework check_swiftsyntax generate-stubs split-generate-stubs gendocs docs-html deploy-docs split-build split-dist split-package split-smoke split-validate split-validate-built split-validate-matrix o o-runtime o-fix-rpaths o-sync clean-build clean

# Allow overriding common build knobs.
CONFIG ?= Release
HOST_ARCH ?= $(shell uname -m)
DESTINATIONS ?= generic/platform=iOS generic/platform=iOS\ Simulator platform=macOS,arch=arm64 platform=macOS,arch=x86_64
DERIVED_DATA ?= $(CURDIR)/.xcodebuild
WORKSPACE ?= .swiftpm/xcode/package.xcworkspace
SCHEME ?= GodotApplePlugins
FRAMEWORK_NAMES ?= GodotApplePlugins
SPLIT_FRAMEWORK_NAMES ?= GodotApplePluginsAVFoundation GodotApplePluginsFoundation GodotApplePluginsGameCenter GodotApplePluginsStoreKit GodotApplePluginsAuthenticationServices GodotApplePluginsARKit GodotApplePluginsCoreMotion GodotApplePluginsKeychain
SPLIT_RUNTIME_FRAMEWORK ?= SwiftGodotRuntime
SPLIT_RUNTIME_RPATH ?= @loader_path/../../../../../GodotApplePluginsRuntime/bin
SPLIT_RUNTIME_FRAMEWORK_RPATH ?= @loader_path/../../../GodotApplePluginsRuntime/bin
SPLIT_RUNTIME_LOAD_DYLIB ?= @rpath/$(SPLIT_RUNTIME_FRAMEWORK).framework/Versions/A/$(SPLIT_RUNTIME_FRAMEWORK)
SPLIT_X64_RUNTIME_LOAD_DYLIB ?= @rpath/$(SPLIT_RUNTIME_FRAMEWORK)_x64.framework/Versions/A/$(SPLIT_RUNTIME_FRAMEWORK)
XCODEBUILD ?= xcodebuild
XCODEBUILD_SETTINGS ?=
XCODEBUILD_LOG_ON_ERROR ?=
XCODEBUILD_LOG_DIR ?=
XCODEBUILD_HEARTBEAT_SECONDS ?= 60
FRAMEWORK_SYMBOLS = python3 "$(CURDIR)/scripts/framework_symbols.py"
CC ?= cc
GODOT ?= ~/cvs/master-godot/editor/bin/godot.macos.editor.dev.arm64

STUB_BASE_DIR ?= $(CURDIR)
STUB_OUTPUT_DIR ?= $(STUB_BASE_DIR)/Generated/GodotApplePluginsStub
STUB_HEADERS_DIR ?= $(CURDIR)/.build/checkouts/SwiftGodot/Sources/GDExtension/include
STUB_ENTRY_SYMBOL ?= godot_apple_plugins_start
STUB_LIBRARY_NAME ?= godot_apple_plugins_stub
STUB_FILES ?=
STUB_GENERATOR ?= swift run GodotApplePluginsStubGenerator
SPLIT_SELECTED_FRAMEWORK_NAMES ?= $(SPLIT_FRAMEWORK_NAMES)
QUICK_FRAMEWORK ?= GodotApplePluginsGameCenter
QUICK_CONFIG ?= Debug
QUICK_DESTINATIONS ?= generic/platform=iOS generic/platform=iOS\ Simulator platform=macOS,arch=$(HOST_ARCH)
QUICK_PROJECT ?= $(HOME)/Documents/TestApplePlugins

empty :=
space := $(empty) $(empty)
comma := ,
SPLIT_SELECTED_FRAMEWORKS_ARG = $(subst $(space),$(comma),$(strip $(SPLIT_SELECTED_FRAMEWORK_NAMES)))

ifeq ($(shell uname -s),Darwin)
STUB_SHARED_EXT ?= dylib
STUB_SHARED_FLAGS ?= -dynamiclib
else
STUB_SHARED_EXT ?= so
STUB_SHARED_FLAGS ?= -shared -fPIC
endif

STUB_SHARED_LIB ?= $(STUB_OUTPUT_DIR)/$(STUB_LIBRARY_NAME).$(STUB_SHARED_EXT)
STUB_FILE_ARGS = $(foreach file,$(STUB_FILES),--file $(file))

run:
	@echo -e "Run make xcframework to produce the binary payloads for all platforms"

generate-stubs:
	@set -e; \
	echo "Generating stub sources from $(STUB_BASE_DIR)"; \
	$(STUB_GENERATOR) "$(STUB_BASE_DIR)" --output "$(STUB_OUTPUT_DIR)" --entry-symbol "$(STUB_ENTRY_SYMBOL)" --library-name "$(STUB_LIBRARY_NAME)" $(STUB_FILE_ARGS); \
	echo "Compiling stub library to $(STUB_SHARED_LIB)"; \
	$(CC) -std=c11 -Wall -Wextra -I "$(STUB_HEADERS_DIR)" $(STUB_SHARED_FLAGS) "$(STUB_OUTPUT_DIR)/$(STUB_LIBRARY_NAME).c" -o "$(STUB_SHARED_LIB)"

build build2:
	set -e; \
	run_xcodebuild() { \
		if [ -n "$(XCODEBUILD_LOG_ON_ERROR)" ]; then \
			log_dir="$(XCODEBUILD_LOG_DIR)"; \
			if [ -n "$$log_dir" ]; then \
				mkdir -p "$$log_dir"; \
			fi; \
			log_file=$$(mktemp "$${log_dir:-$${TMPDIR:-/tmp}}/xcodebuild.XXXXXX"); \
			echo "Capturing xcodebuild output to $$log_file"; \
			"$$@" >"$$log_file" 2>&1 & \
			xcodebuild_pid=$$!; \
			( \
				while kill -0 "$$xcodebuild_pid" 2>/dev/null; do \
					sleep "$(XCODEBUILD_HEARTBEAT_SECONDS)"; \
					if kill -0 "$$xcodebuild_pid" 2>/dev/null; then \
						echo "xcodebuild still running (pid $$xcodebuild_pid): $$*"; \
					fi; \
				done \
			) & \
			heartbeat_pid=$$!; \
			if wait "$$xcodebuild_pid"; then \
				status=0; \
			else \
				status=$$?; \
			fi; \
			kill "$$heartbeat_pid" 2>/dev/null || true; \
			wait "$$heartbeat_pid" 2>/dev/null || true; \
			if [ "$$status" -ne 0 ]; then \
				echo "xcodebuild failed; dumping $$log_file"; \
				cat "$$log_file"; \
				return "$$status"; \
			fi; \
			rm -f "$$log_file"; \
		else \
			"$$@"; \
		fi; \
	}; \
	swift build; \
	for dest in $(DESTINATIONS); do \
		platform_name=`echo "$$dest" | sed -n 's/.*platform=\([^,]*\).*/\1/p'`; \
		if [ -z "$$platform_name" ]; then \
			platform_name="iOS"; \
		fi; \
		platform_lc=`echo "$$platform_name" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'`; \
		arch_name=`echo $$dest | sed -n 's/.*arch=\([a-zA-Z0-9_]*\).*/\1/p'`; \
		suffix=""; \
		if [ -z "$$arch_name" ] && [ "$$platform_lc" = "ios" ]; then \
			arch_name="arm64"; \
		fi; \
		if [ -z "$$arch_name" ] && [ "$$platform_lc" = "iossimulator" ]; then \
			arch_name="$(HOST_ARCH)"; \
		fi; \
		if [ -z "$$arch_name" ] && [ "$$platform_lc" = "macos" ]; then \
			arch_name=`uname -m`; \
		fi; \
		if [ "$$platform_lc" = "iossimulator" ]; then \
			suffix="simulator"; \
		fi; \
		if [ "$$platform_lc" = "macos" ]; then \
			suffix="$$arch_name"; \
		fi; \
	    for framework in $(FRAMEWORK_NAMES); do \
			echo "Building $$framework for $$dest"; \
			run_xcodebuild $(XCODEBUILD) \
				-workspace '$(WORKSPACE)' \
				-scheme $$framework \
				-configuration '$(CONFIG)' \
				-destination "$$dest" \
				-derivedDataPath "$(DERIVED_DATA)$$suffix" \
				GCC_GENERATE_DEBUGGING_SYMBOLS=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
				$(XCODEBUILD_SETTINGS) \
				build; \
			echo "Built $$framework for $$dest"; \
			if [ "$$platform_lc" = "ios" ] || [ "$$platform_lc" = "macos" ]; then \
				relink_platform="$$platform_lc"; \
				$(CURDIR)/relink_without_swiftsyntax.sh \
					--derived-data "$(DERIVED_DATA)$$suffix" \
					--config "$(CONFIG)" \
					--framework $$framework \
					--platform $$relink_platform \
					--arch $$arch_name; \
			else \
				echo "Skipping SwiftSyntax relink for $$framework on $$dest (unsupported platform)"; \
			fi; \
			products_config="$(CONFIG)"; \
			case "$$platform_lc" in \
				ios) products_config="$(CONFIG)-iphoneos" ;; \
				iossimulator) products_config="$(CONFIG)-iphonesimulator" ;; \
			esac; \
			$(FRAMEWORK_SYMBOLS) generate "$(DERIVED_DATA)$$suffix/Build/Products/$$products_config/PackageFrameworks/$$framework.framework"; \
	    done;  \
	done; \

check_swiftsyntax:
	set -e; \
	pattern='SwiftSyntax|SwiftParser|SwiftDiagnostics|SwiftParserDiagnostics|SwiftBasicFormat|_SwiftSyntaxCShims'; \
	failed=0; \
	check_one() { \
		sdk="$$1"; bin="$$2"; label="$$3"; \
		if [ ! -f "$$bin" ]; then \
			echo "SKIP: $$label (missing: $$bin)"; \
			return 0; \
		fi; \
		if xcrun --sdk "$$sdk" nm -gU "$$bin" 2>/dev/null | grep -Eq "$$pattern"; then \
			echo "FAIL: $$label still contains SwiftSyntax-related symbols"; \
			failed=1; \
		else \
			echo "OK:   $$label"; \
		fi; \
	}; \
	for framework in $(FRAMEWORK_NAMES); do \
		check_one iphoneos "$(DERIVED_DATA)/Build/Products/$(CONFIG)-iphoneos/PackageFrameworks/$$framework.framework/$$framework" "iOS/$$framework"; \
		check_one macosx "$(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$$framework.framework/$$framework" "macOS arm64/$$framework"; \
		check_one macosx "$(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$$framework.framework/$$framework" "macOS x86_64/$$framework"; \
	done; \
	test "$$failed" -eq 0

package: split-package

split-generate-stubs:
	@set -e; \
	for framework in $(SPLIT_FRAMEWORK_NAMES); do \
		case "$$framework" in \
			GodotApplePluginsAVFoundation) \
				entry_symbol="godot_apple_plugins_avfoundation_start"; \
				library_name="godot_apple_plugins_avfoundation_stub"; \
				files="AVAudioSession"; \
				;; \
			GodotApplePluginsFoundation) \
				entry_symbol="godot_apple_plugins_foundation_start"; \
				library_name="godot_apple_plugins_foundation_stub"; \
				files="Foundation AppleURL AppleFilePicker NSUbiquitousKeyValueStore"; \
				;; \
			GodotApplePluginsGameCenter) \
				entry_symbol="godot_apple_plugins_game_center_start"; \
				library_name="godot_apple_plugins_game_center_stub"; \
				files="GameCenterManager GKAccessPoint GKAchievement GKAchievementChallenge GKAchievementDescription GKChallenge GKChallengeDefinition GKGameCenterViewController GKGameActivity GKGameActivityDefinition GKLocalPlayer GKLeaderboard GKLeaderboardEntry GKLeaderboardScore GKLeaderboardSet GKInvite GKMatch GKMatchmaker GKMatchmakerViewController GKMatchRequest GKNotificationBanner GKScoreChallenge GKTurnBasedExchange GKTurnBasedExchangeReply GKTurnBasedMatch GKTurnBasedMatchmakerViewController GKTurnBasedParticipant GKVoiceChat GKPlayer GKSavedGame GKError"; \
				;; \
			GodotApplePluginsStoreKit) \
				entry_symbol="godot_apple_plugins_storekit_start"; \
				library_name="godot_apple_plugins_storekit_stub"; \
				files="ProductView StoreProduct StoreProductPurchaseOption StoreProductSubscriptionOffer StoreProductPaymentMode StoreProductSubscriptionPeriod StoreSubscriptionInfo StoreSubscriptionInfoStatus StoreSubscriptionInfoRenewalInfo StoreTransaction StoreKitManager StoreView SubscriptionOfferView SubscriptionStoreView"; \
				;; \
			GodotApplePluginsAuthenticationServices) \
				entry_symbol="godot_apple_plugins_authentication_services_start"; \
				library_name="godot_apple_plugins_authentication_services_stub"; \
				files="ASAuthorizationAppleIDCredential ASPasswordCredential ASAuthorizationController ASWebAuthenticationSession"; \
				;; \
			GodotApplePluginsARKit) \
				entry_symbol="godot_apple_plugins_arkit_start"; \
				library_name="godot_apple_plugins_arkit_stub"; \
				files="ARSession ARWorldTrackingConfiguration ARFrame ARCamera ARLightEstimate ARPointCloud ARAnchor ARPlaneAnchor ARRaycastQuery ARRaycastResult ARTrackedRaycast ARImageAnchor ARMeshAnchor ARFaceAnchor ARWorldMap ARBodyTrackingConfiguration ARBodyAnchor ARBodySkeleton ARHandAnchor ARHandSkeleton ARCoachingOverlay AREnvironmentProbeAnchor ARGeoTrackingConfiguration ARGeoAnchor ARCollaborationData"; \
				;; \
			GodotApplePluginsCoreMotion) \
				entry_symbol="godot_apple_plugins_core_motion_start"; \
				library_name="godot_apple_plugins_core_motion_stub"; \
				files="CMAccelerometerData CMDeviceMotion CMMotionManager CMPedometer CMAltimeter CMMotionActivity CMHeadphoneMotionManager"; \
				;; \
			GodotApplePluginsKeychain) \
				entry_symbol="godot_apple_plugins_keychain_start"; \
				library_name="godot_apple_plugins_keychain_stub"; \
				files="Keychain"; \
				;; \
			*) \
				echo "Unknown split framework $$framework" >&2; \
				exit 1; \
				;; \
		esac; \
		output_dir="$(CURDIR)/Generated/$${framework}Stub"; \
		echo "Generating stub sources for $$framework into $$output_dir"; \
		args=""; \
		for file in $$files; do \
			args="$$args --file $$file"; \
		done; \
		eval $(STUB_GENERATOR) '"$(CURDIR)"' --output '"$$output_dir"' --entry-symbol '"$$entry_symbol"' --library-name '"$$library_name"' $$args; \
	done

split-build:
	$(MAKE) build FRAMEWORK_NAMES="$(SPLIT_FRAMEWORK_NAMES)"

split-dist:
	$(MAKE) split-generate-stubs
	$(MAKE) dist FRAMEWORK_NAMES="$(SPLIT_FRAMEWORK_NAMES)"
	set -e; \
	rm -rf $(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).xcframework; \
	rm -rf $(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).framework; \
	rm -rf $(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK)_x64.framework; \
	mkdir -p $(CURDIR)/addons/GodotApplePluginsRuntime/bin; \
	runtime_ios_device="$(DERIVED_DATA)/Build/Products/$(CONFIG)-iphoneos/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	runtime_ios_sim="$(DERIVED_DATA)simulator/Build/Products/$(CONFIG)-iphonesimulator/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	if [ ! -d "$$runtime_ios_device" ] || [ ! -d "$$runtime_ios_sim" ]; then \
		echo "Missing $(SPLIT_RUNTIME_FRAMEWORK) iOS build products. Run make split-build before make split-dist." >&2; \
		echo "  $$runtime_ios_device" >&2; \
		echo "  $$runtime_ios_sim" >&2; \
		exit 1; \
	fi; \
	$(FRAMEWORK_SYMBOLS) xcframework \
		"$(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).xcframework" \
		"$$runtime_ios_device" "$$runtime_ios_sim" --xcodebuild "$(XCODEBUILD)" \
		--allow-missing-symbols --search-root "$(DERIVED_DATA)" --search-root "$(DERIVED_DATA)simulator" --search-root "$(CURDIR)/.build/artifacts"; \
	if [ ! -d "$(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework" ]; then \
		echo "Missing $(SPLIT_RUNTIME_FRAMEWORK) macOS x86_64 build product. Run split-build for platform=macOS,arch=x86_64 before split-dist." >&2; \
		exit 1; \
	fi; \
	rsync -a $(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework/ $(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK)_x64.framework; \
	$(FRAMEWORK_SYMBOLS) copy "$(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework" \
		"$(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK)_x64.framework.dSYM" \
		--allow-missing-symbols --search-root "$(DERIVED_DATA)x86_64" --search-root "$(CURDIR)/.build/artifacts"; \
	runtime_x64_binary="$(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK)_x64.framework/Versions/A/$(SPLIT_RUNTIME_FRAMEWORK)"; \
	if [ ! -f "$$runtime_x64_binary" ]; then \
		echo "Missing $(SPLIT_RUNTIME_FRAMEWORK) macOS x86_64 runtime binary: $$runtime_x64_binary" >&2; \
		exit 1; \
	fi; \
	install_name_tool -id "$(SPLIT_X64_RUNTIME_LOAD_DYLIB)" "$$runtime_x64_binary"; \
	if ! otool -D "$$runtime_x64_binary" | grep -Fq "$(SPLIT_X64_RUNTIME_LOAD_DYLIB)"; then \
		echo "Failed to set x86_64 runtime install name on $$runtime_x64_binary" >&2; \
		exit 1; \
	fi; \
	if [ ! -d "$(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework" ]; then \
		echo "Missing $(SPLIT_RUNTIME_FRAMEWORK) macOS arm64 build product. Run split-build for platform=macOS,arch=arm64 before split-dist." >&2; \
		exit 1; \
	fi; \
	rsync -a $(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework/ $(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).framework; \
	$(FRAMEWORK_SYMBOLS) copy "$(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework" \
		"$(CURDIR)/addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).framework.dSYM" \
		--allow-missing-symbols --search-root "$(DERIVED_DATA)arm64" --search-root "$(CURDIR)/.build/artifacts"; \
	has_rpath() { \
		binary="$$1"; \
		rpath="$$2"; \
		otool -l "$$binary" | grep -Fq "path $$rpath "; \
	}; \
	set_runtime_rpath() { \
		binary="$$1"; \
		old_rpath="$$2"; \
		runtime_framework="$$3"; \
		runtime_load_dylib="$$4"; \
		new_rpath="$(SPLIT_RUNTIME_RPATH)"; \
		framework_rpath="$(SPLIT_RUNTIME_FRAMEWORK_RPATH)"; \
		if [ "$$runtime_load_dylib" != "$(SPLIT_RUNTIME_LOAD_DYLIB)" ] && otool -L "$$binary" | grep -Fq "$(SPLIT_RUNTIME_LOAD_DYLIB)"; then \
			install_name_tool -change "$(SPLIT_RUNTIME_LOAD_DYLIB)" "$$runtime_load_dylib" "$$binary"; \
		fi; \
		if ! has_rpath "$$binary" "$$new_rpath"; then \
			if has_rpath "$$binary" "$$old_rpath"; then \
				install_name_tool -rpath "$$old_rpath" "$$new_rpath" "$$binary"; \
			else \
				install_name_tool -add_rpath "$$new_rpath" "$$binary"; \
			fi; \
		fi; \
		if ! has_rpath "$$binary" "$$framework_rpath"; then \
			install_name_tool -add_rpath "$$framework_rpath" "$$binary"; \
		fi; \
		if [ "$$old_rpath" != "$$new_rpath" ] && [ "$$old_rpath" != "$$framework_rpath" ] && has_rpath "$$binary" "$$old_rpath"; then \
			install_name_tool -delete_rpath "$$old_rpath" "$$binary"; \
		fi; \
		if ! has_rpath "$$binary" "$$new_rpath"; then \
			echo "Failed to set runtime rpath on $$binary" >&2; \
			exit 1; \
		fi; \
		if ! has_rpath "$$binary" "$$framework_rpath"; then \
			echo "Failed to set framework-root runtime rpath on $$binary" >&2; \
			exit 1; \
		fi; \
		validate_runtime_rpath() { \
			loader_binary="$$1"; \
			rpath="$$2"; \
			if ! runtime_dir=$$(cd "$$(dirname "$$loader_binary")/$${rpath#@loader_path/}" 2>/dev/null && pwd -P); then \
				echo "Runtime rpath does not resolve from $$loader_binary: $$rpath" >&2; \
				exit 1; \
			fi; \
			if [ ! -f "$$runtime_dir/$$runtime_framework/Versions/A/$(SPLIT_RUNTIME_FRAMEWORK)" ]; then \
				echo "Runtime framework is not reachable from $$loader_binary via $$rpath" >&2; \
				echo "Missing: $$runtime_dir/$$runtime_framework/Versions/A/$(SPLIT_RUNTIME_FRAMEWORK)" >&2; \
				exit 1; \
			fi; \
		}; \
		framework_binary="$$(dirname "$$binary")/../../$$(basename "$$binary")"; \
		if [ ! -f "$$framework_binary" ]; then \
			echo "Missing framework-root binary symlink: $$framework_binary" >&2; \
			exit 1; \
		fi; \
		validate_runtime_rpath "$$binary" "$$new_rpath"; \
		validate_runtime_rpath "$$framework_binary" "$$framework_rpath"; \
		if ! otool -L "$$binary" | grep -Fq "$$runtime_load_dylib"; then \
			echo "Runtime load command is not set on $$binary: $$runtime_load_dylib" >&2; \
			exit 1; \
		fi; \
	}; \
	for framework in $(SPLIT_FRAMEWORK_NAMES); do \
		binary_arm="$(CURDIR)/addons/$$framework/bin/$$framework.framework/Versions/A/$$framework"; \
		binary_x64="$(CURDIR)/addons/$$framework/bin/$${framework}_x64.framework/Versions/A/$$framework"; \
		if [ ! -f "$$binary_arm" ]; then \
			echo "Missing macOS arm64 split framework binary: $$binary_arm" >&2; \
			exit 1; \
		fi; \
		if [ ! -f "$$binary_x64" ]; then \
			echo "Missing macOS x86_64 split framework binary: $$binary_x64" >&2; \
			exit 1; \
		fi; \
		set_runtime_rpath "$$binary_arm" "$(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks" "$(SPLIT_RUNTIME_FRAMEWORK).framework" "$(SPLIT_RUNTIME_LOAD_DYLIB)"; \
		set_runtime_rpath "$$binary_x64" "$(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks" "$(SPLIT_RUNTIME_FRAMEWORK)_x64.framework" "$(SPLIT_X64_RUNTIME_LOAD_DYLIB)"; \
	done

split-package: split-build split-dist

split-validate-built:
	@set -e; \
	project_dir=$$(mktemp -d "$${TMPDIR:-/tmp}/godot-split-validate.XXXXXX"); \
	trap 'rm -rf "$$project_dir"' EXIT INT TERM; \
	rsync -a --delete --exclude addons test-apple-godot-api/ "$$project_dir"/; \
	mkdir -p "$$project_dir/addons"; \
	rsync -a --delete "$(CURDIR)/addons/GodotApplePluginsRuntime/" "$$project_dir/addons/GodotApplePluginsRuntime/"; \
	for addon in $(SPLIT_SELECTED_FRAMEWORK_NAMES); do \
		rsync -a --delete "$(CURDIR)/addons/$$addon/" "$$project_dir/addons/$$addon/"; \
	done; \
	$(GODOT) --headless --path "$$project_dir" --scene res://split_validation.tscn -- --frameworks=$(SPLIT_SELECTED_FRAMEWORKS_ARG)

split-validate: split-package split-validate-built

split-validate-matrix: split-package
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsAVFoundation"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsFoundation"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsGameCenter"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsStoreKit"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsAuthenticationServices"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsARKit"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsCoreMotion"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="GodotApplePluginsKeychain"
	$(MAKE) split-validate-built SPLIT_SELECTED_FRAMEWORK_NAMES="$(SPLIT_FRAMEWORK_NAMES)"

split-smoke: split-validate

dist:
	set -e; \
	copy_framework_docs() { \
		framework="$$1"; \
		destination="$$2"; \
		case "$$framework" in \
			GodotApplePluginsAVFoundation) \
				registration_source="Sources/GodotAVFoundation/GodotAVFoundation.swift"; \
				;; \
			GodotApplePluginsFoundation) \
				registration_source="Sources/GodotFoundation/GodotFoundation.swift"; \
				;; \
			GodotApplePluginsGameCenter) \
				registration_source="Sources/GodotGameCenter/GodotGameCenter.swift"; \
				;; \
			GodotApplePluginsStoreKit) \
				registration_source="Sources/GodotStoreKit/GodotStoreKit.swift"; \
				;; \
			GodotApplePluginsAuthenticationServices) \
				registration_source="Sources/GodotAuthenticationServices/GodotAuthenticationServices.swift"; \
				;; \
			GodotApplePluginsARKit) \
				registration_source="Sources/GodotARKit/GodotARKit.swift"; \
				;; \
			GodotApplePluginsCoreMotion) \
				registration_source="Sources/GodotCoreMotion/GodotCoreMotion.swift"; \
				;; \
			GodotApplePluginsKeychain) \
				registration_source="Sources/GodotKeychain/GodotKeychain.swift"; \
				;; \
			*) \
				registration_source=""; \
				;; \
		esac; \
		rm -rf "$$destination"; \
		mkdir -p "$$destination"; \
		if [ -z "$$registration_source" ]; then \
			rsync -a doc_classes/ "$$destination"/; \
		else \
			doc_files=$$(sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)\.self,.*/\1/p' "$$registration_source"); \
			for file in $$doc_files; do \
				if [ -f "doc_classes/$$file.xml" ]; then \
					rsync -a "doc_classes/$$file.xml" "$$destination"/; \
				fi; \
			done; \
		fi; \
	}; \
	for framework in $(FRAMEWORK_NAMES); do \
		rm -rf $(CURDIR)/addons/$$framework/bin/$$framework.xcframework; \
		rm -rf $(CURDIR)/addons/$$framework/bin/$$framework*.framework; \
		if [ -d "$(DERIVED_DATA)/Build/Products/$(CONFIG)-iphoneos/PackageFrameworks/$$framework.framework" ] && [ -d "$(DERIVED_DATA)simulator/Build/Products/$(CONFIG)-iphonesimulator/PackageFrameworks/$$framework.framework" ]; then \
			$(FRAMEWORK_SYMBOLS) xcframework "$(CURDIR)/addons/$$framework/bin/$${framework}.xcframework" \
				"$(DERIVED_DATA)/Build/Products/$(CONFIG)-iphoneos/PackageFrameworks/$$framework.framework" \
				"$(DERIVED_DATA)simulator/Build/Products/$(CONFIG)-iphonesimulator/PackageFrameworks/$$framework.framework" \
				--xcodebuild "$(XCODEBUILD)"; \
		fi; \
		if [ -d "$(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$${framework}.framework" ]; then \
			rsync -a $(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$${framework}.framework/ $(CURDIR)/addons/$$framework/bin/$${framework}_x64.framework; \
			$(FRAMEWORK_SYMBOLS) copy "$(DERIVED_DATA)x86_64/Build/Products/$(CONFIG)/PackageFrameworks/$${framework}.framework" \
				"$(CURDIR)/addons/$$framework/bin/$${framework}_x64.framework.dSYM"; \
			copy_framework_docs "$$framework" "$(CURDIR)/addons/$$framework/bin/$${framework}_x64.framework/Resources/doc_classes"; \
		fi; \
		if [ -d "$(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$${framework}.framework" ]; then \
			rsync -a $(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$${framework}.framework/ $(CURDIR)/addons/$$framework/bin/$${framework}.framework; \
			$(FRAMEWORK_SYMBOLS) copy "$(DERIVED_DATA)arm64/Build/Products/$(CONFIG)/PackageFrameworks/$${framework}.framework" \
				"$(CURDIR)/addons/$$framework/bin/$${framework}.framework.dSYM"; \
			copy_framework_docs "$$framework" "$(CURDIR)/addons/$$framework/bin/$${framework}.framework/Resources/doc_classes"; \
		fi; \
	done

XCFRAMEWORK_GODOTAPPLEPLUGINS ?= $(CURDIR)/addons/GodotApplePlugins/bin/GodotApplePlugins.xcframework
DOCS_REMOTE ?= origin
DOCS_BRANCH ?= docs
DOCS_DEPLOY_DIR ?= docs

justgen:
	(cd test-apple-godot-api; ~/cvs/master-godot/editor/bin/godot.macos.editor.dev.arm64 --headless --path . --doctool .. --gdextension-docs)

gendocs docs-html: justgen
	./fix_doc_enums.sh
	$(MAKE) -C doctools html $(if $(GODOT_DOCS_SOURCE),GODOT_DOCS_SOURCE="$(GODOT_DOCS_SOURCE)") $(if $(HTML_OUTPUT),HTML_OUTPUT="$(HTML_OUTPUT)")

deploy-docs:
	@set -eu; \
	site_dir="$$(mktemp -d "$${TMPDIR:-/tmp}/godotappleplugins-site.XXXXXX")"; \
	worktree_dir="$$(mktemp -d "$${TMPDIR:-/tmp}/godotappleplugins-worktree.XXXXXX")"; \
	cleanup() { \
		git worktree remove --force "$$worktree_dir" >/dev/null 2>&1 || true; \
		rm -rf "$$site_dir" "$$worktree_dir"; \
	}; \
	trap cleanup EXIT INT TERM; \
	$(MAKE) docs-html HTML_OUTPUT="$$site_dir" $(if $(GODOT_DOCS_SOURCE),GODOT_DOCS_SOURCE="$(GODOT_DOCS_SOURCE)"); \
	git fetch "$(DOCS_REMOTE)" "$(DOCS_BRANCH)" >/dev/null 2>&1 || true; \
	if ! git rev-parse --verify --quiet "$(DOCS_REMOTE)/$(DOCS_BRANCH)" >/dev/null; then \
		echo "Missing branch $(DOCS_REMOTE)/$(DOCS_BRANCH)"; \
		exit 1; \
	fi; \
	git worktree add --detach "$$worktree_dir" "$(DOCS_REMOTE)/$(DOCS_BRANCH)"; \
	mkdir -p "$$worktree_dir/$(DOCS_DEPLOY_DIR)"; \
	rsync -a --delete "$$site_dir"/ "$$worktree_dir/$(DOCS_DEPLOY_DIR)/"; \
	if [ -z "$$(git -C "$$worktree_dir" status --short -- "$(DOCS_DEPLOY_DIR)")" ]; then \
		echo "No docs changes to publish."; \
		exit 0; \
	fi; \
	git -C "$$worktree_dir" add "$(DOCS_DEPLOY_DIR)"; \
	git -C "$$worktree_dir" commit -m "Update generated docs for $$(git rev-parse --short HEAD)"; \
	git -C "$$worktree_dir" push "$(DOCS_REMOTE)" HEAD:refs/heads/$(DOCS_BRANCH)

#
# Quick hacks I use for rapid iteration
#
# Builds one split plugin locally, packages its Apple payloads, and copies
# the plugin plus SwiftGodot runtime payloads into a Godot test project.
o:
	$(MAKE) build \
		CONFIG="$(QUICK_CONFIG)" \
		DESTINATIONS="$(QUICK_DESTINATIONS)" \
		FRAMEWORK_NAMES="$(QUICK_FRAMEWORK)"
	$(MAKE) dist CONFIG="$(QUICK_CONFIG)" FRAMEWORK_NAMES="$(QUICK_FRAMEWORK)"
	$(MAKE) o-runtime QUICK_CONFIG="$(QUICK_CONFIG)"
	$(MAKE) o-fix-rpaths QUICK_FRAMEWORK="$(QUICK_FRAMEWORK)" QUICK_CONFIG="$(QUICK_CONFIG)"
	$(MAKE) o-sync QUICK_FRAMEWORK="$(QUICK_FRAMEWORK)" QUICK_PROJECT="$(QUICK_PROJECT)"

o-runtime:
	@set -e; \
	runtime_bin="$(CURDIR)/addons/GodotApplePluginsRuntime/bin"; \
	rm -rf "$$runtime_bin/$(SPLIT_RUNTIME_FRAMEWORK).xcframework" \
		"$$runtime_bin/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	mkdir -p "$$runtime_bin"; \
	runtime_ios_device="$(DERIVED_DATA)/Build/Products/$(QUICK_CONFIG)-iphoneos/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	runtime_ios_sim="$(DERIVED_DATA)simulator/Build/Products/$(QUICK_CONFIG)-iphonesimulator/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	if [ -d "$$runtime_ios_device" ] && [ -d "$$runtime_ios_sim" ]; then \
		$(FRAMEWORK_SYMBOLS) xcframework "$$runtime_bin/$(SPLIT_RUNTIME_FRAMEWORK).xcframework" \
			"$$runtime_ios_device" "$$runtime_ios_sim" --xcodebuild "$(XCODEBUILD)" \
			--allow-missing-symbols --search-root "$(DERIVED_DATA)" --search-root "$(DERIVED_DATA)simulator" --search-root "$(CURDIR)/.build/artifacts"; \
	else \
		echo "Skipping runtime xcframework; missing iOS device or simulator runtime product."; \
	fi; \
	runtime_macos="$(DERIVED_DATA)$(HOST_ARCH)/Build/Products/$(QUICK_CONFIG)/PackageFrameworks/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	if [ -d "$$runtime_macos" ]; then \
		rsync -a "$$runtime_macos/" "$$runtime_bin/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
		$(FRAMEWORK_SYMBOLS) copy "$$runtime_macos" "$$runtime_bin/$(SPLIT_RUNTIME_FRAMEWORK).framework.dSYM" \
			--allow-missing-symbols --search-root "$(DERIVED_DATA)$(HOST_ARCH)" --search-root "$(CURDIR)/.build/artifacts"; \
	else \
		echo "Missing host macOS runtime product: $$runtime_macos" >&2; \
		exit 1; \
	fi

o-fix-rpaths:
	@set -e; \
	addon="$(QUICK_FRAMEWORK)"; \
	binary="$(CURDIR)/addons/$$addon/bin/$$addon.framework/Versions/A/$$addon"; \
	if [ ! -f "$$binary" ]; then \
		echo "Missing host macOS framework binary: $$binary" >&2; \
		exit 1; \
	fi; \
	has_rpath() { \
		check_binary="$$1"; \
		rpath="$$2"; \
		otool -l "$$check_binary" | grep -Fq "path $$rpath "; \
	}; \
	add_or_replace_rpath() { \
		check_binary="$$1"; \
		old_rpath="$$2"; \
		new_rpath="$$3"; \
		if ! has_rpath "$$check_binary" "$$new_rpath"; then \
			if has_rpath "$$check_binary" "$$old_rpath"; then \
				install_name_tool -rpath "$$old_rpath" "$$new_rpath" "$$check_binary"; \
			else \
				install_name_tool -add_rpath "$$new_rpath" "$$check_binary"; \
			fi; \
		fi; \
	}; \
	old_rpath="$(DERIVED_DATA)$(HOST_ARCH)/Build/Products/$(QUICK_CONFIG)/PackageFrameworks"; \
	add_or_replace_rpath "$$binary" "$$old_rpath" "$(SPLIT_RUNTIME_RPATH)"; \
	add_or_replace_rpath "$$binary" "$$old_rpath" "$(SPLIT_RUNTIME_FRAMEWORK_RPATH)"; \
	if ! otool -L "$$binary" | grep -Fq "$(SPLIT_RUNTIME_LOAD_DYLIB)"; then \
		echo "Runtime load command is not set on $$binary: $(SPLIT_RUNTIME_LOAD_DYLIB)" >&2; \
		exit 1; \
	fi

o-sync:
	@set -e; \
	addon="$(QUICK_FRAMEWORK)"; \
	project="$(QUICK_PROJECT)"; \
	target_addons="$$project/addons"; \
	if [ ! -d "$$project" ]; then \
		echo "Missing Godot project: $$project" >&2; \
		exit 1; \
	fi; \
	if [ ! -d "$(CURDIR)/addons/$$addon/bin" ]; then \
		echo "Missing packaged addon payloads for $$addon. Run make o first." >&2; \
		exit 1; \
	fi; \
	if [ ! -d "$(CURDIR)/addons/GodotApplePluginsRuntime/bin" ]; then \
		echo "Missing packaged SwiftGodot runtime payloads. Run make o first." >&2; \
		exit 1; \
	fi; \
	mkdir -p "$$target_addons/$$addon/bin" "$$target_addons/GodotApplePluginsRuntime/bin"; \
	rm -rf "$$target_addons/$$addon/bin/$$addon.xcframework" \
		"$$target_addons/$$addon/bin/$$addon.framework" \
		"$$target_addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).xcframework" \
		"$$target_addons/GodotApplePluginsRuntime/bin/$(SPLIT_RUNTIME_FRAMEWORK).framework"; \
	rsync -a "$(CURDIR)/addons/$$addon/" "$$target_addons/$$addon/"; \
	rsync -a "$(CURDIR)/addons/GodotApplePluginsRuntime/" "$$target_addons/GodotApplePluginsRuntime/"; \
	echo "Updated $$addon and GodotApplePluginsRuntime payloads in $$project"
#
# This I am using to test on the "Exported" project I placed
#
XCFRAMEWORK_EXPORT_PATH=test-apple-godot-api/demo/output/dylibs/addons/GodotApplePlugins/bin/GodotApplePlugins.xcframework
make oo:
	rm -rf $(XCFRAMEWORK_EXPORT_PATH)
	$(XCODEBUILD) -create-xcframework \
		-framework ~/DerivedData/GodotApplePlugins-*/Build/Products/Debug-iphoneos/PackageFrameworks/GodotApplePlugins.framework/ \
		-framework ~/DerivedData/GodotApplePlugins-*/Build/Products/Debug/PackageFrameworks/GodotApplePlugins.framework/ \
		-output '$(XCFRAMEWORK_EXPORT_PATH)'

clean-build:
	rm -rf $(DERIVED_DATA)* .build apple/.build Generated/GodotApplePluginsStub/*.dylib Generated/GodotApplePluginsStub/*.so

clean: clean-build
	rm -rf $(CURDIR)/addons/*/bin dist *.zip	
