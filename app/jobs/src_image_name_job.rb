# Job to automatically name source images using Google.
class SrcImageNameJob < ActiveJob::Base
  queue_as :default

  def perform(src_image)
    return unless host
    return unless src_image.name.blank?

    conn = create_connection

    conn.get('/imghp?hl=en&tab=wi')

    response = conn.get(
      '/searchbyimage',
      image_url: src_image_url(src_image))

    name = extract_name(response.body)
    src_image.update!(name: name) unless name.blank?
  end

  private

  def host
    Rails.application.config.asset_host
  end

  def create_connection
    Faraday.new(url: 'http://google.com') do |faraday|
      faraday.use(:cookie_jar)
      faraday.use(FaradayMiddleware::FollowRedirects)
      faraday.headers['User-Agent'] = \
        'Mozilla/5.0 (Windows NT 6.1; rv:8.0) Gecko/20100101 Firefox/8.0'
      faraday.adapter(Faraday.default_adapter)
    end
  end

  def src_image_url(src_image)
    Rails.application.routes.url_helpers.url_for(
      host: host, controller: :src_images, action: :show,
      id: src_image.id_hash)
  end

  def extract_name(body)
    match = body.match(%r{Best guess for this image:.*?>(.+?)</a>})
    match.captures[0] if match
  end
end
