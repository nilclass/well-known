## SOURCE OF EXAMPLES: http://hueniverse.com/2009/09/implementing-webfinger/

require 'sinatra'
require 'nokogiri'

class WellKnown < Sinatra::Base

  HOST = 'localhost'
  PORT = 9292
  SCHEME = 'http'

  ## Set PREFIX to '', if you want to proxy_pass /.well-known
  ## to this app from a frontend server (which is recommended)
  PREFIX = '/.well-known'

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

    Nokogiri::XML::Builder.new do |xml|
      xml.XRD(
        'xmlns' => 'http://docs.oasis-open.org/ns/xri/xrd-1.0',
        'xmlns:hm' => 'http://host-meta.net/xrd/1.0'
      ) do
        xml['hm'].Host(HOST)

        xml.Link(
          'rel' => 'lrdd',
          'template' => lrdd_describe_url
        ) do
          xml.Title("Resource Descriptor")
        end
      end
    end.to_xml
  end

  get '/lrdd/describe' do

    allow_origin('*')
    content_type 'application/xrd+xml'

    unless uri_string = params[:uri]
      throw :halt, [412, "Precondition Failed\n"]
    end

    uri = URI.parse(uri_string)

    unless uri.host == HOST
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
          *ns.map {|n|
            ["xmlns:#{n}", XRD_NS[n]]
          }
        ]
      )

      Nokogiri::XML::Builder.new do |xml|
        xml.XRD(namespaces) do
          yield(xml)
        end.to_xml
      end
    end

    ## Urls

    def lrdd_describe_url
      well_known_url('lrdd', 'describe?uri={uri}')
    end

    def profile_url(name)
      "#{base_url}/~#{name}"
    end

    def well_known_url(*parts)
      [base_url, '.well-known', *parts].join('/')
    end

    def base_url
      port = [80, 443].include?(PORT.to_i) ? '' : ":#{PORT}"
      "#{SCHEME}://#{HOST}#{port}"
    end

  end
end
