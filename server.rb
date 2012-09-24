#!/usr/bin/ruby

abort "You need to source your openrc.sh file" unless ENV["OS_USERNAME"]

# require 'pp'

require 'rubygems'
require 'fog'
require 'socket'

module ATT
  class Server
    attr_accessor :options, :address
    attr_writer :compute, :flavor, :image, :server

    def self.defaults
      {
        :name           => "#{ENV["LOGNAME"]}-#{$$}",
        :flavor         => 'm1.tiny',
        :image_re       => /ubuntu/,
        :security_group => 'appserver',
      }
    end

    def self.permanent options = {}
      server = self.new options

      server.boot
      server.with_floating_ip do
        server.wait_for_ssh
        yield server
      end
    end

    def self.temporary options = {}
      server = self.new options

      server.boot
      server.with_floating_ip do
        server.wait_for_ssh
        yield server
      end
    ensure
      server.destroy
    end

    def self.from_image name
      raise "Not implemented yet"
    end

    def initialize options = {}
      self.options = Server.defaults.merge options
    end

    def create_image name = "#{ENV["LOGNAME"]}.#{$$}"
      $stderr.print "creating image #{name}: "
      compute.create_image server.id, name

      image = compute.images.find do |image|
        image.server['id'] == server.id
      end

      image.wait_for do
        $stderr.print '.'
        image.ready?
      end

      $stderr.puts "done"

      image
    end

    def destroy
      server.destroy
    end

    ### Option Accessors

    def image_re
      options[:image_re]
    end

    def instance_name
      options[:name]
    end

    def key
      options[:key] or raise "No :key option provided"
    end

    def security_group
      options[:security_group]
    end

    ### Lazy Accessors

    def compute
      @compute ||=
        Fog::Compute.new(:provider           => 'OpenStack',
                         :openstack_api_key  => ENV["OS_PASSWORD"],
                         :openstack_username => ENV["OS_USERNAME"],
                         :openstack_auth_url => ENV["OS_AUTH_URL"],
                         :openstack_tenant   => ENV["OS_TENANT_NAME"])
    end

    def image
      @image ||= compute.images.find_all { |image|
        image.name =~ image_re
      }.max_by { |image|
        image.name.split(/(\d+)/).map { |e| [e.to_i, e] } # "natural" sort order
      }

      abort "image matching #{image_re.inspect} not found" unless @image

      @image
    end

    def server
      @server ||=
        compute.servers.create(:name            => instance_name,
                               :image_ref       => image.id,
                               :flavor_ref      => flavor.id,
                               :key_name        => key,
                               :security_groups => [ { :name => security_group } ])
    end

    def flavor
      @flavor ||= compute.flavors.find do |flavor|
        flavor.name == options[:flavor]
      end

      unless @flavor then
        warn "%15s: %4s, %5s, %3s" % %w[name vcpu ram disk]
        warn ""
        compute.flavors.each do |f|
          warn "%15s: %4d, %5d, %3d" % [f.name, f.vcpus, f.ram, f.disk]
        end

        raise "No match for #{flavor_name}"
      end

      @flavor
    end

    ### Utility Methods

    ##
    # Attempts to connect to +address+ on port 22.  Returns true if the connection
    # succeeds.
    #
    # Used to wait for SSH to come up after OpenStack says the server is alive

    def ssh_alive? address
      socket = TCPSocket.open address, 22
    rescue SystemCallError
      # ignored
    ensure
      socket.close if socket
    end

    ##
    # Attaches a floating IP to +server+ for the duration of a block and removes
    # the floating IP when the block terminates.
    #
    # This prevents you from needing to clean up tens of floating IPs as you test
    # out chef recipes

    def with_floating_ip
      connection   = server.connection
      response     = connection.allocate_address

      id           = response.body['floating_ip']['id']
      self.address = response.body['floating_ip']['ip']

      begin
        server.associate_address address

        yield
      ensure
        connection.release_address id
      end
    end

    def boot
      $stderr.print "booting: "
      server = self.server # ugh. needed because of wait_for's instance_eval
      server.wait_for do
        $stderr.print '.'

        # When there's an ERROR fog merrily continues to check for readiness even
        # when it will never happen.  Destroy the image and return the fault
        # instead.
        if server.state == 'ERROR' then
          server.destroy
          abort server.fault.inspect
        end

        ready?
      end
      $stderr.puts 'done'
    end

    def wait_for_ssh
      s = self
      address = self.address # ugh. needed because of wait_for's instance_eval
      server.wait_for do
        $stderr.print '.'

        s.ssh_alive? address
      end
    end
  end
end
