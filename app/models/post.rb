class Post < ActiveRecord::Base
  include Searchable

  belongs_to :thread, class_name: "DiscussionThread"
  belongs_to :author, class_name: "User"
  has_and_belongs_to_many :broadcast_groups, class_name: "Group"
  has_many :mentions, class_name: "Notifications::Mention", dependent: :destroy

  validates :body, :author, :thread, presence: {allow_blank: false}

  before_create :add_and_increment_post_number

  def add_and_increment_post_number
    DistributedLock.new("thread_#{thread.id}").synchronize do
      next_post_number = thread.highest_post_number + 1
      self.post_number = next_post_number
      thread.update(highest_post_number: next_post_number)
    end
  end

  def required_roles
    thread.subforum.required_roles
  end

  def mark_as_visited(user)
    thread.mark_post_as_visited(user, self)
  end

  def message_id
    format_message_id(thread_id, post_number)
  end

  def previous_message_id
    if post_number > 1
      format_message_id(thread_id, post_number-1)
    end
  end

  def to_search_mapping
    {
      index: {
        _id: id,
        data: {
          body: body,
          author: author.id,
          author_name: author.name,
          author_email: author.email,
          thread: thread.id,
          thread_title: thread.title,
          thread_slug: thread.slug,
          post_number: post_number,
          subforum: thread.subforum.id,
          subforum_name: thread.subforum.name,
          subforum_slug: thread.subforum.slug,
          subforum_group: thread.subforum.subforum_group.id,
          subforum_group_name: thread.subforum.subforum_group.name,
          ui_color: thread.subforum.ui_color
        }
      }
    }
  end

  def self.query_dsl(query)
    # match query for exact matches, terms
    exact_match_query = {
      multi_match: {
        query: query,
        boost: 100,
        fields: [:thread_title, :body]
      }
    }

    # match query for phrase prefixes
    phrase_match_query = {
      multi_match: {
        query: query,
        boost: 10,
        fields: [:thread_title, :body],
        type: :phrase_prefix
      }
    }

    # Combine exact match and prefix queries
    query_dsl = {
      bool: {
        should: [exact_match_query, phrase_match_query]
      }
    }

    return query_dsl
  end

  def self.highlight_fields
    {
      fields: {
        thread_title: {},
        body: {}
      }
    }
  end

private
  def format_message_id(thread_id, post_number)
    "<thread-#{thread_id}/post-#{post_number}@community.hackerschool.com>"
  end
end
