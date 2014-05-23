require 'sinatra'
require 'uri'
require 'csv'

def get_comment(article_id)
  comments = []
  CSV.foreach('comments.csv', headers: true) do |row|
    comments << row.to_hash if row["article_id"] == article_id
  end
  comments.reverse
end

def get_articles
  all_articles = []
  CSV.foreach('articles.csv', headers: true) do |row|
    article = row.to_hash
    article["comments"] = get_comment(row["article_id"])
    all_articles << article
  end
  all_articles.reverse
end

def post_article(id, title, url, descriptor,calander_time,clock_time)
  CSV.open('articles.csv', 'a') do |csv|
    csv << [id, title, url, descriptor,calander_time,clock_time]
  end
end

def post_comment(id, comment, time)
  CSV.open('comments.csv', 'a') do |csv|
    csv << [id, comment, time]
  end
end

def url_exists?(url)
  get_articles.each do |article|
    article["url"] == url ? ( return true ) : (return false )
  end
end

get "/submit"  do
  @populated_info = {}
  @missing_info = []
  erb :submit
end

get "/addcomment/:article_id"  do
  @article_info = get_articles.reverse[params[:article_id].to_i]
  erb :addcomment
end

post "/addcomment"  do
  post_comment(params[:article_id], params[:comment], params[:time])
  redirect "/"
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
    id = get_articles.length
    post_article(id, params[:title],params[:url],URI.encode(params[:descriptor]),params[:calander_time],params[:clock_time])
    redirect "/"
  else
    erb :submit
  end
#
end

get "/*"  do
  @articles = get_articles
  erb :main
end
