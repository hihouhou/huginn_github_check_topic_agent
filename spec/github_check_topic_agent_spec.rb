require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GithubCheckTopicAgent do
  before(:each) do
    @valid_options = Agents::GithubCheckTopicAgent.new.default_options
    @checker = Agents::GithubCheckTopicAgent.new(:name => "GithubCheckTopicAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
