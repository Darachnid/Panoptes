class TranslationStrings
  attr_reader :resource, :attributes

  def initialize(resource)
    @resource = resource
  end

  def extract
    @attributes = translatable_resource_attributes

    transform_method = "transform_#{resource_name}_attributes"
    if respond_to?(transform_method, true)
      send(transform_method)
    end

    flatten_nested_schema(attributes)
  end

  private

  def resource_name
    resource.model_name.singular
  end

  def translatable_resource_attributes
    translatable_attributes = resource.class.translatable_attributes
    resource_attributes = resource.attributes.except(:id)
    resource_attributes.with_indifferent_access.slice(*translatable_attributes)
  end

  # field guide item has icon attributes that should not be translated
  def transform_field_guide_attributes(nested_key="items")
    attributes[nested_key] = extract_nested_attributes(%i(title content), nested_key)
  end

  def transform_organization_attributes
    attributes["title"] = attributes["display_name"]
  end

  def transform_project_attributes
    attributes["title"] = attributes["display_name"]
  end

  # pandora app uses the tasks key to find the tasks strings
  def transform_workflow_attributes
    attributes["tasks"] = attributes.delete("strings")
  end

  def transform_tutorial_attributes(nested_key="steps")
    attributes[nested_key] = extract_nested_attributes(%i(content), nested_key)
  end

  def extract_nested_attributes(attributes_to_slice, key)
    attributes[key.to_sym].map do |nested_object|
      nested_object.slice(*attributes_to_slice)
    end
  end

  def flatten_nested_schema(hash_schema)
    # TODO: convert this to a visitor class that task the schema and converts
    # as it visits, see TasksVisitor for an example
    hash_schema.each_with_object({}) do |(parent_key, value), flattened_hash|
      if value.is_a? Array
        value.each_with_index.map do |nested_object, index|
          nested_object.each do |a_k, a_v|
            flattened_hash["#{parent_key}.#{index}.#{a_k}"] = a_v
          end
        end
      elsif value.is_a? Hash
        flatten_nested_schema(value).map do |h_k, h_v|
          flattened_hash["#{parent_key}.#{h_k}"] = h_v
        end
      else
        flattened_hash[parent_key] = value
      end
    end
  end
end
