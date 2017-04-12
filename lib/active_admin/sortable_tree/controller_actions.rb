module ActiveAdmin::SortableTree
  module ControllerActions

    attr_accessor :sortable_options

    def sortable(options = {})
      options.reverse_merge! :sorting_attribute => :position,
                             :parent_method => :parent,
                             :children_method => :children,
                             :roots_method => :roots,
                             :tree => false,
                             :max_levels => 0,
                             :protect_root => false,
                             :collapsible => false, #hides +/- buttons
                             :start_collapsed => false,
                             :sortable => true,
                             :lazy => false

      # BAD BAD BAD FIXME: don't pollute original class
      @sortable_options = options

      # disable pagination
      config.paginate = false

      collection_action :sort, :method => :post do
        resource_name = active_admin_config.resource_name.to_s.underscore.parameterize('_')

        records = params[resource_name].inject({}) do |res, (resource, parent_resource)|
          res[resource_class.find(resource)] = resource_class.find(parent_resource) rescue nil
          res
        end
        errors = []
        ActiveRecord::Base.transaction do
          records.each_with_index do |(record, parent_record), position|
            record.send "#{options[:sorting_attribute]}=", position
            if options[:tree]
              record.send "#{options[:parent_method]}=", parent_record
            end
            errors << {record.id => record.errors} if !record.save
          end
        end
        if errors.empty?
          head 200
        else
          render json: errors, status: 422
        end
      end

      # action for lazy load
      collection_action :lazy_load, :method => :post do
        parent_record = resource_class.find(params[:parent_id])
        records = parent_record.send(options[:children_method]).sort do |a, b|
          if a.send(options[:sorting_attribute]) && b.send(options[:sorting_attribute])
            a.send(options[:sorting_attribute]) <=> b.send(options[:sorting_attribute])
          else
            a.send(options[:sorting_attribute]) ? -1 : 1
          end
        end
        # Create Arbre Component and render children
        component = ActiveAdmin::Views::IndexAsSortable.new(Arbre::Context.new({}, view_context))
        component.lazy_build(active_admin_config.get_page_presenter(:index))
        result = records.inject("") do |res, record|
          res + component.send(:build_nested_item, record)
        end
        render text: result.html_safe, status: 200, layout: false
      end
    end
  end

  ::ActiveAdmin::ResourceDSL.send(:include, ControllerActions)
end
