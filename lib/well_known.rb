## SOURCE OF EXAMPLES: http://hueniverse.com/2009/09/implementing-webfinger/

require 'sinatra'
require 'nokogiri'

class WellKnown < Sinatra::Base
  #HOST = 'heahdk.net'
  HOST = 'localhost'
  PORT = '3000'
  SCHEME = 'http'

=begin

<?xml version='1.0' encoding='UTF-8'?>
<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'
     xmlns:hm='http://host-meta.net/xrd/1.0'>

    <hm:Host>example.com</hm:Host>

    <Link rel='lrdd'
          template='http://example.com/describe?uri={uri}'>
        <Title>Resource Descriptor</Title>
    </Link>
</XRD>
=end

  get '/host-meta' do
    allow_origin('*')
    content_type 'application/xrd+xml'
    Nokogiri::XML::Builder.new do |xml|
      xml.xrd(
        'xmlns' => 'http://docs.oasis-open.org/ns/xri/xrd-1.0',
        'xmlns:hm' => 'http://host-meta.net/xrd/1.0'
      ) do
        xml['hm'].host(HOST)

        xml.link(
          'rel' => 'lrdd',
          'template' => lrdd_describe_url
        ) do
          xml.title("Resource Descriptor")
        end
      end
    end.to_xml
  end

=begin
<?xml version='1.0' encoding='UTF-8'?>
<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>

    <Subject>acct:joe@example.com</Subject>
    <Alias>http://example.com/profiles/joe</Alias>

    <Link rel='http://portablecontacts.net/spec/1.0'
          href='http://example.com/api/people/' />
    <Link rel='http://webfinger.net/rel/profile-page'
          type='text/html'
          href='http://example.com/profiles/joe' />
    <Link rel='http://microformats.org/profile/hcard'
          type='text/html'
          href='http://example.com/profiles/joe' />
    <Link rel='describedby'
          type='text/html'
          href='http://example.com/profiles/joe' />
    <Link rel='http://webfinger.net/rel/avatar'
          href='http://example.com/profiles/joe/photo' />
</XRD>
=end

  get '/lrdd/describe' do
    allow_origin('*')
    content_type 'application/xrd+xml'

    uri_string = params[:uri]
    throw :precondition_not_met unless uri_string

    uri = URI.parse(uri_string)
    throw :not_allowed unless uri.host == HOST

    uri.scheme = 'acct'

    Nokogiri::XML::Builder.new do |xml|
      xml.instruct!
      xml.xrd(
        'xmlns' => 'http://docs.oasis-open.org/ns/xri/xrd-1.0'
      ) do
        xml.subject(uri.to_s)
        xml.alias(profile_url(uri.user))
      end
    end
  end

  helpers do
    def lrdd_describe_url
      well_known_url('lrdd', 'describe?uri={uri}')
    end

    def profile_url(name)
      "#{base_url}/~#{name})"
    end

    def well_known_url(*parts)
      [base_url, '.well-known', *parts].join('/')
    end

    def base_url
      port = [80, 443].include?(PORT) ? '' : ":#{PORT}"
      "#{SCHEME}://#{HOST}#{port}"
    end

    def allow_origin(origin)
      headers('Access-Control-Allow-Origin' => origin)
    end
  end
end
