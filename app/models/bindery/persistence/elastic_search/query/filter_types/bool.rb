class Bindery::Persistence::ElasticSearch::Query::FilterTypes::Bool < Bindery::Persistence::ElasticSearch::Query::FilterSet

  def initialize(filter_type='bool', filter_params={})
    super
  end

  def must
    @must ||= self.add_filter(:must)
  end
  def must_not
    @must_not ||= self.add_filter(:must_not)
  end
  def should
    @should ||= self.add_filter(:should)
  end

  def add_must_match(filter_params, context=:query)
    if context == :query
      self.must.add_filter(:match, filter_params)
    else
      self.must.add_filter(:query).add_filter(:match, filter_params)
    end
  end

  def add_must_not_match(filter_params, context=:query)
    if context == :query
      self.must_not.add_filter(:match, filter_params)
    else
      self.must_not.add_filter(:query).add_filter(:match, filter_params)
    end
  end

  def add_should_match(filter_params, context=:query)
    if context == :query
      self.should.add_filter(:match, filter_params)
    else
      self.should.add_filter(:query).add_filter(:match, filter_params)
    end
  end

  def merge_existing_filters(existing_filters)
    json = self.as_json
    if json.empty?
      return existing_filters
    else
      if existing_filters
        json['bool'] ||= {}
        json['bool']['must'] ||= []
        json['bool']['must'] << existing_filters
      end
      return json
    end
  end

end