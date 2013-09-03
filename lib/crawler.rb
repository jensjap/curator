class Crawler
  attr_reader :work_order, :error_stack

  def initialize(project_id, extraction_form_id)  #{{{1
    @work_order         = Array.new
    @error_stack        = Array.new
    @project_id         = project_id
    @ef_id              = extraction_form_id

    ## Entry point

    ## Section detail tables are of the following section:  {{{2
    #    - Arm Detail
    #    - Baseline Characteristic
    #    - Design Detail
    #    - Outcome Detail
    #    - Quality Dimension
    self.crawl_section_details_table

    ## Extraction form arms tables are tables declared in the extraction form  {{{2
    #  question section and made available to pick from when extracting data from
    #  a study. However, they only offer choices and there is no other relationship
    #  between these and the study extraction, i.e. an entry here is not necessary
    #  for the study extraction, but it will aid in figuring out what fields to scan
    #  when it comes time to import the data
    self.crawl_extraction_form_arms_table

    ## Extraction form outcome names table is just like the extraction form arms table.  {{{2
    self.crawl_extraction_form_outcome_names
  end

  def extraction_form_title
    ExtractionForm.find(@ef_id).title
  end

  def _crawl_section(section_detail)  #{{{1
    _convert_ar_obj_to_hash(section_detail)
  end

  def _convert_ar_obj_to_hash(active_record_obj)  #{{{1
    temp_hash = Hash.new
    active_record_obj.attributes.each do |att|
      temp_hash[att[0]] = att[1]
    end
    return temp_hash
  end

  def _find_section_field_entries(section, section_detail)  #{{{1
    section_id = "#{section.underscore}_id"
    section_detail_fields = "#{section}Field".constantize.find(:all, :conditions => { "#{section_id}" => section_detail.id })
    return section_detail_fields
  end

  def _find_section_data_point_entries(section, section_detail)  #{{{1
    section_id = "#{section.underscore}_field_id"
    section_data_points = "#{section}DataPoint".constantize.find(:all, :conditions => { "#{section_id}" => section_detail.id })
    return section_data_points
  end

  def crawl_section_details_table  #{{{1
    ["ArmDetail", "BaselineCharacteristic", "DesignDetail", "OutcomeDetail", "QualityDimension"].each do |section|
      if section == "QualityDimension"  #{{{2
        section_details = "#{section}Field".constantize.find_all_by_extraction_form_id(@ef_id)
      else
        section_details = "#{section}".constantize.find_all_by_extraction_form_id(@ef_id)
      end
      section_details.each do |section_detail|
        temp = _crawl_section(section_detail)
        temp[:section] = section
        temp[:section_fields] = []# unless section_detail.field_type.downcase == "text" || section == "QualityDimension"
        temp[:section_data_points] = []

        ## Find all rows in section_fields table and add it to temp
        unless section == "QualityDimension" || section_detail.field_type.downcase == "text"
          section_detail_fields = _find_section_field_entries(section, section_detail)
          section_detail_fields.each do |f|
            hash_f = _convert_ar_obj_to_hash(f)
            temp[:section_fields].push hash_f
          end
        end

        ## Find all data points and add it to temp
        section_data_points = _find_section_data_point_entries(section, section_detail)
        section_data_points.each do |f|
          hash_f = _convert_ar_obj_to_hash(f)
          temp[:section_data_points].push hash_f
        end

        @work_order.push temp
      end
    end
  end

  def crawl_extraction_form_arms_table  #{{{1
    # !!! TODO
  end

  def crawl_extraction_form_outcome_names  #{{{1
    # !!! TODO
  end
end



## I shouldn't be iterating through the section fields for non-text questions. This isn't giving me what I want. I need 
## to nest it like this maybe:
##  - [arm_detail info, [field, [data_point]]]
