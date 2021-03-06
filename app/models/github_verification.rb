class GithubVerification < Verification
  attr_accessor :code

  validates :code, presence: true

  before_validation :generate_access_token, on: :create

  private

  def generate_access_token
    response = request.send_request('POST', uri.path, config)
    data = CGI.parse(response.body)
    return if response.code != '200'

    self.auth_id = get_user_login(data['access_token'].first)
  end

  def request
    Net::HTTP.new(uri.host, uri.port).tap { |http| http.use_ssl = true }
  end

  def uri
    @uri ||= URI(ENV['GITHUB_ACCESS_TOKEN_URI'])
  end

  def config
    CGI.unescape({ code: code, client_id: ENV['GITHUB_CLIENT_ID'], client_secret: ENV['GITHUB_CLIENT_SECRET'],
                   redirect_uri: ENV['GITHUB_REDIRECT_URI'] }.to_query)
  end

  def get_user_login(access_token)
    uri = URI(ENV['GITHUB_USER_URI'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.get2(uri.path, 'Authorization' => "token #{access_token}")
    JSON.parse(response.body)['login']
  end
end
