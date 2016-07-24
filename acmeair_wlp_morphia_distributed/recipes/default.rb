#
# Cookbook Name:: acmeair_wlp_morphia_distributed
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'apt::default'
include_recipe 'firewall::default'
include_recipe 'java::default'

ports = node[:firewall][:ports]
firewall_rule "open ports #{ports}" do
  port ports
end

apt_package 'git' do
  action :install
end

include_recipe 'wlp::default'

execute 'download_mongo-java-driver' do
  command 'wget https://oss.sonatype.org/content/repositories/releases/org/mongodb/mongo-java-driver/2.12.2/mongo-java-driver-2.12.2.jar'
  cwd '/'
  not_if {::File.exists?('/opt/was/liberty/wlp/usr/shared/resources/mongodb/mongo-java-driver-2.12.2.jar') }
end

#needs the mongo driver to installed in the application not the context but works 
#execute 'export_mongodb_VCAP' do
#  command 'export VCAP_SERVICES=\'{"mongo":[{"credentials":{"url":"mongodb://<user>:<pwd>@<host>:<port>/<dbname>"}}]}\''
#end

execute 'mkdir_mongo-java-driver' do
  command 'mkdir ./mongodb'
  cwd '/opt/was/liberty/wlp/usr/shared/resources'
  not_if { ::File.directory?('/opt/was/liberty/wlp/usr/shared/resources/mongodb') }
end

execute 'move_mongo-java-driver' do
  command 'mv mongo-java-driver-2.12.2.jar /opt/was/liberty/wlp/usr/shared/resources/mongodb'
  cwd '/'
  not_if {::File.exists?('/opt/was/liberty/wlp/usr/shared/resources/mongodb/mongo-java-driver-2.12.2.jar') }
end

wlp_install_feature "mongodb" do
  location "mongodb-2.0"
  accept_license true
end

wlp_server "server1" do
  action :create
end

git '/acmeair-buildfiles' do
  repository 'https://github.com/crixx/acmeair-buildfiles.git'
  revision 'morphia-distributed'
  action :sync
end

execute 'copy_webapp' do
  command 'cp /acmeair-buildfiles/acmeair-webapp/build/libs/acmeair-webapp-2.0.0-SNAPSHOT.war /opt/was/liberty/wlp/usr/servers/server1/apps/'
end

mongodb_ip = node[:mongodb][:ip]
if node[:mongodb][:ip_from_file] and File.exist?(node[:mongodb][:ip_file_path_name])
  mongodb_ip = ::File.read(node[:mongodb][:ip_file_path_name]).chomp
end

template '/opt/was/liberty/wlp/usr/servers/server1/server.xml' do
	source 'server.xml.erb'
	owner 'wlp'
	group 'wlpadmin'
	mode '0644'
	variables({
	 :mongodb_ip => mongodb_ip,
	 :mongodb_port => node[:mongodb][:port],
	 :mongodb_name => node[:mongodb][:name],
	 :mongodb_user_name => node[:mongodb][:user][:name],
	 :mongodb_user_password => node[:mongodb][:user][:password],
   :http_port => node[:config][:webapp][:port][:http],
   :https_port => node[:config][:webapp][:port][:https],
   :max_keep_alive_requests => node[:config][:tuning][:max_keep_alive_requests]
	})
end

template '/opt/was/liberty/wlp/usr/servers/server1/jvm.options' do
  source 'jvm.options.erb'
  owner 'wlp'
  group 'wlpadmin'
  mode '0644'
  variables({
   :heap_xms => node[:config][:tuning][:heap_xms],
   :heap_xmx => node[:config][:tuning][:heap_xmx]
  })
end

wlp_server "server1" do
  clean true
  action :start 
end