require 'rubygems'
require 'bundler/setup'

require 'plist'
require 'parse-ruby-client'

require_relative 'paths.rb'


def generatePlist (settings)
  
  puts "--> Creation du plist"
  
  buildConfiguration  = settings[:buildConfiguration]
  buildDirectory      = settings[:buildDirectory]
  buildNumber         = settings[:buildNumber]
  projectInfosPath    = settings[:projectInfosPath]
  
  projectInfos    = Plist::parse_xml(projectInfosPath)
  deployPlistPath = deployPlistPath(settings)
  
  deployPlist = Hash.new
  items       = Array.new
  item        = Hash.new
  
  assets        = Array.new
  
  asset         = Hash.new
  asset['kind'] = 'software-package'
  asset['url']  = settings[:deploy]["uploadServer"]["ipa"][0]["publicURL"] + "/" + ipaName(settings)

  assets.push asset
  
  metadata = Hash.new
  
  # the following line has been commented and replaced by th next one in order to make it work on iOS 9...
  # metadata['bundle-identifier'] = settings[:deploy]["infosPlist"]["CFBundleIdentifier"] + ".iOS8"
  metadata['bundle-identifier'] = settings[:deploy]["infosPlist"]["CFBundleIdentifier"]
  metadata['bundle-version']    = projectInfos['CFBundleVersion']
  metadata['subtitle']          = 'by SoLocal'
  metadata['title']             = settings[:deploy]["infosPlist"]["CFBundleDisplayName"]
  metadata['kind']              = 'software'

  item['assets']    = assets
  item['metadata']  = metadata
  
  items.push item
  deployPlist['items'] = items
  Plist::Emit.save_plist(deployPlist , deployPlistPath)
  
end

