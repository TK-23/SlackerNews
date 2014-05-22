require 'sinatra'
require 'uri'
require 'csv'

def get_articles
  articles = []
  CSV.foreach('articles.csv', headers: true) do |row|
    articles << row.to_hash
  end
  articles.reverse
end

def post_article(title, url, descriptor,calander_time,clock_time)
  CSV.open('articles.csv', 'a') do |csv|
    csv << [title, url, descriptor,calander_time,clock_time]
  end
end

def url_exists?(url)
  get_articles.each do |article|
    article["url"] == url ? ( return true ) : (return false )
  end
end


get "/"  do
  @articles = get_articles
  erb :main
end

get "/submit"  do
  @populated_info = {}
  @missing_info = []
  erb :submit
end

post "/submit"  do
  @populated_info = {}
  @missing_info = []
  checks_failed = 0

  [:title,:url,:descriptor].each do |check|
    if params[check] == ""
      @missing_info << "Please enter information for ".concat(check.to_s.upcase)
      checks_failed +=1
    else
      @populated_info[check] = params[check]
    end
  end

  if params[:descriptor].length < 20
    @missing_info << "Please enter a longer description"
    checks_failed +=1
  end

  if url_exists?(params[:url]) == true
    @missing_info << "The URL is already listed..."
    checks_failed +=1
  end

  if checks_failed == 0
    post_article(params[:title],params[:url],URI.encode(params[:descriptor]),params[:calander_time],params[:clock_time])
    redirect "/"
  else
    erb :submit
  end
#

end
