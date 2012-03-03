## SOURCE OF EXAMPLES: http://hueniverse.com/2009/09/implementing-webfinger/

require 'sinatra'
require 'nokogiri'
require 'yaml'
require 'etc'

class WellKnown < Sinatra::Base

  HOST = 'localhost'
  PORT = 9292
  SCHEME = 'http'

  ## Set PREFIX to '', if you want to proxy_pass /.well-known
  ## to this app from a frontend server (which is recommended)
  PREFIX = '/.well-known'

  ## How do your profile URLs work?
  PROFILE_PATTERN = '[base_url]/~[name]' # (example: http://wonderland.lit/~alice)

  ## Configure your services:
  SERVICE_LINKS = {
    ## Example for remoteStorage:
    # 'remoteStorage' => {
    #   'rel' => 'remoteStorage',
    #   'api' => 'CouchDB',
    #   'template' => 'http://localhost:5984/[name]/{category}/',
    #   'auth' => '...'
    # }
  }


  ## Where do UIDs of actual users start?
  UID_START = 1000

  passwd_entries = []
  while entry = Etc.getpwent
    passwd_entries.push(entry) if entry.uid >= UID_START
  end

  USERS = Hash[passwd_entries.map {|e| [e.name, e] }].freeze

  def self.get(path, &block)
    file, line = caller.first.match(/^([^\:]+)\:(\d+)/)[1..2]
    location = "#{File.basename(file)}:#{line}"
    path = PREFIX + path
    puts "ROUTE: #{path} => @#{location}"
    super(path, &block)
  end


  get '/host-meta' do

    allow_origin('*')
    content_type 'application/xrd+xml'

    # <?xml version='1.0' encoding='UTF-8'?>
    # <XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'
    #      xmlns:hm='http://host-meta.net/xrd/1.0'>
    #
    #     <hm:Host>example.com</hm:Host>
    #
    #     <Link rel='lrdd'
    #           template='http://example.com/describe?uri={uri}'>
    #         <Title>Resource Descriptor</Title>
    #     </Link>
    # </XRD>

    xrd(:hm) do |x|
      x['hm'].Host(HOST)
      x.Link('rel' => 'lrdd', 'template' => lrdd_describe_url) do
        x.Title("Resource Descriptor")
      end
    end
  end

  get '/lrdd/describe' do

    allow_origin('*')
    content_type 'application/xrd+xml'

    unless uri_string = params[:uri]
      throw :halt, [412, "Precondition Failed\n"]
    end

    uri = URI.parse(uri_string)

    unless uri.scheme == 'acct'
      throw :halt, [412, "Precondition Failed\nSorry, we don't support #{uri.scheme} URIs yet."]
    end

    unless uri.host == HOST
      puts "Don't know about host #{uri.host}. My name is #{HOST}"
      throw :halt, [404, "Not Found\n"]
    end

    unless USERS[uri.user]
      puts "Don't know user #{uri.user}."
      throw :halt, [404, "Not Found\n"]
    end

    # <?xml version='1.0' encoding='UTF-8'?>
    # <XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>
    #
    #     <Subject>acct:joe@example.com</Subject>
    #     <Alias>http://example.com/profiles/joe</Alias>
    #
    #     <Link rel='http://portablecontacts.net/spec/1.0'
    #           href='http://example.com/api/people/' />
    #     <Link rel='http://webfinger.net/rel/profile-page'
    #           type='text/html'
    #           href='http://example.com/profiles/joe' />
    #     <Link rel='http://microformats.org/profile/hcard'
    #           type='text/html'
    #           href='http://example.com/profiles/joe' />
    #     <Link rel='describedby'
    #           type='text/html'
    #           href='http://example.com/profiles/joe' />
    #     <Link rel='http://webfinger.net/rel/avatar'
    #           href='http://example.com/profiles/joe/photo' />
    # </XRD>


    xrd do |x|
      x.Subject(uri.to_s)
      x.Alias(profile_url(uri.user))

      add_links(x, uri.user)
    end
  end

  helpers do

    ## Headers

    def allow_origin(origin)
      headers('Access-Control-Allow-Origin' => origin)
    end

    XRD_NS = {
      :hm => 'http://host-meta.net/xrd/1.0'
    }

    ## XRD
    def xrd(*ns)
      namespaces = {
        'xmlns' => 'http://docs.oasis-open.org/ns/xri/xrd-1.0'
      }.merge(
        Hash[
          ns.map {|n|
            ["xmlns:#{n}", XRD_NS[n]]
          }
        ]
      )

      return Nokogiri::XML::Builder.new { |xml|
        xml.XRD(namespaces) {
          yield(xml)
        }
      }.to_xml
    end

    def add_links(xrd, user)
      config_path = File.join(home_dir(user), '.lrdd.yml')
      if File.exist?(config_path)
        config = YAML.load_file(config_path)
        vars = {
          :name => user
        }
        config['services'].each do |service|
          if attributes = SERVICE_LINKS[service]
            xrd.Link(
              attributes.each_pair.inject({}) { |attrs, (key, value)|
                attrs.update(key => replace_vars(value, vars))
              }
            )
          else
            puts "WARNING: Service not defined: #{service}"
          end
        end
      end
    end

    def home_dir(user)
      USERS[user].dir
    end

    ## Urls

    def lrdd_describe_url
      well_known_url('lrdd', 'describe?uri={uri}')
    end

    def profile_url(name)
      vars = {
        :base_url => base_url,
        :name => name
      }
      replace_vars(PROFILE_PATTERN, vars)
    end

    def well_known_url(*parts)
      base_url('.well-known', *parts)
    end

    def base_url(*parts)
      port = [80, 443].include?(PORT.to_i) ? '' : ":#{PORT}"
      ["#{SCHEME}://#{HOST}#{port}", *parts].join('/')
    end

    ## Simple Template

    def replace_vars(template, vars)
      expression = /\[(#{vars.keys.join('|')})\]/
      template.gsub(expression) { |k|
        vars[ k.gsub(/[\[\]]/, '').to_sym ]
      }
    end

  end
end
