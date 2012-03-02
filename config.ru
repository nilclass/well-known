# -*- mode:ruby -*-

require 'ruby-debug'
require 'pathname'

lib = Pathname.new(File.expand_path('../lib', __FILE__))

require lib.join('well_known.rb')
require lib.join('uri/acct.rb')

run WellKnown
