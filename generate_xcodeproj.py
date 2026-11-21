#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generador automático de Hefesto.xcodeproj/project.pbxproj
Compatible con Xcode 15/16 y macOS CI Runners (GitHub Actions).
"""

import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

def create_xcodeproj(project_dir="/home/snow/Hefesto"):
    xcodeproj_dir = os.path.join(project_dir, "Hefesto.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)
    pbx_path = os.path.join(xcodeproj_dir, "project.pbxproj")

    id_proj = gen_id()
    id_target = gen_id()
    id_group_main = gen_id()
    id_group_src = gen_id()
    id_group_products = gen_id()
    id_product_app = gen_id()
    id_sources_phase = gen_id()
    id_frameworks_phase = gen_id()
    id_resources_phase = gen_id()
    id_config_list_proj = gen_id()
    id_config_list_target = gen_id()
    id_debug_proj = gen_id()
    id_release_proj = gen_id()
    id_debug_target = gen_id()
    id_release_target = gen_id()

    swift_files = [
        ("HefestoApp.swift", "App/HefestoApp.swift"),
        ("BlueprintModels.swift", "Models/BlueprintModels.swift"),
        ("OdiseoAPIService.swift", "Services/OdiseoAPIService.swift"),
        ("CatalogView.swift", "Views/CatalogView.swift"),
        ("BlueprintDetailView.swift", "Views/BlueprintDetailView.swift"),
        ("SceneKitViewer.swift", "Views/SceneKitViewer.swift"),
        ("InspectorCardView.swift", "Views/InspectorCardView.swift"),
        ("ARQuickLookPresenter.swift", "Views/ARQuickLookPresenter.swift")
    ]

    file_refs = []
    build_files = []

    for name, rel_path in swift_files:
        f_id = gen_id()
        b_id = gen_id()
        file_refs.append((f_id, name, rel_path))
        build_files.append((b_id, f_id, name))

    id_plist_ref = gen_id()
    id_assets_ref = gen_id()
    id_assets_build = gen_id()

    content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
"""
    for b_id, f_id, name in build_files:
        content += f"\t\t{b_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {name} */; }};\n"
    content += f"\t\t{id_assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {id_assets_ref} /* Assets.xcassets */; }};\n"

    content += """/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t""" + f"{id_product_app} /* Hefesto.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Hefesto.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    for f_id, name, rel_path in file_refs:
        content += f"\t\t{f_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{rel_path}\"; sourceTree = \"<group>\"; }};\n"
    content += f"\t\t{id_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
    content += f"\t\t{id_assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};\n"

    content += """/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t""" + f"{id_frameworks_phase} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n"
    content += """/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t""" + f"{id_group_main} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{id_group_src} /* Hefesto */,\n\t\t\t\t{id_group_products} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
    
    content += f"\t\t{id_group_products} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{id_product_app} /* Hefesto.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"

    src_children = "\n".join([f"\t\t\t\t{f_id} /* {name} */," for f_id, name, _ in file_refs])
    content += f"\t\t{id_group_src} /* Hefesto */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{src_children}\n\t\t\t\t{id_assets_ref} /* Assets.xcassets */,\n\t\t\t\t{id_plist_ref} /* Info.plist */,\n\t\t\t);\n\t\t\tpath = Hefesto;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"

    content += """/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t""" + f"""{id_target} /* Hefesto */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {id_config_list_target} /* Build configuration list for PBXNativeTarget "Hefesto" */;
\t\t\tbuildPhases = (
\t\t\t\t{id_sources_phase} /* Sources */,
\t\t\t\t{id_frameworks_phase} /* Frameworks */,
\t\t\t\t{id_resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Hefesto;
\t\t\tproductName = Hefesto;
\t\t\tproductReference = {id_product_app} /* Hefesto.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{id_proj} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastUpgradeCheck = 1520;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{id_target} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {id_config_list_proj} /* Build configuration list for PBXProject "Hefesto" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = es;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\tes,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {id_group_main};
\t\t\tproductRefGroup = {id_group_products} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{id_target} /* Hefesto */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{id_resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{id_assets_build} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{id_sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""
    for b_id, _, name in build_files:
        content += f"\t\t\t\t{b_id} /* {name} in Sources */,\n"

    content += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{id_debug_proj} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{id_release_proj} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{id_debug_target} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Hefesto;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.education";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.odiseo.hefesto;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{id_release_target} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = Hefesto;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.education";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.odiseo.hefesto;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{id_config_list_proj} /* Build configuration list for PBXProject "Hefesto" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{id_debug_proj} /* Debug */,
\t\t\t\t{id_release_proj} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{id_config_list_target} /* Build configuration list for PBXNativeTarget "Hefesto" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{id_debug_target} /* Debug */,
\t\t\t\t{id_release_target} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {id_proj} /* Project object */;
}}
"""
    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Hefesto.xcodeproj generado exitosamente en: {pbx_path}")

if __name__ == "__main__":
    create_xcodeproj()
