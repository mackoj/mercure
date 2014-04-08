require 'rubygems'
require 'bundler/setup'

require 'net/scp'
require 'net/ftp'
require 'net/ssh'

require 'nokogiri'
require 'date'

require_relative 'paths.rb'

def uploadArtefacts(xcode_settings , deploy)
  
  uploadPlist(xcode_settings , deploy)
  uploadIPA(xcode_settings , deploy)

  # legacy, shouldn't be needed when the old DTAppStore will no more be used.
  updateDTMobXML xcode_settings , deploy
  
end

def uploadFiles(xcode_settings , deploy , destination , files_to_upload)
  
  host    = destination["host"]
  login   = destination["login"]
  path    = destination["path"]
  
  if (destination["protocol"] == "ssh")
    uploadViaSSH(host , login , files_to_upload)

  elsif (destination["protocol"] == "ftp")
    password = destination["password"]
    uploadViaFTP(host , login , password, path, files_to_upload)

  else 
    puts "Protocole de téléversement inconnu"

  end
  
end

def uploadIPA(xcode_settings , deploy)

  deploy["uploadServer"]["ipa"].each do |destination|
    
    ipaPath         = ipaPath (xcode_settings , deploy)
    remoteIpaPath   = remoteIpaPath (xcode_settings , deploy , destination)
    
    dsymPath        = zippedDsymPath(xcode_settings , deploy)
    remoteDsymPath  = remoteDsymPath(xcode_settings , deploy , destination)
    
    files_to_upload = [[ipaPath , remoteIpaPath] , [dsymPath , remoteDsymPath]]
    
    uploadFiles(xcode_settings , deploy , destination , files_to_upload)
    
  end
  
end

def uploadPlist(xcode_settings , deploy)
  
  deploy["uploadServer"]["plist"].each do |destination|
    
    deployPlistPath         = deployPlistPath       (xcode_settings , deploy)
    remoteDeployPlistPath   = remoteDeployPlistPath (xcode_settings , deploy ,destination)
    
    files_to_upload = [[deployPlistPath , remoteDeployPlistPath]]
    
    uploadFiles(xcode_settings , deploy , destination , files_to_upload)
    
  end
  
end

# files_to_upload is an array of arrays
# that must be like [local_file_path , remote_file_path]
def uploadViaSSH(host , login , files_to_upload)

  # on vérifie si le dossier existe
  version = "./iphone_rf/IrishCoffee.7.2"
  check_command = "if [ ! -d \"#{version}\" ]; then mkdir \"#{version}\"; fi"
  
  Net::SSH.start(host, login) do |ssh|
    # capture all stderr and stdout output from a remote process
    output = ssh.exec!(check_command)
    
    puts "check: #{check_command}"
    puts "output : #{output}"
  end

  Net::SCP.start(host, login) do |scp|
    files_to_upload.each do |names|
      puts 'Envoi du fichier ' + names[0] + ' vers ' + names[1]
      scp.upload!(names[0].to_s, names[1])
    end
  end

end

# files_to_upload is an array of arrays
# that must be like [local_file_path , remote_file_path]
def uploadViaFTP(host, usermame , password , path, files_to_upload)
  
  ftp = Net::FTP.new(host)
  
  ftp.login(usermame , password)
  ftp.chdir(path)
  liste = ftp.list
  
  puts "liste: #{liste}"
  
  target_path = "test"
  
  if ! (liste.any? { |element| element.include? target_path})
    puts "le dossier #{target_path} n'existe pas."
    ftp.mkdir(target_path)
  end
  
  files_to_upload.each do |names|
    puts 'Envoi du fichier ' + names[0] + ' vers ' + names[1]
    ftp.putbinaryfile(names[0].to_s, names[1])
  end
  
  ftp.close
  
end


def updateDTMobXML (xcode_settings , deploy)
  
  # après upload des artefacts, on peut mettre à jour le fichier dtmob.xml
  # et pourquoi pas dsem.xml
  
  puts "Pas de mise à jour du dtmob.xml pour le moment"
  
  return
  
  host        = deploy["uploadServer"]["host"]
  login       = deploy["uploadServer"]["login"]
  path        = deploy["uploadServer"]["path"]
  buildNumber = xcode_settings[:buildNumber]
  
  dtmobApplicationName    = deploy["uploadServer"]["applicationTitle"]
  dtmobApplicationVersion = deploy["uploadServer"]["applicationVersion"]
  
  Net::SCP.start(host, login) do |scp|
    puts 'Mise-à-jour du fichier dtmob.xml'
    scp.download!(remoteDTMobFile, localDTMobFile)
    
    file  = File.read(localDTMobFile)
    dtmob = Nokogiri::XML(file)
    
    timeFormat        = "%Y-%m-%d %H-%M-%S"
    lastUpdate        = DateTime.now.strftime(timeFormat)
    applicationXPath  = "//application[title='#{dtmobApplicationName}']"
    versionXPath      = "version[numero='#{dtmobApplicationVersion}']"
    changeLogXPath    = "changelog"
    changeLogContent  = <<-EOXML
    <![CDATA[
    <ul>
    <li>Last update: #{lastUpdate}</li>
    <li>Build number: #{buildNumber}</li>
    </ul>]]>
    EOXML
    
    application       = dtmob.xpath(applicationXPath)
    version           = application.xpath(versionXPath)
    
    changeLog            = version.xpath(changeLogXPath).first
    changeLog.inner_html = changeLogContent
    
    # save the output into a new file
    File.open(localDTMobFile, "w") do |f|
      f.write dtmob.to_xml
    end
    
    
    scp.upload(localDTMobFile , remoteDTMobFile)
  end
  
end

