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

  def extraction_form_title  #{{{1
    ExtractionForm.find(@ef_id).title
  end

  def extraction_form_id  #{{{1
    @ef_id
  end

  def _crawl_section(section_detail)  #{{{1
    _convert_ar_obj_to_hash(section_detail)
  end

  ## Working with ActiveRecord (ar) less convenient. We are converting...  #{{{1
  ## ...ar object to a hash
  def _convert_ar_obj_to_hash(active_record_obj)
    temp_hash = Hash.new

    ## QualityDimensionField has fields that are named differently. We fix that here
    if active_record_obj.class == QualityDimensionField
      active_record_obj.attributes.each do |att|
        if att[0] == "title"                      # QualityDimensionField uses title as the field name for the question...
          temp_hash["question"] = att[1]          # ...so we change it here
        elsif att[0] == "field_notes"
          temp_hash["instruction"] = att[1]
        else
          temp_hash[att[0]] = att[1]
        end
      end
      temp_hash["field_type"] = "radio"           # Add `field_type' because it is missing for this section
    ## For everyone else we directly map
    else
      active_record_obj.attributes.each do |att|
        temp_hash[att[0]] = att[1]
      end
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
        section_details = "#{section}Field".constantize.find(:all,
                                                             :conditions => { :extraction_form_id => @ef_id },
                                                             :order => :id)
      else  #{{{2
        section_details = "#{section}".constantize.find(:all,
                                                        :conditions => { :extraction_form_id => @ef_id },
                                                        :order => :question_number)
      end
      section_details.each do |section_detail|  #{{{2
        temp                       = _crawl_section(section_detail)
        temp[:section]             = section
        temp[:section_fields]      = Array.new
        temp[:section_data_points] = Array.new
        temp[:answer_choices]      = Array.new

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

        ## We find answer choices and add :answer_choices field to temp hash
        answer_choices = _find_answer_choices(temp)
        temp[:answer_choices] = answer_choices

        @work_order.push temp
      end
    end
  end

  def _find_answer_choices(temp)  #{{{1
    answer_choices = Array.new

    ## QualityDimensionField has its answer choices embedded in the question
    ## We will parse the question and add a new field to temp called answer_choices
    if temp[:section] == "QualityDimension"
      answer_choices = _parse_quality_dimension_field_question(temp["question"])
    elsif temp["field_type"] == "checkbox"
      temp[:section_fields].each do |section_field|
        answer_choices.push section_field["option_text"]
      end
    elsif temp["field_type"] == "matrix_checkbox"
      matrix_rows, matrix_cols = _split_matrix_into_rows_and_columns(temp[:section_fields])
      answer_choices = _build_matrix_answer_choices(matrix_rows, matrix_cols)
    elsif temp["field_type"] == "matrix_radio"
      matrix_rows, matrix_cols = _split_matrix_into_rows_and_columns(temp[:section_fields])
      answer_choices = _build_matrix_answer_choices(matrix_rows, matrix_cols)
    elsif temp["field_type"] == "matrix_select"
      matrix_rows, matrix_cols = _split_matrix_into_rows_and_columns(temp[:section_fields])
      answer_choices = _build_matrix_answer_choices(matrix_rows, matrix_cols)
    elsif temp["field_type"] == "radio"
      temp[:section_fields].each do |section_field|
        answer_choices.push section_field["option_text"]
      end
    elsif temp["field_type"] == "select"
      temp[:section_fields].each do |section_field|
        answer_choices.push section_field["option_text"]
      end
    elsif temp["field_type"] == "text"
      answer_choices = nil
    end

    return answer_choices
  end

  def _build_matrix_answer_choices(matrix_rows, matrix_cols)  #{{{1
    answer_choices = Array.new

    matrix_rows.each do |row|
      answer_choices.push "[Row]#{row["option_text"]}"
    end

    matrix_cols.each do |col|
      answer_choices.push "[Col]#{col["option_text"]}"
    end

#    matrix_rows.each do |row|
#      matrix_cols.each do |col|
#        answer_choices.push "[#{row["option_text"]}][#{col["option_text"]}]"
#      end
#    end

    return answer_choices
  end

  def _parse_quality_dimension_field_question(str)  #{{{1
    re_pattern = Regexp.new('\[(.*)\]')
    str =~ re_pattern
    options_str = "#{$1}"
    options_str.split(/[\s,]+/)
    #showRE(str, re_pattern)
  end

  def _split_matrix_into_rows_and_columns(section_fields)  #{{{1
    rows = Array.new
    cols = Array.new

    section_fields.each do |field|
      if field["column_number"] == 0
        rows.push field
      else
        cols.push field
      end
    end
    return rows, cols
  end

  def showRE(a,re)  #{{{1
    if a =~ re
      puts "#{$`}<<#{$&}>>#{$'}"
    else
      puts "no match"
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
