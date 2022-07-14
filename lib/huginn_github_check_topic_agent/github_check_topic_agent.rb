module Agents
  class GithubCheckTopicAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Github Check Topic agent agent checks if topics are present and creates an event if they are missing.

      `wanted_topic` is the wanted topics list.

      `regex_filter_name` is used to filter repositories with regex ( for example `^huginn_`).

      `token` is mandatory for the queries .

      `debug` for more verbosity .

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "repository_name": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "url": "https://github.com/XXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "missing_topics": "huginn, huginn-agent"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'token' => '',
        'wanted_topic' => '',
        'regex_filter_name' => ''
      }
    end

    form_configurable :token, type: :string
    form_configurable :regex_filter_name, type: :string
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :wanted_topic, type: :string

    def validate_options
      unless options['token'].present?
        errors.add(:base, "token is a required field")
      end

      unless options['wanted_topic'].present?
        errors.add(:base, "wanted_topic is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def parse(payload)
      payload.each do |repository|
        if repository['name'].match(interpolated['regex_filter_name'])
          missing_topic = []
          if interpolated['debug'] == 'true'
            log "#{repository['name']} found"
          end
          topics_array = interpolated['wanted_topic'].split(" ")
          topics_array.each do |topic|
            found = 'false'
            repository['topics'].each do |topicbis|
              if interpolated['debug'] == 'true'
                log "topic #{topic} topicbis #{topicbis}"
              end
              if topic == topicbis
                found = 'true' 
              end
            end
            if interpolated['debug'] == 'true'
              if found == 'false'
                log "topic not present"
              end
            end
            if found == 'false'
              missing_topic.push(topic)
            end
          end
          if !missing_topic.empty?
            log "topic not present -> #{missing_topic}"
            create_event :payload => { "repository_name" => "#{repository['name']}", "url" => "#{repository['html_url']}", "missing_topics" => "#{missing_topic.join(", ")}" }
#            repository['url']
          end
        end
      end
    end    

    def get_next(url)
      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = interpolated['token']
      request["Accept"] = "application/vnd.github.mercy-preview+json"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    
      log "fetch notification request status : #{response.code}"
    
      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end
      parse(payload)
    end    
    
    def fetch
      uri = URI.parse("https://api.github.com/users/hihouhou/repos?per_page=100")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = interpolated['token']
      request["Accept"] = "application/vnd.github.mercy-preview+json"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    
      log "fetch notification request status : #{response.code}"
    
      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end
      parse(payload)

      if interpolated['debug'] == 'true' && response.to_hash['link'].present?
        log " link -> #{response.to_hash['link']}"
      end

      if response['link'].present?
        URI.extract(response['link'], ['http', 'https']).each do |url|
          get_next(url)
        end
      end
    end    
  end
end
