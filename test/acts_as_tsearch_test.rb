#########################################
# To run this you first need to create a database and set it up for tsearch.
# 
# Tsearch comes with Postgres now.  From terminal try a "locate tsearch2.sql".  If nothing is found then you need
# recompile postgres.  More information on that coming.
# 
# If you found tsearch2.sql then you just need to do this:
# >> su postgres  (or su root, then su postgres - if you don't know the postgres password)
# >> psql acts_as_tsearch_test < tsearch2.sql
# >> psql acts_as_tsearch_test
# 	grant all on public.pg_ts_cfg to acts_as_tsearch_test;
# 	grant all on public.pg_ts_cfgmap to acts_as_tsearch_test;
# 	grant all on public.pg_ts_dict to acts_as_tsearch_test;
# 	grant all on public.pg_ts_parser to acts_as_tsearch_test;
#
#########################################
require File.dirname(__FILE__) + '/test_helper'

class ActsAsTsearchTest < Test::Unit::TestCase

  fixtures :blog_entries, :blog_comments, :profiles

  def setup
    create_fixtures(:blog_entries, :blog_comments, :profiles)
  end  
  
  # Is your db setup properly for tests?
  def test_is_db_working
    assert BlogEntry.count > 0
  end
  
  # Do the most basic search
  def test_simple_search
    BlogEntry.acts_as_tsearch :fields => "title"
    BlogEntry.update_vectors
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml
  end

  # Do a simple multi-field search
  def test_simple_two_field
    BlogEntry.acts_as_tsearch :fields => [:title, :description]
    BlogEntry.update_vectors
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml
    b = BlogEntry.find_by_tsearch("dined")[0]
    assert b.id == 1, b.to_yaml
    assert BlogEntry.find_by_tsearch("shared").size == 2
    b = BlogEntry.find_by_tsearch("zippy")[0]
    assert b.id == 2, b.to_yaml
  end
  
  # Do a simple multi-field search
  def test_weight_syntax
    BlogEntry.acts_as_tsearch :vectors => {
                        :fields => {
                          "a" => {:columns => ["title"], :weight => 1},
                          "b" => {:columns => [:description], :weight => 0.5}
                          }
                        }
    BlogEntry.update_vectors
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml
    b = BlogEntry.find_by_tsearch("dined")[0]
    assert b.id == 1, b.to_yaml
    assert BlogEntry.find_by_tsearch("shared").size == 2
    b = BlogEntry.find_by_tsearch("zippy")[0]
    assert b.id == 2, b.to_yaml

    BlogEntry.acts_as_tsearch :fields => {
                          "a" => {:columns => ["title"], :weight => 1},
                          "b" => {:columns => [:description], :weight => 0.5}
                          }
    BlogEntry.update_vectors
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml
    b = BlogEntry.find_by_tsearch("dined")[0]
    assert b.id == 1, b.to_yaml
    assert BlogEntry.find_by_tsearch("shared").size == 2
    b = BlogEntry.find_by_tsearch("zippy")[0]
    assert b.id == 2, b.to_yaml
  end

  # Do a simple multi-field search
  def test_multi_table
    BlogEntry.acts_as_tsearch :vectors => {
                        :fields => {
                          "a" => {:columns => ["blog_entries.title"], :weight => 1},
                          "b" => {:columns => ["blog_comments.comment"], :weight => 0.5}
                          },
                        :tables => {
                          :blog_comments => {
                            :from => "blog_entries b2 left outer join blog_comments on blog_comments.blog_entry_id = b2.id",
                            :where => "b2.id = blog_entries.id"
                            }
                          }
                        }

    BlogEntry.update_vectors
    
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml

    b = BlogEntry.find_by_tsearch("see")[0]
    assert b.id == 1, b.to_yaml

    b = BlogEntry.find_by_tsearch("zippy")[0]
    assert b.id == 2, b.to_yaml
    
    b = BlogEntry.find_by_tsearch("crack")[0]
    assert b.id == 2, b.to_yaml
    
    
  end

  # Test the auto-update functionality
  def test_add_row_and_search
    BlogEntry.acts_as_tsearch :fields => [:title, :description]
    BlogEntry.update_vectors
    b = BlogEntry.new
    b.title = "qqq"
    b.description = "xxxyyy"
    b.save
    id = b.id
    b = BlogEntry.find_by_tsearch("qqq")[0]
    assert id == b.id
    b = BlogEntry.find_by_tsearch("xxxyyy")[0]
    assert id == b.id
  end
  
  def test_count_by_search
    BlogEntry.acts_as_tsearch :fields => "title"
    BlogEntry.update_vectors
    assert BlogEntry.count_by_tsearch("bob") == 1
    assert BlogEntry.count_by_tsearch("bob or zippy") == 2
    assert BlogEntry.count_by_tsearch("bob and opera") == 0
  end

  def test_add_row_and_search_flag_off
    BlogEntry.acts_as_tsearch :vectors => {
      :auto_update_index => false,
      :fields => [:title, :description]
    }
    BlogEntry.update_vectors
    b = BlogEntry.new
    b.title = "uuii"
    b.description = "ppkkjj"
    b.save
    id = b.id
    assert BlogEntry.find_by_tsearch("uuii").size == 0
    assert BlogEntry.find_by_tsearch("ppkkjj").size == 0

    #update vector
    BlogEntry.update_vector(id)
    #should be able to find it now
    assert BlogEntry.find_by_tsearch("uuii")[0].id == id
    assert BlogEntry.find_by_tsearch("ppkkjj")[0].id == id
    
  end
    
  # Test for error message if user typos field names
  def test_failure_for_bad_fields
    assert_raise ArgumentError do
      BlogEntry.acts_as_tsearch :fields => "ztitle"
    end

    assert_raise ArgumentError do
      BlogEntry.acts_as_tsearch :fields => [:ztitle, :zdescription]
    end
    
    assert_raise ArgumentError do
      BlogEntry.acts_as_tsearch :vectors => {
        :auto_update_index => false,
        :fields => {          
          "a" => {:columns => [:title]},
          "b" => {:columns => [:zdescription]}
          }
        }
    end
    
  end
  
  def test_vectors
#     Profile.acts_as_tsearch :public_vector => {:fields => {"a" => {:columns => [:name, :public_info]}}},
#                             :private_vector => {:fields => {"a" => {:columns => [:name, :private_info]}}}
     Profile.acts_as_tsearch :public_vector => {:fields => [:name, :public_info]},
                             :private_vector => {:fields => [:name, :private_info]}
#raise Profile.acts_as_tsearch_config.to_yaml
    Profile.update_vectors
    p = Profile.find_by_tsearch("ben",nil,{:vector => "public_vector"})[0]
    assert p.name == "ben", "Couldn't find 'ben' in public profile search"

    assert_raise RuntimeError do
      p = Profile.find_by_tsearch("ben")[0]
    end
    
    p = Profile.find_by_tsearch("bob",nil,{:vector => "public_vector"})[0]
    assert p.name == "bob", "Couldn't find 'bob' in public profile search"

    p = Profile.find_by_tsearch("ben",nil,{:vector => "private_vector"})[0]
    assert p.name == "ben", "Couldn't find 'ben' in private profile search"
    
    p = Profile.find_by_tsearch("bob",nil,{:vector => "private_vector"})[0]
    assert p.name == "bob", "Couldn't find 'bob' in private profile search"

    p = Profile.find_by_tsearch("pumpkin",nil,{:vector => "public_vector"})
    assert p.size == 0, "Shouldn't have found pumpkin in public search: #{p.to_yaml}"
    
    p = Profile.find_by_tsearch("pumpkin",nil,{:vector => "private_vector"})[0]
    assert p.name == "ben", "Couln't find pumpkin in private profile search"
    
  end
  
end
