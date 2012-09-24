#!/usr/bin/ruby

abort "You need to source your openrc.sh file" unless ENV["OS_USERNAME"]

require 'rubygems'
require './server.rb'

# require 'chef'
# require 'chef/knife'

# defined in dashboard/security -- associated with my ssh key
key = ARGV.shift || 'att_nova'

module RbConfig
  def self.ruby
    File.join(RbConfig::CONFIG['bindir'],
              RbConfig::CONFIG['ruby_install_name'] +
              RbConfig::CONFIG['EXEEXT']).sub(/.*\s.*/m, '"\&"')
  end
end unless RbConfig.respond_to? :ruby

def knife args
  knife_command = Gem.default_exec_format % 'knife'

  result = system RbConfig.ruby, '-S', knife_command, *args

  raise "failed: #{knife_command} #{args.join ' '}" unless result
end

class ATT::Server
  def ssh cmd
    system "ssh", "root@#{address}", "sh -c '#{cmd}'"
  end
end

ATT::Server.temporary :key => key do |server|
  address = server.address
  knife %W[prepare root@#{address}]
  knife %W[cook -V root@#{address} nodes/generic.json]

  # server.create_image "my-web-thingy"

  puts "VM built on #{server.address}, press return to continue"
  gets
end

20.times do |n|
  ATT::Server.permanent :image => "my-web-thingy", :name => "web-server-#{n}"
end
