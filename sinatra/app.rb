Thread.abort_on_exception = true

$:.unshift File.dirname(__FILE__) + "/lib"

require "bananajour"

require 'sinatra'
require 'haml'
require 'json'

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array'

set :server, 'thin'
set :haml, {:format => :html5, :attr_wrapper => '"'}
set :logging, false
set :root, File.dirname(__FILE__)

require "mock_browsers" if Sinatra::Application.development?

set :bananajour_browser, Bananajour::Bonjour::BananajourBrowser.new
set :repository_browser, Bananajour::Bonjour::RepositoryBrowser.new

require "diff_helpers"
helpers DiffHelpers

require "bananajour/helpers"
helpers Bananajour::GravatarHelpers, Bananajour::DateHelpers

helpers do
  def bananajour_browser() options.bananajour_browser end
  def repository_browser() options.repository_browser end
  def json(body)
    content_type "application/json"
    params[:callback] ? "#{params[:callback]}(#{body});" : body
  end
  def local?
    [
      "0.0.0.0",
      "127.0.0.1",
      Socket.getaddrinfo(request.env["SERVER_NAME"], nil).map {|a| a[3]}
    ].flatten.include? request.env["REMOTE_ADDR"]
  end
  def pluralize(number, singular, plural)
    "#{number} #{number == 1 ? singular : plural}"
  end
end

get "/" do
  @my_repositories     = Bananajour.repositories
  @other_repos_by_name = repository_browser.other_repositories.group_by {|r| r.name}
  @people              = bananajour_browser.other_bananajours
  haml :home
end

get "/:repository/readme" do
  @repository      = Bananajour::Repository.for_name(params[:repository])
  @rendered_readme = @repository.rendered_readme
  @plain_readme    = @repository.raw_readme_file
  haml :readme
end

get "/:repository/:commit" do
  @repository = Bananajour::Repository.for_name(params[:repository])
  @commit     = @repository.rugged_repo.lookup(params[:commit])
  haml :commit
end

get "/index.json" do
  json Bananajour.to_hash.to_json
end

get "/:repository.json" do
  response = Bananajour::Repository.for_name(params[:repository]).to_hash

  response["recent_commits"].map! { |c| c["committed_date_pretty"] = time_ago_in_words(c[:committer][:time]).gsub("about ","") + " ago"; c }
  json response.to_json
end
