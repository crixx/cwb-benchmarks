default['acmeairdefault']['testplan']['user_in_db'] = 200

default['acmeairdefault']['testplan']['connection_timeout'] = 30000 #30s
default['acmeairdefault']['testplan']['response_timeout'] = 30000 #30s

default['acmeairdefault']['testplan']['target_host']['port'] = 9080
default['acmeairdefault']['testplan']['target_host']['name'] = '172.31.3.1'

default['acmeairdefault']['testplan']['threadgroup']['num_threads'] = 500
default['acmeairdefault']['testplan']['threadgroup']['ramp_up_time'] = 120
default['acmeairdefault']['testplan']['threadgroup']['duration'] = 300
default['acmeairdefault']['testplan']['threadgroup']['delay'] = 0