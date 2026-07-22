#!/usr/bin/env python3
"""Generate Evidence.xcodeproj for the Evidence iOS app.

Walks Evidence/, EvidenceTests/, and EvidenceUITests/ for discoverable assets,
then emits an Xcode 16-style project that uses PBXFileSystemSynchronizedRootGroup
so individual Swift/resource files do not need to be listed in project.pbxproj.

Also ensures:
  - project.xcworkspace/contents.xcworkspacedata
  - Assets.xcassets scaffolding (if missing)
  - Evidence.entitlements (Sign in with Apple)
  - Evidence/Configuration/Evidence.xcconfig (optional Config.xcconfig include)

Run from repo root:
  python3 scripts/generate_xcode_project.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

APP_NAME = "Evidence"
BUNDLE_ID = "com.evidence.app"
DEPLOYMENT_TARGET = "18.0"
SWIFT_VERSION = "5.0"
SUPABASE_PACKAGE_URL = "https://github.com/supabase/supabase-swift"
SUPABASE_PACKAGE_FROM = "2.0.0"
SUPABASE_PRODUCT = "Supabase"

FACE_ID_USAGE = (
    "Evidence can lock your collection using Face ID so only you can open it."
)

# Stable 24-char hex IDs (Xcode-style). Do not change casually — regenerating
# with new IDs forces Xcode to re-resolve package state.
IDS = {
    "project": "A10000000000000000000001",
    "main_group": "A10000000000000000000002",
    "products_group": "A10000000000000000000003",
    "frameworks_group": "A10000000000000000000004",
    "config_group": "A10000000000000000000005",
    "app_product": "A10000000000000000000010",
    "tests_product": "A10000000000000000000011",
    "uitests_product": "A10000000000000000000012",
    "app_target": "A10000000000000000000020",
    "tests_target": "A10000000000000000000021",
    "uitests_target": "A10000000000000000000022",
    "app_sources": "A10000000000000000000030",
    "tests_sources": "A10000000000000000000031",
    "uitests_sources": "A10000000000000000000032",
    "app_frameworks": "A10000000000000000000033",
    "tests_frameworks": "A10000000000000000000034",
    "uitests_frameworks": "A10000000000000000000035",
    "app_resources": "A10000000000000000000036",
    "app_sync": "A10000000000000000000040",
    "tests_sync": "A10000000000000000000041",
    "uitests_sync": "A10000000000000000000042",
    "app_exceptions": "A10000000000000000000043",
    "project_configs": "A10000000000000000000050",
    "app_configs": "A10000000000000000000051",
    "tests_configs": "A10000000000000000000052",
    "uitests_configs": "A10000000000000000000053",
    "project_debug": "A10000000000000000000060",
    "project_release": "A10000000000000000000061",
    "app_debug": "A10000000000000000000062",
    "app_release": "A10000000000000000000063",
    "tests_debug": "A10000000000000000000064",
    "tests_release": "A10000000000000000000065",
    "uitests_debug": "A10000000000000000000066",
    "uitests_release": "A10000000000000000000067",
    "package_ref": "A10000000000000000000070",
    "package_product": "A10000000000000000000071",
    "xcconfig_ref": "A10000000000000000000080",
    "entitlements_ref": "A10000000000000000000081",
    "target_dep_tests": "A10000000000000000000090",
    "target_dep_uitests": "A10000000000000000000091",
    "container_proxy_tests": "A10000000000000000000092",
    "container_proxy_uitests": "A10000000000000000000093",
}

DISCOVER_EXTENSIONS = {".swift", ".json", ".xcconfig", ".xcstrings"}
DISCOVER_DIRS = {".xcassets"}


def discover(root: Path) -> dict[str, list[str]]:
    """Walk a source root and collect paths relative to ROOT."""
    found: dict[str, list[str]] = {
        "swift": [],
        "json": [],
        "xcconfig": [],
        "xcstrings": [],
        "xcassets": [],
        "other": [],
    }
    if not root.exists():
        return found

    for dirpath, dirnames, filenames in os.walk(root):
        # Keep walk stable and skip hidden / build junk.
        dirnames[:] = sorted(
            d for d in dirnames if not d.startswith(".") and d not in {"DerivedData", "build"}
        )
        rel_dir = Path(dirpath).relative_to(ROOT)

        # Record asset catalogs at the catalog root only.
        for d in list(dirnames):
            if d.endswith(".xcassets"):
                found["xcassets"].append(str(rel_dir / d))
                # Do not descend into Contents.json noise for discovery summary.
                dirnames.remove(d)

        for name in sorted(filenames):
            if name.startswith("."):
                continue
            path = rel_dir / name
            suffix = path.suffix.lower()
            if suffix == ".swift":
                found["swift"].append(str(path))
            elif suffix == ".json":
                found["json"].append(str(path))
            elif suffix == ".xcconfig":
                found["xcconfig"].append(str(path))
            elif suffix == ".xcstrings":
                found["xcstrings"].append(str(path))
            else:
                found["other"].append(str(path))
    return found


def ensure_assets() -> None:
    assets = ROOT / "Evidence" / "Resources" / "Assets.xcassets"
    app_icon = assets / "AppIcon.appiconset"
    accent = assets / "AccentColor.colorset"

    assets.mkdir(parents=True, exist_ok=True)
    app_icon.mkdir(parents=True, exist_ok=True)
    accent.mkdir(parents=True, exist_ok=True)

    catalog = assets / "Contents.json"
    if not catalog.exists():
        catalog.write_text(
            json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
            encoding="utf-8",
        )

    icon_contents = app_icon / "Contents.json"
    if not icon_contents.exists():
        icon_contents.write_text(
            json.dumps(
                {
                    "images": [
                        {
                            "idiom": "universal",
                            "platform": "ios",
                            "size": "1024x1024",
                        }
                    ],
                    "info": {"author": "xcode", "version": 1},
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    accent_contents = accent / "Contents.json"
    if not accent_contents.exists():
        accent_contents.write_text(
            json.dumps(
                {
                    "colors": [
                        {
                            "color": {
                                "color-space": "srgb",
                                "components": {
                                    "alpha": "1.000",
                                    "blue": "0.400",
                                    "green": "0.420",
                                    "red": "0.280",
                                },
                            },
                            "idiom": "universal",
                        }
                    ],
                    "info": {"author": "xcode", "version": 1},
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )


def ensure_entitlements() -> None:
    path = ROOT / "Evidence" / "Evidence.entitlements"
    if path.exists():
        return
    path.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
""",
        encoding="utf-8",
    )


def ensure_shared_xcconfig() -> None:
    path = ROOT / "Evidence" / "Configuration" / "Evidence.xcconfig"
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        return
    path.write_text(
        "// Shared build settings for Evidence.\n"
        "// Copy Config.example.xcconfig → Config.xcconfig (gitignored).\n"
        "\n"
        "SUPABASE_URL =\n"
        "SUPABASE_ANON_KEY =\n"
        "\n"
        '#include? "Config.xcconfig"\n',
        encoding="utf-8",
    )


def escape_pbx(value: str) -> str:
    specials = set(' \t\n\r"$&\'()*+,/:;<=>?@[\\]^`{|}#')
    if not value or any(ch in specials for ch in value):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return value


def build_settings_block(settings: dict[str, str], indent: str = "\t\t\t\t") -> str:
    lines = ["\t\t\tbuildSettings = {"]
    for key in sorted(settings.keys()):
        lines.append(f"{indent}{key} = {escape_pbx(settings[key])};")
    lines.append("\t\t\t};")
    return "\n".join(lines)


def common_project_settings(debug: bool) -> dict[str, str]:
    settings = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    if debug:
        settings.update(
            {
                "DEBUG_INFORMATION_FORMAT": "dwarf",
                "ENABLE_TESTABILITY": "YES",
                "GCC_OPTIMIZATION_LEVEL": "0",
                "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG=1",
                "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
                "ONLY_ACTIVE_ARCH": "YES",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            }
        )
    else:
        settings.update(
            {
                "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                "ENABLE_NS_ASSERTIONS": "NO",
                "MTL_ENABLE_DEBUG_INFO": "NO",
                "SWIFT_COMPILATION_MODE": "wholemodule",
                "VALIDATE_PRODUCT": "YES",
            }
        )
    return settings


def app_target_settings(debug: bool) -> dict[str, str]:
    settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_ENTITLEMENTS": "Evidence/Evidence.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": "Evidence",
        "INFOPLIST_KEY_NSFaceIDUsageDescription": FACE_ID_USAGE,
        "INFOPLIST_KEY_SUPABASE_ANON_KEY": "$(SUPABASE_ANON_KEY)",
        "INFOPLIST_KEY_SUPABASE_URL": "$(SUPABASE_URL)",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": (
            "UIInterfaceOrientationPortrait "
            "UIInterfaceOrientationLandscapeLeft "
            "UIInterfaceOrientationLandscapeRight"
        ),
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": (
            "UIInterfaceOrientationPortrait "
            "UIInterfaceOrientationPortraitUpsideDown "
            "UIInterfaceOrientationLandscapeLeft "
            "UIInterfaceOrientationLandscapeRight"
        ),
        "LD_RUNPATH_SEARCH_PATHS": (
            "$(inherited) @executable_path/Frameworks"
        ),
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    if debug:
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    return settings


def tests_target_settings(debug: bool) -> dict[str, str]:
    settings = {
        "BUNDLE_LOADER": "$(TEST_HOST)",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID}.tests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": "1,2",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Evidence.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Evidence",
    }
    if debug:
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    return settings


def uitests_target_settings(debug: bool) -> dict[str, str]:
    settings = {
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID}.uitests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SWIFT_VERSION": SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY": "1,2",
        "TEST_TARGET_NAME": "Evidence",
    }
    if debug:
        settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    return settings


def generate_pbxproj() -> str:
    i = IDS

    # Membership exceptions: config / entitlements must not be copied into the app bundle.
    exceptions = """\
		{app_exceptions} /* Exceptions for "Evidence" folder in "Evidence" target */ = {{
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Configuration/Config.example.xcconfig,
				Configuration/Config.xcconfig,
				Configuration/Evidence.xcconfig,
				Configuration/InfoPlist.example.xcconfig,
				Evidence.entitlements,
			);
			target = {app_target} /* Evidence */;
		}};
""".format(**i)

    objects = f"""\
// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 77;
	objects = {{

/* Begin PBXFileReference section */
		{i['app_product']} /* Evidence.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Evidence.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{i['tests_product']} /* EvidenceTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = EvidenceTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{i['uitests_product']} /* EvidenceUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = EvidenceUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{i['xcconfig_ref']} /* Evidence.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Evidence.xcconfig; sourceTree = "<group>"; }};
		{i['entitlements_ref']} /* Evidence.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Evidence.entitlements; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
{exceptions}/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{i['app_sync']} /* Evidence */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				{i['app_exceptions']} /* Exceptions for "Evidence" folder in "Evidence" target */,
			);
			path = Evidence;
			sourceTree = "<group>";
		}};
		{i['tests_sync']} /* EvidenceTests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = EvidenceTests;
			sourceTree = "<group>";
		}};
		{i['uitests_sync']} /* EvidenceUITests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = EvidenceUITests;
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		{i['app_frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{i['tests_frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{i['uitests_frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{i['main_group']} = {{
			isa = PBXGroup;
			children = (
				{i['app_sync']} /* Evidence */,
				{i['tests_sync']} /* EvidenceTests */,
				{i['uitests_sync']} /* EvidenceUITests */,
				{i['config_group']} /* Configuration */,
				{i['frameworks_group']} /* Frameworks */,
				{i['products_group']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{i['products_group']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{i['app_product']} /* Evidence.app */,
				{i['tests_product']} /* EvidenceTests.xctest */,
				{i['uitests_product']} /* EvidenceUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{i['frameworks_group']} /* Frameworks */ = {{
			isa = PBXGroup;
			children = (
			);
			name = Frameworks;
			sourceTree = "<group>";
		}};
		{i['config_group']} /* Configuration */ = {{
			isa = PBXGroup;
			children = (
				{i['xcconfig_ref']} /* Evidence.xcconfig */,
				{i['entitlements_ref']} /* Evidence.entitlements */,
			);
			name = Configuration;
			path = Evidence/Configuration;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{i['app_target']} /* Evidence */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {i['app_configs']} /* Build configuration list for PBXNativeTarget "Evidence" */;
			buildPhases = (
				{i['app_sources']} /* Sources */,
				{i['app_frameworks']} /* Frameworks */,
				{i['app_resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				{i['app_sync']} /* Evidence */,
			);
			name = Evidence;
			packageProductDependencies = (
				{i['package_product']} /* Supabase */,
			);
			productName = Evidence;
			productReference = {i['app_product']} /* Evidence.app */;
			productType = "com.apple.product-type.application";
		}};
		{i['tests_target']} /* EvidenceTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {i['tests_configs']} /* Build configuration list for PBXNativeTarget "EvidenceTests" */;
			buildPhases = (
				{i['tests_sources']} /* Sources */,
				{i['tests_frameworks']} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				{i['target_dep_tests']} /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				{i['tests_sync']} /* EvidenceTests */,
			);
			name = EvidenceTests;
			packageProductDependencies = (
			);
			productName = EvidenceTests;
			productReference = {i['tests_product']} /* EvidenceTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
		{i['uitests_target']} /* EvidenceUITests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {i['uitests_configs']} /* Build configuration list for PBXNativeTarget "EvidenceUITests" */;
			buildPhases = (
				{i['uitests_sources']} /* Sources */,
				{i['uitests_frameworks']} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				{i['target_dep_uitests']} /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				{i['uitests_sync']} /* EvidenceUITests */,
			);
			name = EvidenceUITests;
			packageProductDependencies = (
			);
			productName = EvidenceUITests;
			productReference = {i['uitests_product']} /* EvidenceUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{i['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{i['app_target']} = {{
						CreatedOnToolsVersion = 16.0;
					}};
					{i['tests_target']} = {{
						CreatedOnToolsVersion = 16.0;
						TestTargetID = {i['app_target']};
					}};
					{i['uitests_target']} = {{
						CreatedOnToolsVersion = 16.0;
						TestTargetID = {i['app_target']};
					}};
				}};
			}};
			buildConfigurationList = {i['project_configs']} /* Build configuration list for PBXProject "Evidence" */;
			compatibilityVersion = "Xcode 16.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {i['main_group']};
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				{i['package_ref']} /* XCRemoteSwiftPackageReference "supabase-swift" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = {i['products_group']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{i['app_target']} /* Evidence */,
				{i['tests_target']} /* EvidenceTests */,
				{i['uitests_target']} /* EvidenceUITests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{i['app_resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{i['app_sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{i['tests_sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{i['uitests_sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXContainerItemProxy section */
		{i['container_proxy_tests']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {i['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {i['app_target']};
			remoteInfo = Evidence;
		}};
		{i['container_proxy_uitests']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {i['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {i['app_target']};
			remoteInfo = Evidence;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXTargetDependency section */
		{i['target_dep_tests']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {i['app_target']} /* Evidence */;
			targetProxy = {i['container_proxy_tests']} /* PBXContainerItemProxy */;
		}};
		{i['target_dep_uitests']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {i['app_target']} /* Evidence */;
			targetProxy = {i['container_proxy_uitests']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		{i['project_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(common_project_settings(True).items()))}
			}};
			name = Debug;
		}};
		{i['project_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(common_project_settings(False).items()))}
			}};
			name = Release;
		}};
		{i['app_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = {i['xcconfig_ref']} /* Evidence.xcconfig */;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(app_target_settings(True).items()))}
			}};
			name = Debug;
		}};
		{i['app_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			baseConfigurationReference = {i['xcconfig_ref']} /* Evidence.xcconfig */;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(app_target_settings(False).items()))}
			}};
			name = Release;
		}};
		{i['tests_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(tests_target_settings(True).items()))}
			}};
			name = Debug;
		}};
		{i['tests_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(tests_target_settings(False).items()))}
			}};
			name = Release;
		}};
		{i['uitests_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(uitests_target_settings(True).items()))}
			}};
			name = Debug;
		}};
		{i['uitests_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{chr(10).join(f'{chr(9)*4}{k} = {escape_pbx(v)};' for k, v in sorted(uitests_target_settings(False).items()))}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{i['project_configs']} /* Build configuration list for PBXProject "Evidence" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{i['project_debug']} /* Debug */,
				{i['project_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{i['app_configs']} /* Build configuration list for PBXNativeTarget "Evidence" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{i['app_debug']} /* Debug */,
				{i['app_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{i['tests_configs']} /* Build configuration list for PBXNativeTarget "EvidenceTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{i['tests_debug']} /* Debug */,
				{i['tests_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{i['uitests_configs']} /* Build configuration list for PBXNativeTarget "EvidenceUITests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{i['uitests_debug']} /* Debug */,
				{i['uitests_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
		{i['package_ref']} /* XCRemoteSwiftPackageReference "supabase-swift" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "{SUPABASE_PACKAGE_URL}";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = {SUPABASE_PACKAGE_FROM};
			}};
		}};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{i['package_product']} /* Supabase */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {i['package_ref']} /* XCRemoteSwiftPackageReference "supabase-swift" */;
			productName = {SUPABASE_PRODUCT};
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {i['project']} /* Project object */;
}}
"""
    # Fix entitlements path: Configuration group path is Evidence/Configuration but
    # entitlements live in Evidence/. Use a sibling-relative fix via file ref path.
    # The entitlements PBXFileReference path is just "Evidence.entitlements" under
    # Configuration group which is wrong. Fix by pointing group children correctly.
    #
    # Regenerating with corrected Configuration group: only xcconfig there;
    # entitlements referenced by CODE_SIGN_ENTITLEMENTS path string is enough.
    return objects.replace(
        f"""		{i['config_group']} /* Configuration */ = {{
			isa = PBXGroup;
			children = (
				{i['xcconfig_ref']} /* Evidence.xcconfig */,
				{i['entitlements_ref']} /* Evidence.entitlements */,
			);
			name = Configuration;
			path = Evidence/Configuration;
			sourceTree = "<group>";
		}};""",
        f"""		{i['config_group']} /* Configuration */ = {{
			isa = PBXGroup;
			children = (
				{i['xcconfig_ref']} /* Evidence.xcconfig */,
			);
			name = Configuration;
			path = Evidence/Configuration;
			sourceTree = "<group>";
		}};""",
    ).replace(
        f"""		{i['entitlements_ref']} /* Evidence.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Evidence.entitlements; sourceTree = "<group>"; }};
""",
        "",
    )


def write_workspace() -> None:
    workspace = ROOT / "Evidence.xcodeproj" / "project.xcworkspace"
    workspace.mkdir(parents=True, exist_ok=True)
    contents = workspace / "contents.xcworkspacedata"
    contents.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
        encoding="utf-8",
    )


def print_discovery_summary(label: str, found: dict[str, list[str]]) -> None:
    print(f"  {label}:")
    print(f"    .swift     {len(found['swift'])}")
    print(f"    .json      {len(found['json'])}")
    print(f"    .xcconfig  {len(found['xcconfig'])}")
    print(f"    .xcstrings {len(found['xcstrings'])}")
    print(f"    .xcassets  {len(found['xcassets'])}")


def main() -> int:
    os.chdir(ROOT)

    print("Discovering sources…")
    app = discover(ROOT / "Evidence")
    tests = discover(ROOT / "EvidenceTests")
    uitests = discover(ROOT / "EvidenceUITests")
    print_discovery_summary("Evidence", app)
    print_discovery_summary("EvidenceTests", tests)
    print_discovery_summary("EvidenceUITests", uitests)

    print("Ensuring assets, entitlements, and xcconfig…")
    ensure_assets()
    ensure_entitlements()
    ensure_shared_xcconfig()

    project_dir = ROOT / "Evidence.xcodeproj"
    project_dir.mkdir(parents=True, exist_ok=True)
    pbxproj_path = project_dir / "project.pbxproj"
    pbxproj_path.write_text(generate_pbxproj(), encoding="utf-8")
    write_workspace()

    print(f"Wrote {pbxproj_path.relative_to(ROOT)}")
    print(f"Wrote {project_dir.relative_to(ROOT)}/project.xcworkspace/contents.xcworkspacedata")
    print("Done. Open Evidence.xcodeproj in Xcode 16+ on macOS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
