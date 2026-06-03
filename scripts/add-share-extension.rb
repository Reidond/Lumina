#!/usr/bin/env ruby
# Adds the iOS-only `LuminaShare` share-extension target to Lumina.xcodeproj, embeds it in
# the app (iOS platform filter so macOS builds skip it), and points the app at the partial
# Info.plist that declares the `lumina://` URL scheme. Idempotent: re-running is a no-op.
#
# Run:  ruby scripts/add-share-extension.rb
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
proj_path = File.join(ROOT, "Lumina.xcodeproj")
project = Xcodeproj::Project.open(proj_path)

app = project.targets.find { |t| t.name == "Lumina" }
raise "Lumina app target not found" unless app

# Point the app at the partial Info.plist (CFBundleURLTypes). Generated keys still merge.
# It lives OUTSIDE the synchronized Lumina/ folder so it isn't also copied as a resource.
app.build_configurations.each do |c|
  c.build_settings["INFOPLIST_FILE"] = "Lumina-Info.plist"
end

if project.targets.any? { |t| t.name == "LuminaShare" }
  puts "LuminaShare already exists — only refreshed app INFOPLIST_FILE."
  project.save
  exit 0
end

ext = project.new_target(:app_extension, "LuminaShare", :ios, "18.0", nil, :swift)

# Source + Info.plist references in a LuminaShare group.
group = project.main_group.new_group("LuminaShare", "LuminaShare")
sv = group.new_reference("ShareViewController.swift")
group.new_reference("Info.plist")
ext.add_file_references([sv])

ext.build_configurations.each do |c|
  s = c.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"] = "xyz.andriishafar.Lumina.Share"
  s["INFOPLIST_FILE"] = "LuminaShare/Info.plist"
  s["GENERATE_INFOPLIST_FILE"] = "NO"
  s["IPHONEOS_DEPLOYMENT_TARGET"] = "18.0"
  s["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
  s["SDKROOT"] = "iphoneos"
  s["TARGETED_DEVICE_FAMILY"] = "1,2"
  s["SWIFT_VERSION"] = "5.0"
  s["DEVELOPMENT_TEAM"] = "K567Y7B93R"
  s["CODE_SIGN_STYLE"] = "Automatic"
  s["CURRENT_PROJECT_VERSION"] = "1"
  s["MARKETING_VERSION"] = "1.0"
  s["PRODUCT_NAME"] = "$(TARGET_NAME)"
  s["SKIP_INSTALL"] = "YES"
  s["SWIFT_EMIT_LOC_STRINGS"] = "YES"
  s["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
end

# App depends on the extension, then embeds it. iOS platform filter so macOS is unaffected.
app.add_dependency(ext)
app.dependencies.last.platform_filters = ["ios"]

embed = app.new_copy_files_build_phase("Embed Foundation Extensions")
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
bf.platform_filters = ["ios"]

project.save
puts "Added LuminaShare target and embedded it (iOS only)."
