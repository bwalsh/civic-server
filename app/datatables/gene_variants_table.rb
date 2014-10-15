class GeneVariantsTable
  delegate :params, to: :@view_context

  def initialize(view_context)
    @view_context = view_context
  end

  def as_json(options = {})
    {
      result: data,
      count: events.size,
    }
  end

  private
  def data
    events.map { |e| GeneVariantRowPresenter.new(e) }
  end

  def events
    @events ||= filter_events(order_events(get_events))
  end

  def get_events
    Event.index_scope
      .page(page)
      .per(count)
  end

  def filter_events(events)
    if filter_params = params['filter']
      filter_params.inject(events) do |e, (col, term)|
        e.where("lower(#{column_map(col)}) LIKE :search", search: "#{term.downcase}%")
      end
    else
      events
    end
  end

  def order_events(events)
    if sort_params = params['sorting']
      sort_params.inject(events) do |e, (col, direction)|
        e.order("#{column_map(col)} #{sort_direction(direction)}")
      end
    else
      events
    end
  end

  def page
    params[:page].to_i
  end

  def count
    params[:count].to_i
  end

  def column_map(col)
    @@columns[col]
  end

  def sort_direction(dir)
    dir == 'desc' ? 'desc' : 'asc'
  end

  @@columns = {
    'Entrez Gene'      => 'genes.name',
    'Entrez ID'        => 'genes.entrez_id',
    'Variant'          => 'events.name',
    'Category'         => 'categories.name',
    'Protein Function' => 'protein_functions.name',
  }
end
