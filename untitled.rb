require 'csv'

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
    load_csv("comments.csv").each do |comment|
      if ( comment["parent_comment"] == comment["comment_id"] ) && ( comment["article_id"] == article["article_id"] )
        article["comments"] = find_subcomments(comment)
      end
    end
    all_articles << [article]
  end
  puts all_articles
end

get_articles
