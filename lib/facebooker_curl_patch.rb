# Attempt at fixing Curl errors in Facebooker requests that may be caused by no data returned

# Patch of facebooker/service/curl_service.rb
# Found in http://groups.google.com/group/facebooker/browse_thread/thread/6b9e0489c2fb4512/7ea4736898c418f5
# service.post has retry logic for the following errors:
# Errno::ECONNRESET, EOFError

class Facebooker::Service::CurlService < Facebooker::Service::BaseService
  def post_form(url,params,multipart=false)
    begin
      curl = Curl::Easy.new(url.to_s) do |c|
        c.multipart_form_post = multipart
        c.timeout = ENV['FACEBOOKER_TIMEOUT'].to_i rescue c.timeout = nil
      end
      curl.http_post(*to_curb_params(params))
      Facebooker.logger.warn "Curl http_post returned nothing!" unless curl.body_str
      curl.body_str
    rescue Curl::Err::TimeoutError => e 
      Facebooker.logger.error "*** #{e.class.name} #{e.message}: #{params[:method]}...RETRYING ***"
      raise Errno::ECONNRESET
    rescue Curl::Err::GotNothingError => e
      Facebooker.logger.error "*** #{e.class.name} #{e.message}: #{params[:method]}...RETRYING ***"
      raise Errno::ECONNRESET
    end
  end
end