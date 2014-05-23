require 'sinatra'
require 'csv'
require 'redis'
require 'json'

def get_connection
  if ENV.has_key?("REDISCLOUD_URL")
    Redis.new(url: ENV["REDISCLOUD_URL"])
  else
    Redis.new
  end
end

def find_articles
  redis = get_connection
  serialized_articles = redis.lrange("slacker:articles", 0, -1)

  articles = []

  serialized_articles.each do |article|
    articles << JSON.parse(article, symbolize_names: true)
  end

  articles
end

def save_article(url, title, description)
  article = { url: url, title: title, description: description }

  redis = get_connection
  redis.rpush("slacker:articles", article.to_json)
end

def load_csv(csv)
  all_rows = []
  CSV.foreach(csv, headers: true) do |row|
    all_rows << row.to_hash
  end
  all_rows
end

def find_subcomments(initial_hash)
  initial_hash["subcomments"] = []
  load_csv("comments.csv").each do |sub_comment|
    if ( initial_hash["comment_id"] == sub_comment["parent_comment"] ) && ( initial_hash["comment_id"] != sub_comment["comment_id"] )
      initial_hash["subcomments"] << sub_comment.to_hash
    end
  end
  if initial_hash["subcomments"] == []
    initial_hash.delete("subcomments")
  else
    initial_hash["subcomments"].each do |subsubcomment|
      find_subcomments(subsubcomment)
    end
  end
  initial_hash
end

def get_articles
  all_articles = []
  load_csv("articles.csv").each do |article|
    article["comments"] = []
    load_csv("comments.csv").each do |comment|
      if ( comment["parent_comment"] == comment["comment_id"] ) && ( comment["article_id"] == article["article_id"] )
         article["comments"] << find_subcomments(comment)
      end
    end
    all_articles << article
  end
  all_articles
end

def get_matches(csv, field, article_id)
  matches = []
  CSV.foreach(csv, headers: true) do |row|
    matches << row.to_hash if row[field] == article_id
  end
  matches.reverse
end

def get_comments
  all_rows = []
  CSV.foreach("comments.csv", headers: true) do |row|
    row_info = row.to_hash
    if row["comment_id"] != row["parent_comment"]
      row_info["response_to"] = get_matches("comments.csv","comment_id",row["parent_comment"])[0]["comment"]
    end
    row_info["article"] = get_matches("articles.csv","article_id", row["article_id"])
    all_rows << row_info
  end
  all_rows.reverse
end

def post_article(id, title, url, descriptor,calander_time,clock_time)
  CSV.open('articles.csv', 'a') do |csv|
    csv << [id, title, url, descriptor,calander_time,clock_time]
  end
end

def post_comment(comment_id,parent_comment,article_id, comment, time)
  CSV.open('comments.csv', 'a') do |csv|
    csv << [comment_id,parent_comment,article_id, comment, time]
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

get "/comments"  do
  @comments = get_comments
  erb :comments
end

get "/addcomment/:article_id"  do
  @article_info = get_articles[params[:article_id].to_i]
  erb :addcomment
end

get "/addresponse/:article_id/:parent_comment"  do
  @comment_info = ""
  get_comments.reverse.each { |comment| @comment_info = comment if comment["comment_id"].to_i == params[:parent_comment].to_i }
  erb :addresponse
end

post "/addcomment"  do
  comment_id = get_comments.length
  params[:parent_comment] == nil ? ( parent_comment = get_comments.length ) : ( parent_comment = params[:parent_comment] )
  post_comment(comment_id,parent_comment, params[:article_id], params[:comment], params[:time])
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
