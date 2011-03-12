module EasyPDF
  require 'open3'

  def render_with_webkit_pdf(opts = {})
    if RAILS_ENV == 'production' || RAILS_ENV == 'staging'
      render_with_webkit_pdf_production(opts)
    else
      render_with_webkit_pdf_locally(opts)
    end
  end

  def render_with_webkit_pdf_production(opts = {})
    webkit_pdf_render(webkit_pdf_url(opts))
  end

  def render_with_webkit_pdf_locally(opts = {})
    render_webkit_environment_setup_error and return unless ENV['WEBKIT_PDF_DEVELOPMENT_URL']
    url = webkit_pdf_url(opts).gsub(Regexp.new("#{request.protocol}#{request.host_with_port}"),
                                  ENV['WEBKIT_PDF_DEVELOPMENT_URL'])
    webkit_pdf_render(url)
  end

  def webkit_pdf_url(opts)
    uri   = URI.parse(request.request_uri.gsub(/\.pdf$/, ""))
    query = CGI.parse(uri.query) if uri.query
    str = if query
      query.delete('format')
      query['style'] = 'pdf'
      query.collect { |key, values| values.collect { |value| "#{CGI.escape(key)}=#{CGI.escape(value)}" }}.
                    flatten.join("&")
    else "style=pdf" end

    url = "#{request.protocol}#{request.host_with_port}#{uri.path}#{str ? "?#{str}" : ""}"
    url
  end

  def render_webkit_environment_setup_error
    @this_url = request.host_with_port
    response.headers['Content-Type'] = 'text/html'
    render :template => File.dirname(__FILE__) + '/local.html.erb'
  end

  def webkit_pdf_render(url)
    cookie_hash = Helpers::split_cookies(request.headers['HTTP_COOKIE'])
    username = Preference.find_by_name('HTTP_USERNAME')
    password = Preference.find_by_name('HTTP_PASSWORD')
    auth_opts = if username && password && password.value.length > 0
                then "--username \"#{username.value}\" --password \"#{password.value}\""
                else "" end
    cookie_opts = cookie_hash.collect {|name,value| "--cookie \"#{name}\" \"#{value}\""}.join(" ")
    cmd = "wkhtmltopdf #{cookie_opts} #{auth_opts} -q --disable-external-links \"#{url}\" -"
    log_info("wkhtmltopdf command: #{cmd}")
    pdf = Open3.popen3(cmd) do |_, stdout, stderr|
      pdf = stdout.read
      raise "PDF could not be generated!\n#{stderr.read}" if pdf.length == 0
      pdf
    end
    render :text => pdf
  end


  module Helpers

    def Helpers::split_cookies(cookies)
      h = {}
      cookies.split(";").each do |cookie|
        name, value = cookie.split("=")
        h[name.strip] = value.strip
      end
      h
    end

  end


end
