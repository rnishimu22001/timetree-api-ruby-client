# frozen_string_literal: true

module TimeTree
  # TimeTree apis client.
  class Client
    API_HOST = 'https://timetreeapis.com'
    # @return [String]
    attr_reader :access_token
    # @return [Integer]
    attr_reader :ratelimit_limit
    # @return [Integer]
    attr_reader :ratelimit_remaining
    # @return [Time]
    attr_reader :ratelimit_reset_at

    def initialize(access_token = nil)
      @access_token = access_token || TimeTree.configuration.access_token
      @http_cmd = HttpCommand.new(API_HOST, self)
    end

    #
    # Get current user information.
    #
    # @return [TimeTree::User]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def current_user
      res = get '/user'
      raise Error, res if res.status != 200

      to_model res.body[:data]
    end

    #
    # Get a single calendar's information.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [Array<symbol>] include_relationships
    # includes association's object in the response.
    # @return [TimeTree::Calendar]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def calendar(cal_id, include_relationships: nil)
      params = relationships_params(include_relationships, Calendar::RELATIONSHIPS)
      res = @http_cmd.get "/calendars/#{cal_id}", params
      raise Error, res if res.status != 200

      to_model(res.body[:data], included: res.body[:included])
    end

    #
    # Get calendar list that current user can access.
    #
    # @param [Array<symbol>] include_relationships
    # includes association's object in the response.
    # @return [Array<TimeTree::Calendar>]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def calendars(include_relationships: nil)
      params = relationships_params(include_relationships, Calendar::RELATIONSHIPS)
      res = @http_cmd.get '/calendars', params
      raise Error, res if res.status != 200

      included = res.body[:included]
      res.body[:data].map { |item| to_model(item, included: included) }
    end

    #
    # Get a calendar's label information used in event.
    #
    # @param [String] cal_id
    # calendar's id.
    # @return [Array<TimeTree::Label>]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def calendar_labels(cal_id)
      res = @http_cmd.get "/calendars/#{cal_id}/labels"
      raise Error, res if res.status != 200

      res.body[:data].map { |item| to_model(item) }
    end

    #
    # Get a calendar's member information.
    #
    # @param [String] cal_id
    # calendar's id.
    # @return [Array<TimeTree::User>]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def calendar_members(cal_id)
      res = @http_cmd.get "/calendars/#{cal_id}/members"
      raise Error, res if res.status != 200

      res.body[:data].map { |item| to_model item }
    end

    #
    # Get the event's information.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [String] event_id
    # event's id.
    # @param [Array<symbol>] include_relationships
    # includes association's object in the response.
    # @return [TimeTree::Event]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def event(cal_id, event_id, include_relationships: nil)
      params = relationships_params(include_relationships, Event::RELATIONSHIPS)
      res = @http_cmd.get "/calendars/#{cal_id}/events/#{event_id}", params
      raise Error, res if res.status != 200

      ev = to_model(res.body[:data], included: res.body[:included])
      ev.calendar_id = cal_id
      ev
    end

    #
    # Get the events' information after a request date.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [Integer] days
    # The number of days to get. A range from 1 to 7 can be specified.
    # @param [String] timezone
    # Timezone.
    # @param [Array<symbol>] include_relationships
    # includes association's object in the response.
    # @return [Array<TimeTree::Event>]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def upcoming_events(cal_id, days: 7, timezone: 'UTC', include_relationships: nil)
      params = relationships_params(include_relationships, Event::RELATIONSHIPS)
      params.merge!(days: days, timezone: timezone)
      res = @http_cmd.get "/calendars/#{cal_id}/upcoming_events", params
      raise Error, res if res.status != 200

      included = res.body[:included]
      res.body[:data].map do |item|
        ev = to_model(item, included: included)
        ev.calendar_id = cal_id
        ev
      end
    end

    #
    # Creates an event to the calendar.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [TimeTree::Event#data_params] params
    # event's information.
    # @return [TimeTree::Event]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def create_event(cal_id, params)
      res = @http_cmd.post "/calendars/#{cal_id}/events", params
      raise Error, res if res.status != 201

      ev = to_model res.body[:data]
      ev.calendar_id = cal_id
      ev
    end

    #
    # Updates an event.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [String] event_id
    # event's id.
    # @param [TimeTree::Event#data_params] params
    # event's information.
    # @return [TimeTree::Event]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def update_event(cal_id, event_id, params)
      res = @http_cmd.put "/calendars/#{cal_id}/events/#{event_id}", params
      raise Error, res if res.status != 200

      ev = to_model res.body[:data]
      ev.calendar_id = cal_id
      ev
    end

    #
    # Deletes an event.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [String] event_id
    # event's id.
    # @return [true] if the operation succeeded.
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def delete_event(cal_id, event_id)
      res = @http_cmd.delete "/calendars/#{cal_id}/events/#{event_id}"
      raise Error, res if res.status != 204

      true
    end

    #
    # Creates comment to an event.
    #
    # @param [String] cal_id
    # calendar's id.
    # @param [String] event_id
    # event's id.
    # @param [TimeTree::Activity#data_params] params
    # comment's information.
    # @return [TimeTree::Activity]
    # @raise [TimeTree::Error] if the http response status is not success.
    # @since 0.0.1
    def create_activity(cal_id, event_id, params)
      res = @http_cmd.post "/calendars/#{cal_id}/events/#{event_id}/activities", params
      raise Error, res if res.status != 201

      activity = to_model res.body[:data]
      activity.calendar_id = cal_id
      activity.event_id = event_id
      activity
    end

    def inspect
      limit_info = nil
      if @ratelimit_limit
        limit_info = " ratelimit:#{@ratelimit_remaining}/#{@ratelimit_limit}"
      end
      if @ratelimit_reset_at
        limit_info = "#{limit_info}, reset_at:#{@ratelimit_reset_at.strftime('%m/%d %R')}"
      end
      "\#<#{self.class}:#{object_id}#{limit_info}>"
    end

    #
    # update ratelimit properties
    #
    # @param [Faraday::Response] res
    # apis http response.
    def update_ratelimit(res)
      limit = res.headers['x-ratelimit-limit']
      remaining = res.headers['x-ratelimit-remaining']
      reset = res.headers['x-ratelimit-reset']
      @ratelimit_limit = limit.to_i if limit
      @ratelimit_remaining = remaining.to_i if remaining
      @ratelimit_reset_at = Time.at reset.to_i if reset
    end

    private

    def to_model(data, included: nil)
      TimeTree::BaseModel.to_model data, client: self, included: included
    end

    def relationships_params(relationships, default)
      params = {}
      relationships ||= default
      params[:include] = relationships.join ',' if relationships.is_a? Array
      params
    end
  end
end
