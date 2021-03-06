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
sample_img = File.join(current_dir, 'sample.jpg')

# remove any existing images
Dir.glob(File.join(temp_dir, '*.jpg')) do |f|
  File.delete(f)
end

# capture image
Magick::Image.read(sample_img).first.write(img_path)

# create thumbnail
image = Magick::Image.read(img_path).first
resized = image.resize_to_fit(cnf['thumbsize']['width'], cnf['thumbsize']['height'])
resized.write(thumb_path)

# ensure folder exists
Net::SSH.start(cnf['remote'], cnf['username'], :password => cnf['password'] ) do |ssh|
  ses = ssh.exec!("mkdir #{cnf['remotefolder']}")
end

# scp onto server
Net::SCP.start(cnf['remote'], cnf['username'], :password => cnf['password'] ) do |scp|
  scp.upload!(img_path, cnf['remotefolder'])
  scp.upload!(thumb_path, cnf['remotefolder'])
end