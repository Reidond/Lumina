#!/usr/bin/env ruby
# Adds the iOS-only `LuminaWidgets` extension target that hosts Lumina's Live Activity,
# shares DownloadActivityAttributes with the app, and embeds the extension (iOS platform
# filter so macOS skips it). Idempotent. Run: ruby scripts/add-widget-extension.rb
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, "Lumina.xcodeproj"))
app = project.targets.find { |t| t.name == "Lumina" }
raise "Lumina app target not found" unless app

# Shared attributes file, compiled into BOTH the app and the widget extension.
shared_group = project.main_group.children.find { |g| g.respond_to?(:display_name) && g.display_name == "Shared" } \
  || project.main_group.new_group("Shared", "Shared")
shared_ref = shared_group.files.find { |f| f.path == "DownloadActivityAttributes.swift" } \
  || shared_group.new_reference("DownloadActivityAttributes.swift")
unless app.source_build_phase.files_references.include?(shared_ref)
  app.add_file_references([shared_ref])
end

if project.targets.any? { |t| t.name == "LuminaWidgets" }
  puts "LuminaWidgets already exists — ensured shared file membership only."
  project.save
  exit 0
end

ext = project.new_target(:app_extension, "LuminaWidgets", :ios, "18.0", nil, :swift)

group = project.main_group.new_group("LuminaWidgets", "LuminaWidgets")
live = group.new_reference("DownloadLiveActivity.swift")
bundle = group.new_reference("LuminaWidgetsBundle.swift")
group.new_reference("Info.plist")
ext.add_file_references([live, bundle, shared_ref])

ext.build_configurations.each do |c|
  s = c.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"] = "xyz.andriishafar.Lumina.Widgets"
  s["INFOPLIST_FILE"] = "LuminaWidgets/Info.plist"
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

app.add_dependency(ext)
app.dependencies.last.platform_filters = ["ios"]

embed = app.copy_files_build_phases.find { |ph| ph.display_name == "Embed Foundation Extensions" } \
  || app.new_copy_files_build_phase("Embed Foundation Extensions")
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(ext.product_reference)
bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
bf.platform_filters = ["ios"]

project.save
puts "Added LuminaWidgets (Live Activity) target and embedded it (iOS only)."
