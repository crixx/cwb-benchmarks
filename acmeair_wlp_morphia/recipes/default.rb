#
# Cookbook Name:: acmeair_wlp_morphia
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.


#configure firewall
include_recipe 'firewall::default'
ports = node.default['morphia_server']['open_ports']
firewall_rule "open ports #{ports}" do
  port ports
end

#apt-get update
include_recipe 'apt::default'
#install java
include_recipe 'java::default'
#install git
apt_package 'git' do
  action :install
end

#install wlp
include_recipe 'wlp::default'

#download the mongo-java-driver
execute 'download_mongo-java-driver' do
  command 'wget https://oss.sonatype.org/content/repositories/releases/org/mongodb/mongo-java-driver/2.12.2/mongo-java-driver-2.12.2.jar'
  cwd '/'
  not_if {::File.exists?('/opt/was/liberty/wlp/usr/shared/resources/mongodb/mongo-java-driver-2.12.2.jar') }
end

#needs the mongo driver to installed in the application not the context but works 
#execute 'export_mongodb_VCAP' do
#  command 'export VCAP_SERVICES=\'{"mongo":[{"credentials":{"url":"mongodb://<user>:<pwd>@<host>:<port>/<dbname>"}}]}\''
#end

#make a folder
execute 'mkdir_mongo-java-driver' do
  command 'mkdir ./mongodb'
  cwd '/opt/was/liberty/wlp/usr/shared/resources'
  not_if { ::File.directory?('/opt/was/liberty/wlp/usr/shared/resources/mongodb') }
end

#install i.e move the driver to the folder
execute 'move_mongo-java-driver' do
  command 'mv mongo-java-driver-2.12.2.jar /opt/was/liberty/wlp/usr/shared/resources/mongodb'
  cwd '/'
  not_if {::File.exists?('/opt/was/liberty/wlp/usr/shared/resources/mongodb/mongo-java-driver-2.12.2.jar') }
end

#add shorthand $WLP_DIR
execute 'export_WLP_DIR' do
  command 'sudo echo "WLP_DIR=/opt/was/liberty/wlp/" >> /etc/environment'
end

#add shorthand to start the server $WLP_START
execute 'export_WLP_START' do
  command 'sudo echo "WLP_START=/opt/was/liberty/wlp/bin/server start server1" >> /etc/environment'
end

#add shorthand to stop the server $WLP_STOP
execute 'export_WLP_STOP' do
  command 'sudo echo "WLP_STOP=/opt/was/liberty/wlp/bin/server stop server1" >> /etc/environment'
end

#install mongodb feature to WLP
wlp_install_feature "mongodb" do
  location "mongodb-2.0"
  accept_license true
end

#create a new webserver-instance
wlp_server "server1" do
  action :create
end

#download the buildfiles for acmeair
git '/acmeair-buildfiles' do
  repository 'https://github.com/crixx/acmeair-buildfiles.git'
  revision 'morphia-distributed'
  action :sync
end

#copy to buildfiles to the WLP folder
execute 'copy_webapp' do
  command 'cp /acmeair-buildfiles/acmeair-webapp/build/libs/acmeair-webapp-2.0.0-SNAPSHOT.war /opt/was/liberty/wlp/usr/servers/server1/apps/'
end

template '/opt/was/liberty/wlp/usr/servers/server1/server.xml' do
  source 'server.xml.erb'
  owner 'wlp'
  group 'wlpadmin'
  mode '0644'
  variables({
   :mongodb_ip => node[:mongodb][:ip],
   :mongodb_port => node[:mongodb][:port],
   :mongodb_name => node[:mongodb][:name]
  })
end

#install the mongodb in a older version
include_recipe "mongodb::10gen_repo"
include_recipe "mongodb::default"

#start the server
wlp_server "server1" do
  clean true
  action :start
end

#execute 'run_vmstat' do
#  command 'sudo nohup vmstat 5 > vmstat.log &'
#  cwd '/'
#end

ruby_block 'load_users_to_db' do
  block do   
    require 'net/http'
    res = Net::HTTP.get_response(URI("http://localhost:9080/acmeair-webapp/rest/info/loader/load?numCustomers=#{node[:config][:webapp][:users_to_load]}"))
    if  res.body.include? "Loaded flights and"
    else
      raise "An error has occured: #{res.code} #{res.message}"
    end
  end
  retries 60
end