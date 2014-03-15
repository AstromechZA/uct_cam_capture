require 'open3'
require 'RMagick'

require 'net/ssh'
require 'net/scp'
require 'yaml'

# path stuff
current_dir = File.dirname(__FILE__)
temp_dir = File.join(current_dir, 'temp')

# load config
cnf = YAML::load_file(File.join(current_dir, 'config.yml'))
puts cnf

# ensure temp directory
Dir.mkdir(File.join(temp_dir)) if not Dir.exists?(temp_dir)

# timestamp string
t = Time.now.to_i

# filenames
img = "img#{t}.jpg"
thumb = "thumb#{t}.jpg"
img_path = File.join(temp_dir, img)
thumb_path = File.join(temp_dir, thumb)
sample_path = File.join(current_dir, 'noimage.jpg')
remote_img_path = File.join(cnf['remoteimgfolder'], '')
remote_script_path = File.join(cnf['remotescriptfolder'], '')

# remove any existing images
puts "Deleting existing images in #{temp_dir}"
Dir.glob(File.join(temp_dir, '*.jpg')) do |f|
  File.delete(f)
end

# capture image
puts "Capturing #{cnf['imagesize']['width']}x#{cnf['imagesize']['height']} image to #{img_path}"
begin
  stdout,stderr,status = Open3.capture3("raspistill -o #{img_path} -w #{cnf['imagesize']['width']} -h #{cnf['imagesize']['height']} -q 75 -n")
rescue
  puts 'Camera not available. Copying non existant image'
  Magick::Image.read(sample_path).first.write(img_path)
end

# create thumbnail
puts "Generating thumbnail #{img_path} -> #{thumb_path}"
image = Magick::Image.read(img_path).first
resized = image.resize_to_fit(cnf['thumbsize']['width'], cnf['thumbsize']['height'])
resized.write(thumb_path)

# ensure folder exists
puts "Creating ssh connection to #{cnf['username']}@#{cnf['remote']}"
Net::SSH.start(cnf['remote'], cnf['username'], :password => cnf['password'] ) do |ssh|
  puts "Creating remote folder #{remote_img_path}"
  ses = ssh.exec!("mkdir #{remote_img_path}")
end

# scp onto server
puts "Creating scp connection to #{cnf['username']}@#{cnf['remote']}"
Net::SCP.start(cnf['remote'], cnf['username'], :password => cnf['password'] ) do |scp|
  puts 'Uploading img'
  scp.upload!(img_path, remote_img_path)
  puts 'Uploading thumb'
  scp.upload!(thumb_path, remote_img_path)
end

# start script
script = File.join(remote_script_path, 'rebuild_img_listing.rb')
puts "Creating ssh connection to #{cnf['username']}@#{cnf['remote']}"
Net::SSH.start(cnf['remote'], cnf['username'], :password => cnf['password'] ) do |ssh|
  puts "Executing script #{script}"
  ses = ssh.exec!("ruby #{script}")
end